<#
    .NOTES
     Created on:   	2024-02-19 15:30:19
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
    .DESCRIPTION
        This PowerShell script checks if the required modules are imported and installs them 
        if necessary. It then defines reconnection parameters for connecting to the NinjaRMM API 
        and establishes the connection. The script retrieves the current date and time in Unix 
        time format and calculates the Unix time for 14 days ago. It retrieves the list of all 
        devices, failed patches, and successfully installed patches from NinjaRMM. The script 
        filters the failed patches to include only those older than 14 days. It populates a hashtable 
        with devices and their respective failed patches. It determines the health status for all 
        devices and sets custom fields accordingly. Finally, it processes the remaining devices 
        and updates the custom field to "Unknown" if no information is available.
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
}
else { 
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

# Get the current date and time in Unix time format
$currentDateTimeUnix = [int][double]::Parse((Get-Date -UFormat %s))

# Calculate the Unix time for 14 days ago
$DaysAgoUnix = $currentDateTimeUnix - (13 * 24 * 60 * 60) # 13 days, 24 hours, 60 minutes, 60 seconds

# Get the list of all devices
$alldevices = Get-NinjaOneDevices

# Get the list of failed patches
$failedPatches = Get-NinjaOneOSPatchInstalls -status "FAILED"

# Get the list of successfully installed patches
$healthyPatches = Get-NinjaOneOSPatchInstalls -status "INSTALLED"

# Filter the failed patches to include only those older than $DaysAgoUnix
$filteredFailedPatches = $failedPatches | Where-Object { $_.installedAt -lt $DaysAgoUnix }

# Initialize a hashtable to keep track of failed patches by deviceId
$deviceFailedPatches = @{}
$deviceHealthStatus = @{}

# Populate the hashtable with devices and their respective failed patches
foreach ($patch in $filteredFailedPatches) {
    if (-not $deviceFailedPatches.ContainsKey($patch.deviceId)) {
        $deviceFailedPatches[$patch.deviceId] = [System.Collections.ArrayList]@()
    }
    [void]$deviceFailedPatches[$patch.deviceId].Add($patch.name)
}

# Determine the health status for all devices
foreach ($patch in $healthyPatches) {
    $deviceHealthStatus[$patch.deviceId] = $true
}

# Set the custom fields for each device
foreach ($deviceId in $deviceHealthStatus.Keys) {
    if ($deviceHealthStatus[$deviceId] -and -not $deviceFailedPatches.ContainsKey($deviceId)) {
        # The device is considered healthy if it has healthy patches and no failed patches
        Write-Host "Device $deviceId has 'Healthy' OS Patch status" -ForegroundColor Cyan
        Set-NinjaOneDeviceCustomFields -deviceid $deviceId -customFields @{ failedPatches = "Healthy" }
    } elseif ($deviceFailedPatches.ContainsKey($deviceId)) {
        # The device has failed patches, update the custom field with the list of failed patches
        Write-Host "Device $deviceId has 'Failed' OS Patch status" -ForegroundColor Cyan
        $failedPatchesString = ($deviceFailedPatches[$deviceId] -join "`n")
        Set-NinjaOneDeviceCustomFields -deviceid $deviceId -customFields @{ failedPatches = "Failed: $failedPatchesString" }
    }
}

foreach ($device in $alldevices) {
    if ($deviceHealthStatus.ContainsKey($device.id) -or $deviceFailedPatches.ContainsKey($device.id)) {
        # The device has already been processed, skip it
        Write-Host "Device $($device.id) has already been processed" -ForegroundColor Red
    } else {
        # The device has no information, update the custom field to "Unknown"
        Write-Host "Device $($device.id) has 'Unknown' OS Patch status" -ForegroundColor Cyan
        Set-NinjaOneDeviceCustomFields -deviceid $($device.Id) -customFields @{ failedPatches = "Unknown" }                
    }
}