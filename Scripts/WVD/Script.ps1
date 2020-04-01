<#

.SYNOPSIS


.DESCRIPTION
.

.ROLE


#>


param(
    [Parameter(mandatory = $true)]
    [string]$RDBrokerURL,

    [Parameter(mandatory = $true)]
    [string]$definedTenantGroupName,

    [Parameter(mandatory = $true)]
    [string]$TenantName,

    [Parameter(mandatory = $true)]
    [string]$HostPoolName,

    [Parameter(mandatory = $false)]
    [string]$Description,

    [Parameter(mandatory = $false)]
    [string]$FriendlyName,

    [Parameter(mandatory = $true)]
    [string]$Hours,

    [Parameter(mandatory = $true)]
    [string]$TenantAdminUPN,

    [Parameter(mandatory = $true)]
    [string]$TenantAdminPassword,

    [Parameter(mandatory = $true)]
    [string]$localAdminUserName,

    [Parameter(mandatory = $true)]
    [string]$localAdminPassword,

    [Parameter(mandatory = $true)]
    [string]$rdshIs1809OrLater,

    [Parameter(mandatory = $false)]
    [string]$isServicePrincipal = "False",

    [Parameter(Mandatory = $false)]
    [string]$AadTenantId
)



function Write-Log { 
    [CmdletBinding()] 
    param ( 
        [Parameter(Mandatory = $false)] 
        [string]$Message,
        [Parameter(Mandatory = $false)] 
        [string]$Error 
    ) 
     
    try { 
        $DateTime = Get-Date -Format 'MM-dd-yy HH:mm:ss'
        $Invocation = "$($MyInvocation.MyCommand.Source):$($MyInvocation.ScriptLineNumber)" 
        if ($Message) {
            Add-Content -Value "$DateTime - $Invocation - $Message" -Path "$WVDDeployLogPath\ScriptLog.log" 
        }
        else {
            Add-Content -Value "$DateTime - $Invocation - $Error" -Path "$WVDDeployLogPath\ScriptLog.log" 
        }
    } 
    catch { 
        Write-Error $_.Exception.Message 
    } 
}

# Get Start Time
$startDTM = (Get-Date)
Write-Log -Message "Starting WVD Deploy on Host"
# Setting to Tls12 due to Azure web app security requirements
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$rdshIs1809OrLaterBool = ($rdshIs1809OrLater -eq "True")

$WVDDeployBasePath = "c:\WVDDeploy\"
$WVDDeployLogPath = "c:\WVDDeploy\logs"
$WVDDeployBootPath = "C:\WVDDeploy\Boot"
$WVDDeployInfraPath = "C:\WVDDeploy\Infra"
$WVDDeployFslgxPath =  "C:\WVDDeploy\fslogix"
$BootURI = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"
$infraURI = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
$fslgxURI = "https://aka.ms/fslogix_download"

# Creating a folder inside rdsh vm for agents and log files
New-Item -Path $WVDDeployLogPath -ItemType Directory -Force
New-Item -Path $WVDDeployBootPath -ItemType Directory -Force
New-Item -Path $WVDDeployInfraPath -ItemType Directory -Force
New-Item -Path $WVDDeployFslgxPath -ItemType Directory -Force

Write-Log -Message "Created Directory Structure Begining Setup for WVD"
Invoke-WebRequest -Uri $BootURI -OutFile "$WVDDeployBootPath\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi"
Write-Log -Message "Downloaded RDAgentBootLoader"
Invoke-WebRequest -Uri $infraURI -OutFile "$WVDDeployInfraPath\Microsoft.RDInfra.RDAgent.Installer-x64.msi"
Write-Log -Message "Downloaded RDInfra"
Invoke-WebRequest -Uri $fslgxURI -OutFile "$WVDDeployBasePath\FSLogix_Apps.zip"
Expand-Archive "$WVDDeployBasePath\FSLogix_Apps.zip" -DestinationPath "$WVDDeployFslgxPath" -ErrorAction SilentlyContinue
Remove-Item "$WVDDeployBasePath\FSLogix_Apps.zip"


# Checking if RDInfragent is registered or not in rdsh vm
$CheckRegistry = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue

Write-Log -Message "Checking whether VM was Registered with RDInfraAgent"

if ($CheckRegistry) {
    Write-Log -Message "VM was already registered with RDInfraAgent, script execution was stopped"
}
else {
    Write-Log -Message "VM was not registered with RDInfraAgent, script is executing"
}



