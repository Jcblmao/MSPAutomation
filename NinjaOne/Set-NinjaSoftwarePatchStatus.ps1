<#
    .NOTES
     Created on:   	2024-02-19 15:30:19
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
    .DESCRIPTION
        The script is a PowerShell script that performs software patch management using the NinjaRMM API. 
        It connects to the NinjaRMM API using reconnection parameters, retrieves a list of devices, 
        and checks for failed and successfully installed patches. It calculates the Unix time for 14 
        days ago and filters the failed patches based on that timeframe. It then determines the health status 
        of each device based on the presence of failed patches and updates the custom fields accordingly. 
        Finally, it handles devices that have already been processed or have no information by updating 
        the custom field to "Unknown". The script includes comments documenting the creation date, author, 
        and organization.
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

$ReconnectionParameters = @{
    Instance     = 'eu'
    ClientID     = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientID' -AsPlainText
    ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientSecret' -AsPlainText
    RefreshToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneRefreshToken' -AsPlainText
    UseTokenAuth = $True
}

# Connect to NinjaRMM API using the reconnection parameters
Connect-NinjaOne @ReconnectionParameters

# Get the current date and time in Unix time format
$currentDateTimeUnix = [int][double]::Parse((Get-Date -UFormat %s))

# Calculate the Unix time for 14 days ago
# Adjust to suite preferences 
# If attempted patch install date is greater then $DaysAgoUnix will write to failedPatches custom field with
# failed patch info. If under threshold or no failed patches will write "Healthy - No Failed Patches

$DaysAgoUnix = $currentDateTimeUnix - (13 * 24 * 60 * 60) # 13 days, 24 hours, 60 minutes, 60 seconds

# Get the list of all devices
$alldevices = Get-NinjaOneDevices

# Get the list of failed patches
$failedPatches = Get-NinjaOneSoftwarePatchInstalls -status "FAILED"

# Get the list of successfully installed patches
$healthyPatches = Get-NinjaOneSoftwarePatchInstalls -status "INSTALLED"

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
        Write-Host "Device $deviceId has 'Healthy' Software Patch status" -ForegroundColor Cyan
        Set-NinjaOneDeviceCustomFields -deviceid $deviceId -customFields @{ failedSoftwarePatches = "Healthy" }
    }
    elseif ($deviceFailedPatches.ContainsKey($deviceId)) {
        # The device has failed patches, update the custom field with the list of failed patches
        Write-Host "Device $deviceId has '$failedPatchesString' Software Patch status" -ForegroundColor Cyan
        $failedPatchesString = ($deviceFailedPatches[$deviceId] -join "`n")
        Set-NinjaOneDeviceCustomFields -deviceid $deviceId -customFields @{ failedSoftwarePatches = $failedPatchesString }
    }
}

foreach ($device in $alldevices) {
    if ($deviceHealthStatus.ContainsKey($device.id) -or $deviceFailedPatches.ContainsKey($device.id)) {
        # The device has already been processed, skip it
        Write-Host "Device $($device.id) has already been processed" -ForegroundColor Red
    }
    else {
        # The device has no information, update the custom field to "Unknown"
        Write-Host "Device $($device.id) has 'Unknown' Software Patch status" -ForegroundColor Cyan
        Set-NinjaOneDeviceCustomFields -deviceid $($device.Id) -customFields @{ failedSoftwarePatches = "Unknown" }                
    }
}