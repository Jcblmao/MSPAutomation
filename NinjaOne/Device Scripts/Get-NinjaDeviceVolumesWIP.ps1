<#
    .NOTES
     Created on:   	2024-02-19 15:35:45
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
    .DESCRIPTION
    
#>

# Check if the Az.KeyVault module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
}
else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

# Check if the NinjaOne module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "NinjaOne") { 
    Import-Module NinjaOne
} else { 
    Install-Module NinjaOne -Force; Import-Module NinjaOne
}

# Define the reconnection parameters for connecting to NinjaRMM API
$NinjaReconnectionParameters = @{
    Instance = 'eu'
    ClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientID' -AsPlainText
    ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientSecret' -AsPlainText
    RefreshToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneRefreshToken' -AsPlainText
    UseWebAuth = $True
}

# Define the connection parameters for connecting to Halo API
$HaloClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientID' -AsPlainText
$HaloClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientSecret' -AsPlainText
$HaloURL = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloURL' -AsPlainText

# Connect to NinjaRMM API using the reconnection parameters
Connect-NinjaOne @NinjaReconnectionParameters

# Connect to NinjaRMM API using the reconnection parameters
Connect-HaloAPI -URL $HaloURL -ClientId $HaloClientID -ClientSecret $HaloClientSecret -Scopes "all"

# Get all devices from NinjaRMM
$devices = Get-NinjaOneDevices

# Loop all devices
foreach ($device in $devices) {
    Get-NinjaOneDeviceVolumes -deviceid $($device.deviceID)
    $serialNumber = $device.system.serialNumber

    # Find device in Halo
    $HaloDevice = Get-HaloAsset -FullObjects -Search $serialNumber

    # Create Halo update object
    $UpdateAsset = @{
        id           = $HaloDevice.Id
        customfields = @(
            @{
                name  = "CF"
                value = $DattoDeviceSoftwareHTML
            }
        )
    }
    switch($($device.healthstatus))
    {
        "HEALTHY" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $($device.deviceID) -customFields @{ healthStatus = "Healthy" }
        }
        "NEEDS_ATTENTION" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $($device.deviceID) -customFields @{ healthStatus = "Needs Attention" }
        }
        "UNHEALTHY" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $($device.deviceID) -customFields @{ healthStatus = "Unhealthy" }
        }
        default 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $($device.deviceID) -customFields @{ healthStatus = "Unknown" }
        }
    }
}