if (!$CheckRegistry) {
    
    # Installing & Importing WVD PowerShell module
    If(-not(Get-InstalledModule Microsoft.RDInfra.RDPowerShell -ErrorAction silentlycontinue)){
        Install-PackageProvider NuGet -Force
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module Microsoft.RDInfra.RDPowerShell -Confirm:$False -Force
        Write-Log -Message "Installed RDMI PowerShell modules successfully"
    }

    Import-Module -Name Microsoft.RDInfra.RDPowerShell
    Write-Log -Message "Imported RDMI PowerShell modules successfully"

    #Build Credential Variables
    $Securepass = ConvertTo-SecureString -String $TenantAdminPassword -AsPlainText -Force
    $Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($TenantAdminUPN, $Securepass)
    $AdminSecurepass = ConvertTo-SecureString -String $localAdminPassword -AsPlainText -Force
    $adminCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($localAdminUserName, $AdminSecurepass)

    # Getting fqdn of rdsh vm
    $SessionHostName = (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain
    Write-Log  -Message "Getting fully qualified domain name of RDSH VM: $SessionHostName"

    # Authenticating to WVD
    if ($isServicePrincipal -eq "True"){
        $authentication = Add-RdsAccount -DeploymentUrl $RDBrokerURL -Credential $Credentials -ServicePrincipal -TenantId $AadTenantId 
    } else {
        $authentication = Add-RdsAccount -DeploymentUrl $RDBrokerURL -Credential $Credentials
    }
    $obj = $authentication | Out-String

    if ($authentication) {
        Write-Log -Message "RDMI Authentication successfully Done. Result: `
    $obj"  
    }
    else {
        Write-Log -Error "RDMI Authentication Failed, Error: `
    $obj"
    
    }

    # Set context to the appropriate tenant group
    Write-Log "Running switching to the $definedTenantGroupName context"
    Set-RdsContext -TenantGroupName $definedTenantGroupName
    try {
        $tenants = Get-RdsTenant
        if( !$tenants ) {
            Write-Log "No tenants exist or you do not have proper access."
        }
    } catch {
        Write-Log -Message ""
    }

    # Checking if host pool exists. If not, create a new one with the given HostPoolName
    $HPName = Get-RdsHostPool -TenantName $TenantName -Name $HostPoolName -ErrorAction SilentlyContinue
    Write-Log -Message "Checking Hostpool exists inside the Tenant"
    if ($HPName) {
        Write-log -Message "Hostpool $HPName, exists inside tenant: $TenantName"
    }
    else {
        Write-log -Message "Hostpool $HPName, does not exist inside tenant: $TenantName"
        Write-log -Message "Creating $HPName"
        $HPName = New-RdsHostPool -TenantName $TenantName -Name $HostPoolName -Description $Description -FriendlyName $FriendlyName

        $HName = $HPName.name | Out-String -Stream
        Write-Log -Message "Successfully created new Hostpool: $HName"
    }

    # Setting UseReverseConnect property to true
    Write-Log -Message "Checking Hostpool UseResversconnect is true or false"
    if ($HPName.UseReverseConnect -eq $False) {
        Write-Log -Message "UseReverseConnect is false, it will be changed to true"
        Set-RdsHostPool -TenantName $TenantName -Name $HostPoolName -UseReverseConnect $true
    }
    else {
        Write-Log -Message "Hostpool UseReverseConnect already enabled as true"
    }
    
    # Creating registration token
    $Registered = $null
    try {
        $Registered = Export-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName
        if (!$Registered) {
            $Registered = New-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName -ExpirationHours $Hours
            Write-Log -Message "Created new Rds RegistrationInfo into variable 'Registered': $Registered"
        } else {
            Write-Log -Message "Exported Rds RegistrationInfo into variable 'Registered': $Registered"
        }
    } catch {
        $Registered = New-RdsRegistrationInfo -TenantName $TenantName -HostPoolName $HostPoolName -ExpirationHours $Hours
        Write-Log -Message "Created new Rds RegistrationInfo into variable 'Registered': $Registered"
    }

    #Get MSI Paths for Install 
    $AgentBootServiceInstaller = (dir $WVDDeployBootPath\ -Filter *.msi | Select-Object).FullName
    $AgentInstaller = (dir $WVDDeployInfraPath\ -Filter *.msi | Select-Object).FullName
    $RegistrationToken = $Registered.Token

    #Boot Install
    # Uninstalling previous versions of RDAgentBootLoader
    Write-Log -Message "Uninstalling any previous versions of RDAgentBootLoader on VM"
    $bootloader_uninstall_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {A38EE409-424D-4A0D-B5B6-5D66F20F62A5}", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPath\AgentBootLoaderInstall.txt" -Wait -Passthru
    $sts = $bootloader_uninstall_status.ExitCode
    # Installing RDAgentBootLoader
    Write-Log -Message "Starting install of $AgentBootServiceInstaller"
    $bootloader_deploy_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $AgentBootServiceInstaller", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPathAgentBootLoaderInstall.txt" -Wait -Passthru
    $sts = $bootloader_deploy_status.ExitCode
    Write-Log -Message "Installing RDAgentBootLoader on VM Complete. Exit code=$sts"


    #Infra Install
    # Uninstalling previous versions of RDInfraAgent
    Write-Log -Message "Uninstalling any previous versions of RD Infra Agent on VM"
    $legacy_agent_uninstall_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {5389488F-551D-4965-9383-E91F27A9F217}", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPath\AgentUninstall.txt" -Wait -Passthru
    $sts = $legacy_agent_uninstall_status.ExitCode
    # Uninstalling previous versions of RDInfraAgent DLLs
    Write-Log -Message "Uninstalling any previous versions of RD Infra Agent DLL on VM"
    $agent_uninstall_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {CB1B8450-4A67-4628-93D3-907DE29BF78C}", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPath\AgentUninstall.txt" -Wait -Passthru
    $sts = $agent_uninstall_status.ExitCode
    # Installing RDInfraAgent
    Write-Log -Message "Starting install of $AgentInstaller"
    $agent_deploy_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $AgentInstaller", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken", "/l* $WVDDeployLogPath\AgentInstall.txt" -Wait -Passthru
    $sts = $agent_deploy_status.ExitCode
    Write-Log -Message "Installing RD Infra Agent on VM Complete. Exit code=$sts"

    #FSLogix Install
    Write-Log -Message "Starting Install of FSLogix"
    $fslgx_deploy_status = Start-Process "$WVDDeployFslgxPath\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait -Passthru
    $sts = $fslgx_deploy_status.ExitCode
    Write-Log -Message "Installing FSLogix Agent on VM Complete. Exit code=$sts"

    #Set Registry Key For Timezone Redirect
    $key =  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server"
    foreach($k in $key){
        If  ( -Not ( Test-Path "Registry::$k")){New-Item -Path "Registry::$k" -ItemType RegistryKey -Force}
        Set-ItemProperty -path "Registry::$k" -Name "fEnableTimeZoneRedirection" -Type "DWord" -Value "1"
    }


    #Starting Service
    Write-Log -Message "Starting RDAgentBootLoader service on SessionHostName"
    Start-Service RDAgentBootLoader     


    # Executing DeployAgent psl file in rdsh vm and add to hostpool
    # Write-Log "AgentInstaller is $DeployAgentLocation\RDAgentBootLoaderInstall, InfraInstaller is $DeployAgentLocation\RDInfraAgentInstall, SxS is $DeployAgentLocation\RDInfraSxSStackInstall"
    # $DAgentInstall = .\DeployAgent.ps1 -ComputerName $SessionHostName -AgentBootServiceInstallerFolder "$DeployAgentLocation\RDAgentBootLoaderInstall" -AgentInstallerFolder "$DeployAgentLocation\RDInfraAgentInstall" -SxSStackInstallerFolder "$DeployAgentLocation\RDInfraSxSStackInstall" -EnableSxSStackScriptFolder "$DeployAgentLocation\EnableSxSStackScript" -AdminCredentials $adminCredentials -TenantName $TenantName -PoolName $HostPoolName -RegistrationToken $Registered.Token -StartAgent $true -rdshIs1809OrLater $rdshIs1809OrLaterBool
    # Write-Log -Message "DeployAgent Script was successfully executed and RDAgentBootLoader,RDAgent,StackSxS installed inside VM for existing hostpool: $HostPoolName `
    # $DAgentInstall"

    #add rdsh vm to hostpool
    Write-Log -Message "Adding $SessionHostName To Pool $HostPoolName"
    $addRdsh = Set-RdsSessionHost -TenantName $TenantName -HostPoolName $HostPoolName -Name $SessionHostName -AllowNewSession $true
    $rdshName = $addRdsh.name | Out-String -Stream
    $poolName = $addRdsh.hostpoolname | Out-String -Stream
    Write-Log -Message "Successfully added $SessionHostName VM to $HostPoolName"
}

# Get End Time
$endDTM = (Get-Date)
Write-Log -Message "WVD Deploy on $SessionHostName Finished"
# Echo Time elapsed
Write-Log -Message "Elapsed Time: $(($endDTM-$startDTM).totalseconds) seconds"