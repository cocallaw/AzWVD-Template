#Registry RdmsEnableUILog
$key =  "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
foreach($k in $key){
            If  ( -Not ( Test-Path "Registry::$k")){New-Item -Path "Registry::$k" -ItemType RegistryKey -Force}
            Set-ItemProperty -path "Registry::$k" -Name "EnableUILog" -Type "DWord" -Value "1"
        }

#Registry EnableDeploymentUILog
$key =  "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
foreach($k in $key){
                If  ( -Not ( Test-Path "Registry::$k")){New-Item -Path "Registry::$k" -ItemType RegistryKey -Force}
                Set-ItemProperty -path "Registry::$k" -Name "EnableDeploymentUILog" -Type "DWord" -Value "1"
        }

#Registry EnableTraceLog
$key =  "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
foreach($k in $key){
                If  ( -Not ( Test-Path "Registry::$k")){New-Item -Path "Registry::$k" -ItemType RegistryKey -Force}
                Set-ItemProperty -path "Registry::$k" -Name "EnableTraceLog" -Type "DWord" -Value "1"
        }

#Registry EnableTraceToFile
$key =  "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMS"
foreach($k in $key){
                If  ( -Not ( Test-Path "Registry::$k")){New-Item -Path "Registry::$k" -ItemType RegistryKey -Force}
                Set-ItemProperty -path "Registry::$k" -Name "EnableTraceToFile" -Type "DWord" -Value "1"
        }

#Add Firewall Rule 
New-NetFirewallRule -DisplayName "Firewall-GW-RDSH-TCP-In" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -Group "Connection Broker" -Description "Inbound rule for CB to allow TCP traffic for configuring GW and RDSH machines during deployment."

#Add RDS Feature 
$vmname = $env:computername
Install-WindowsFeature -Name RDS-RD-Server -computerName $vmname
