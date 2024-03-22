<#
    .NOTES
     Created on:   	2024-02-19 15:35:45
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
.DESCRIPTION
    The script is a PowerShell script that connects to the NinjaRMM API and retrieves device 
    information. It uses reconnection parameters to establish the connection and then retrieves 
    all devices from NinjaRMM. It loops through each device and checks its health status. 
    Based on the health status, it sets custom fields for each device indicating its health status. 
    The script also includes some notes and description metadata.
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
$ReconnectionParameters = @{
    Instance = 'eu'
    ClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientID' -AsPlainText
    ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientSecret' -AsPlainText
    RefreshToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneRefreshToken' -AsPlainText
    UseTokenAuth = $True
}

# Connect to NinjaRMM API using the reconnection parameters
Connect-NinjaOne @ReconnectionParameters

# Get all devices from NinjaRMM
$allDevices = Get-NinjaOneDevices

# Loop all devices to check health status
foreach ($device in $alldevices) {
    $id = $device.id

    # Check if the device has a health status
    $deviceHealth = Get-NinjaOneDeviceHealth -deviceFilter "id = $id"
    
    # Map the contents of $deviceHealth to variables
    $activeThreatsCount = $deviceHealth.activeThreatsCount
    $quarantinedThreatsCount = $deviceHealth.quarantinedThreatsCount
    $blockedThreatsCount = $deviceHealth.blockedThreatsCount
    $failedOSPatchesCount = $deviceHealth.failedOSPatchesCount
    $pendingOSPatchesCount = $deviceHealth.pendingOSPatchesCount
    $alertCount = $deviceHealth.alertCount
    $activeJobCount = $deviceHealth.activeJobCount
    $failedSoftwarePatchesCount = $deviceHealth.failedSoftwarePatchesCount
    $pendingSoftwarePatchesCount = $deviceHealth.pendingSoftwarePatchesCount
    $pendingRebootReason = $deviceHealth.pendingRebootReason
    $productsInstallationStatuses = $deviceHealth.productsInstallationStatuses
    $offline = $deviceHealth.offline
    $parentOffline = $deviceHealth.parentOffline
    $healthStatus = $deviceHealth.healthStatus
    $installationIssuesCount = $deviceHealth.installationIssuesCount
    $deviceId = $deviceHealth.deviceId

    # Set the health status custom field for the device and write to host what is being updated
    switch($healthStatus)
    {
        "HEALTHY" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $ID -customFields @{ healthStatus = "Healthy" }
            Write-Host "Device $ID has been updated to Healthy" -ForegroundColor Green
        }
        "NEEDS_ATTENTION" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $ID -customFields @{ healthStatus = "Needs Attention" }
            Write-Host "Device $ID has been updated to Needs Attention" -ForegroundColor Yellow
        }
        "UNHEALTHY" 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $ID -customFields @{ healthStatus = "Unhealthy" }
            Write-Host "Device $ID has been updated to Unhealthy" -ForegroundColor Red
        }
        default 
        {
            Set-NinjaOneDeviceCustomFields -deviceid $ID -customFields @{ healthStatus = "Unknown" }
            Write-Host "Device $ID has been updated to Unknown" -ForegroundColor Yellow
        }
    }
}