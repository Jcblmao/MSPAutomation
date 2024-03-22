<#
.SYNOPSIS
    Checks all OneDrive logs for status of OneDrive - NinjaOne-friendly
.DESCRIPTION
    This script is intended to be used to monitor OneDrive status from inside of NinjaOne. While it
    is possible to see the status within the Tenent; personal accounts, accounts where tenent access
    is limited or managed by a third party or the desire to try to widen vision from inside NinjaOne,
    aiming for single-pane access.

    Based on code from Rudy Ooms - https://call4cloud.nl/2020/09/lost-in-monitoring-onedrive/
.NOTES
    If OneDrive is paused by the end user, you may have a situation where OneDrive does not report itself
    as active until the next file is synced. This could be a short period of time over the default max
    of 24 hour pause. Until the next file is synced, it will still report as paused.

    Due to timing, the Custom Fields updated can take some time to show up in Ninja and be retrievable.
    Seems to be a delay with the first Set inside a script. After discussion on Ninja Discord,
    appears this is nature of it.

    In the script's current form, the intentions is to adjust the configuration variables below.
    Suggested variables below are default.
#>

<#
###### Test-OneDrive.ps1 -- v1.5

## Modified by Andy Klein
## Changes noted at end of script

## Based on code from Rudy Ooms - https://call4cloud.nl/2020/09/lost-in-monitoring-onedrive/
  Modified for NinjaOne use
  Intended for use as SYSTEM user - Needs access to reading log files

## Condition settings:
    Run Every: Choose your frequency of check. Not intense - Log doesn't update fast
    Timeout: 1m or 2m. Script does not take long as that it is just processing a log file
    Result Code: Greater than 0 or 1. You may want 1 if you are concerned about a malicous
        actor pausing a sync to hide itself.
#>

#### CONFIGURATION VARIABLES

## What type of OneDrive.
#   "Personal" for non-tenant OneDrive (M365 Family/Personal)
#   "Business1" for first tenant-based OneDrive, "Business2", etc.
$typeOneDrive = "Business1"

## You you want elements from here logged in Custom Fields as well?
# If so, please ensure the fields are available and set up
#   monitorOnedriveStatusCode (Text - Device) - This must be TEXT - Codes too long for INT
#   monitorOnedriveStatusDescription (Text - Device)
#   monitorOnedriveLastDateSynced (String - Device)
#   MonitorOnedriveLastSyncedSeconds (UNSIGNED INT - Device)
$wantCustomFields = $true

$isAzure = $false  # Are the accounts you want to test Azure accounts? $true or $false

# Number of hours before no files syncronized throws an error
#   72 hours to get through a weekend - Not recommended less than 25h
#   due to the Pausing issue. rudyooms indicates under 3 days could cause
#   issues due to the handling of the logs
$warningFileSyncedDelayHours = 72


###### DO NOT MAKE CHANGES BELOW UNLESS YOU KNOW WHAT YOU'RE DOING

#### CONSTANTS

## Response codes to NinjaOne

$responseNoError = 0                    # No error with current logged-in user

# Warnings
$responseNoUserLoggedIn = -1001         # No user currently logged in (No error - Cautionary)
$responseActiveNoRecentSync = -1011     # User logged in, OneDrive status good, more than 
                                        # $warningFileSyncedDelayHours since last sync
$responseBackupPausedNoSync = -1021     # Backup paused and more than $warningFileSyncedDelayHours

# Errors
$responseNotRunning = 1001              # User logged in, OneDrive not running
$responseUnknownError = 1011            # User logged in, OneDrive throwing error

# Soft Errors - May want to test
$responseBackupPaused = 1               # The Paused code from OneDrive log can take hours to clear
                                        # after unpausing. Please refer to last sync as a safety.

# Hard Failure error code                                        
$responseHardFailure = 9999                 # If the Try-Catch fails


## OneDrive codes

$statusOneDriveUpToDate = 16777216, 42, 0     # Up-to-date - Array
$statusOneDrivePaused = 65536                 # Paused - May be syncing
$statusOneDriveNotSyncing = 8194              # Not syncing
$statusOneDriveSyncingProblems = 1854         # Having syncing problems


### FUNCTIONS
## Convert-ResultCodeToName
# Convert returned integer status and convert to text descriptor.
Function Convert-ResultCodeToName
{
    # Evaluates response codes and converts to human-readable
    param([Parameter(Mandatory=$true)]
    [int] $status
)

switch($status)
{
    {($statusOneDriveUpToDate.Contains($_))} 
    {
        $statusName = "Up-to-Date"
    }
    $statusOneDrivePaused
    {
        $statusName = "Paused - Might be Syncing"
    }
    $statusOneDriveNotSyncing
    {
        $statusName = "Not syncing"
    }
    $statusOneDriveSyncingProblems
    {
        $statusName = "Having syncing problems"
    }
    default 
    {
        $statusName = "Unknown - ($status)" 
    }
}
return $statusName
}


## CODE START

# Leading component of the mask prior to onedrive type
$folderOneDriveLogs = "C:\Users\*\AppData\Local\Microsoft\OneDrive\logs\"

