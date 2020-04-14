# AzWVD-Template
[![Build Status](https://dev.azure.com/cocallaw/WVD%20ARM%20Template/_apis/build/status/WVD%20ARM%20Template%20Validation?branchName=master)](https://dev.azure.com/cocallaw/WVD%20ARM%20Template/_build/latest?definitionId=2&branchName=master)


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcocallaw%2FAzWVD-Template%2Fmaster%2FTemplates%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true"/> 
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fcocallaw%2FAzWVD-Template%2Fmaster%2FTemplates%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true"/>
</a>




## Template Description
This template will create WVD Host VMs using the specified source image, then prepare and join them to the specified WVD Host pool.

### Prerequisites 

The following items are required to already exist for the template to deploy sucessfully 

* Azure Virtual Network and Subnet in the same region and subscription
* Windows AD Domain and AD user capable of joining machines to the domain
* Network connectivity from the subnet being used to the AD infrastructure
* Azure WVD Tenant and Host Pool ([Setup-WVDHost.ps1](https://github.com/cocallaw/AzWVD-Template/blob/master/Scripts/WVD/Setup-WVDHost.ps1) will create Host Pool if it does not exist in Tenant given)
* Azure WVD Tenant Admin User or SPN credentials 

### Host Configuration

This template utilizes the Azure VM Custom Script Extension to run [Setup-WVDHost.ps1](https://github.com/cocallaw/AzWVD-Template/blob/master/Scripts/WVD/Setup-WVDHost.ps1), which performs the WVD specific prep, and joining to the specified Host Pool. The script uses public URLs to download and install the most recent version of following items-

* Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi
* Microsoft.RDInfra.RDAgent.Installer-x64.msi
* FSLogixAppsSetup.exe

The standalone Setup-WVDHost.ps1 can be found in the [cocallaw/AzWVD-PSScript](https://github.com/cocallaw/AzWVD-PSScript) repo, and can be used for configuring a VM locally or incorporating into other WVD workflows 

## Template Parameters

Parameter | Required | Description
--- | --- | ---
Location | Yes | Region resources will be deployed to, defaults to Resource Group location
localAdminUsername | Yes | Admin username for Host VMs
localAdminPassword | Yes | Admin password for Host VMs
vmHostBaseName | Yes | Base VM name that will incrimented with -number for each instance
vmHostSize | Yes | VM SKU size to be used for all Hosts created
numberOfHosts | Yes | Number of VM Hosts to deploy
HostImageType | Yes | Is the Host VM Image from the Azure Gallery or Custom Azure VM Image
HostOS | Yes | OS Platform for the Host VM
HostIsWindowsServer | Bool | If the VM is a Windows Server SKU (2016, 2019, etc.), enter true. If the VM is a Windows client SKU (Windows 10) enter false.
CustomImageSourceName | Conditional | Name of the Azure VM Image to be used. Required if HostImageType is set to CustomImage
CustomImageSourceResourceGroup | Conditional | Name of the Resource Group containing the custom Azure VM Image to be used. Required if HostImageType is set to CustomImage
galleryName | Conditional | Name of the Shared Image Gallery. Required if HostImageType is set to AzureImageGallery
galleryImageDefinitionName | Conditional | Name of the Image Definition. Required if HostImageType is set to AzureImageGallery
galleryImageVersionName | Conditional | Name of the Image Version - should follow `<MajorVersion>.<MinorVersion>.<Patch>`. Required if HostImageType is set to AzureImageGallery
createAvailabilitySet | Bool | If set to True template will create Availability Set for all Host VMs deployed. Using an Availability set limits you to a maximum of 200 virtual machines For more info: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#virtual-machines-limits---azure-resource-manager."
AVSFault | Conditional | Fault Domains for the Availabilty Set. Required if createAvailabilitySet set to True
AVSUpdate | Conditional | Update Domains for the Availabilty Set. Required if createAvailabilitySet set to True
existingVNetRG | Yes | Name of the of the Resource Group Containing the Virtual Network the Host will connect to
existingVNetName | Yes | Name of the of the existing Virtual Network the Host will connect to
existingSubnetName | Yes | Name of the of the existing Subnet the Host will connect to
domainToJoin | Yes | The domain name that the Host VMs will join (mydomain.com or wvd.mydomain.com)
domainUserFQDN | Yes | FQDN Username to be used to join Hosts to the specified domain
domainPassword | Yes | Password for the account being used to join Hosts to the specified domain
ouPath | Yes | Specifies an organizational unit (OU) where the Hosts will be placed in Active Directory
domainJoinOptions | Yes | Set of bit flags that define the join options. Default value of 3 is a combination of `NETSETUP_JOIN_DOMAIN (0x00000001)` & `NETSETUP_ACCT_CREATE (0x00000002)` i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx
ExistingTenantGroupName | Yes | The name of the tenant group in the WVD deployment
ExistingTenantName | Yes | Name of the Existing WVD Tenant
HostPoolName | Yes | Name of existing WVD Hostpool
TenantAdminUpnOrApplicationId | Yes | The template will fail if you enter a user account that requires MFA or an application that is secured by a certificate. The UPN or ApplicationId must be an RDS Owner in the WVD Tenant to create the hostpool or an RDS Owner of the host pool to provision the host pool with additional VMs
TenantAdminPassword | Yes | The password that corresponds to the tenant admin UPN or SPN
isServicePrincipal | Bool | The boolean value indicating if the credentials are for a service principal
AadTenantId | Yes | The Azure AAD Tenant ID GUID where the WVD is located