# Combine into single variable
# Note that must use *.log because if OneDrive can not open SyncDiagnostics.log, will make a new file
$folderMask = $folderOneDriveLogs + $typeOneDrive + "\*.log"  

# Find OneDrive logs in user folders of type $typeOneDrive
$files = Get-ChildItem -Path $folderMask -Filter SyncDiagnostics.log | Where-Object { $_.LastWriteTime -gt [datetime]::Now.AddMinutes(-1440)}

# Collect progressState and checkDate from SyncDiagnostics.log
$progressState = Get-Content $files | Where-Object { $_.Contains("SyncProgressState") } 
$checkLogDate = Get-Content $files | Where-Object { $_.Contains("UtcNow:") }  

# Parse SyncProgressState - Split off code
$status = $progressState | ForEach-Object { -split $_ | Select-Object -index 1 }

# Check if OneDrive is active
$processActive = Get-Process OneDrive -ErrorAction SilentlyContinue
$checkProcess = -Not($processActive.count -eq 0) 

# Get user and username who is currently logged in, if anyone
$user = Get-CimInstance -class Win32_ComputerSystem | Select-Object username

if($null -eq $user.username)  #Is there a username in $user?
{
    $userLoggedIn = $null
} 
elseif ((($isAzure) -and ($user.username -match "azuread")) -or
    (-not($isAzure) -and ($user.username -match "\\")))
{
    $userLoggedIn = $user.username
} 

# Create result text
$resultText = Convert-ResultCodeToName $status

# Checking if progressState indicates OneDrive is running
$state = ($progressState -match 16777216) -or ($progressState -match 42) -or ($progressState -match 0) 

## Comparing log file dates

# Grab first insance of UTC time from log and split off into ISO 8601
$rawLogDate = $checkLogDate | ForEach-Object { -split $_ | Select-Object -index 1 }

# Convert text into [DateTime] to be safe and UTC
$convertLogDate = $rawLogDate -as [DateTime]
$utcLogDate = $convertLogDate.ToUniversalTime()
$timezone = [System.TimeZoneInfo]::Local.DisplayName

# Grab current DateTime and convert to UTC
$dateNow = Get-Date
$utcNow = $dateNow.ToUniversalTime()

# Calculate timespan between times
$timeSpan = New-TimeSpan -start $utcLogDate -end $utcNow
$difference = $timeSpan.hours

# Set NinjaOne Custom Fields if desired
if($wantCustomFields)
{
    Ninja-Property-Set monitorOnedriveStatusCode $status
    Ninja-Property-Set monitorOnedriveStatusDescription $resultText
    Ninja-Property-Set MonitorOnedriveLastSyncedSeconds (Get-Date $rawLogDate -UFormat %s)

    $lastSyncedString = "$($convertLogDate) $($timezone)"
    Ninja-Property-Set monitorOnedriveLastDateSynced $lastSyncedString
}

## Final NinjaOne outputcd ~
Try 
{
If ($userLoggedIn -eq $False)
{
    Write-Host "- No user logged in"
    exit $responseNoUserLoggedIn
}
elseif ($checkProcess -eq $false)
{
    Write-Host "! User logged in | Onedrive is not running"
    exit $responseNotRunning
}
elseif ($state -eq $true -and  # If sync state from log is true, time since last sync <24hrs
    $difference -le $warningFileSyncedDelayHours) 
    # -and $files.count -gt 0) ## -- Not needed? $state should not come back true if no SyncProgressState
{
    Write-Host "- Onedrive reports good ($resultText)"
    exit $responseNoError
}
elseif ($state -eq $true -and  # If sync state from log is true, time since last sync <24hrs
    $difference -gt $warningFileSyncedDelayHours) # See note above on $files.count
{ 
    Write-Host "? Onedrive appears active but no files synced in $difference hours"
    exit $responseActiveNoRecentSync
}
elseif ($progressState -eq $statusOneDrivePaused -and
    $difference -le $warningFileSyncedDelayHours)
{
    Write-Host "- User logged in | OneDrive paused | Synced $difference hours ago"
    Write-Host "NOTE: It can take hours for the log to update after a pause"
    exit $responseBackupPaused
}
elseif ($progressState -eq $statusOneDrivePaused -and
    $difference -gt $warningFileSyncedDelayHours)
{
    Write-Host "! User logged in | OneDrive paused | Synced $difference hours ago"
    Write-Host "NOTE: The user may have ended up with a stuck Pause"
    exit $responseBackupPausedNoSync
}
else
{
    Write-Host "! Onedrive is $resultText ($status) | Synced $difference hours ago"
    exit $responseUnknownError
}
}
catch
{
    Write-Warning "! Value Missing"
    exit $responseHardFailure
}
<# 
## v1.0 - First version
## v1.1 - Minor code fixes + Improved comments
## v1.2 - Moved function declaration to above main code (Thanks @Excal) + Other housekeeping
## v1.3 - Fixed final response loop/Paused + fixed code for clarity/stability
## v1.4 - return was working; Replaced with proper exit
## v1.5 - Fix all timezone/UTC problems
#>