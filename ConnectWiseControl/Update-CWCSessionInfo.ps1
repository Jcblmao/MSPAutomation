<#
    .NOTES
     Created on:   	2024-02-20 17:29:10
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
    .DESCRIPTION
    This script is designed to poll the ConnectWise Control API for all active sessions
    and retrieve device information. It then runs remote commands to gather additional
    device details and updates the custom fields in ConnectWise Control to reflect the
    device information. The script checks this information with HaloPSA and updates the
    custom fields accordingly. The script also includes some notes and description metadata.
#>

# Function that runs a remote command on a CWC session
function Send-RemoteCommand {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GUID,
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    # Run the command and capture the output
    $output = Invoke-CWCCommand -GUID $GUID -Command $Command | Out-String

    # Split the output into lines
    $lines = $output -split "`n"

    # Remove the first line (the command that was run)
    $filteredLines = $lines | Select-Object -Skip 1

    # Join the remaining lines back into a single string
    $response = $filteredLines -join "`n"

    # Remove any leading or trailing whitespace
    $response = $response.Trim()

    return $response
}

# Function to convert command output to a JSON string
function ConvertTo-JsonFromCommand {
    param (
        [Parameter(Mandatory=$true)]
        [string]$command
    )

    # Run the command and capture the output
    $output = Invoke-CWCCommand -GUID $sessionID -Command $command | Out-String

    # Split the output into lines
    $lines = $output -split "`n"

    # Filter the lines to remove the command line prompt and the command
    $filteredLines = $lines | Where-Object {
        $_ -notmatch "^C:\\Windows\\system32>"
    }

    # Join the filtered lines back into a string
    $filteredOutput = $filteredLines -join "`n"

    # Replace colon and whitespace with equals sign
    $filteredOutput = $filteredOutput -replace ': ', '='

    # Convert the filtered output to a PowerShell object
    $object = $filteredOutput | ConvertFrom-StringData

    # Convert the object to JSON
    $json = $object | ConvertTo-Json

    # Return the JSON string
    return $json
}

# Function to convert filtered output to a hashtable
function ConvertTo-HashTable {
    param (
        [Parameter(Mandatory=$true)]
        [string]$filteredOutput
    )

    # Initialize an empty hashtable
    $hashTable = @{}

    # Split the filtered output into lines
    $lines = $filteredOutput -split "`n"

    # Process each line
    foreach ($line in $lines) {
        # Split the line into key and value at the colon
        $parts = $line -split ':', 2

        # If the line contains a colon
        if ($parts.Count -eq 2) {
            # Trim whitespace from the key and value
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()

            # Add the key-value pair to the hashtable
            $hashTable[$key] = $value
        }
    }

    # Return the hashtable
    return $hashTable
}

# Check if the Az.KeyVault module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
} else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

# Get HaloAPI Module and installing.
If (Get-Module -ListAvailable -Name "HaloAPI") { 
    Import-Module HaloAPI
} Else { 
    Install-Module HaloAPI -Force; Import-Module HaloAPI
}

# Check if the ConnectWiseControlAPI module v0.3.6.0 is already imported, if not, install and import it
# Get all available versions of the module
$CWCModule = Get-Module -Name "ConnectWiseControlAPI" -ListAvailable

# Filter to get a specific version
$versionCheck = $CWCModule | Where-Object { $_.Version -eq "0.3.6.0" }

# Import the module
if ($versionCheck -eq "0.3.6.0") { 
    Import-Module "ConnectWiseControlAPI" -RequiredVersion "0.3.6.0"
} else { 
    # Define the module name and URL
    $moduleName = "ConnectWiseControlAPI"
    $moduleUrl = "https://raw.githubusercontent.com/Jcblmao/ConnectWiseControlAPI/master/ConnectWiseControlAPI/ConnectWiseControlAPI.psm1"

    # Define the path to save the module
    $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$moduleName"

    # Create the directory if it doesn't exist
    if (!(Test-Path -Path $modulePath)) {
        New-Item -ItemType Directory -Path $modulePath | Out-Null
    }

    # Download the module file
    Invoke-WebRequest -Uri $moduleUrl -OutFile "$modulePath\$moduleName.psm1"

    # Import the module
    Import-Module "$modulePath\$moduleName.psm1"
}

# Define the credentials from Azure Key Vault
$CWCServer = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'CWCServer' -AsPlainText
$CWCUsername = Get-AzKeyVaultSecret -VaultName "jdev" -Name "CWCUsername" -AsPlainText
$CWCPassword = (Get-AzKeyVaultSecret -VaultName "jdev" -Name "CWCPassword").SecretValue
$CWCSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'CWCSecret' -AsPlainText
$HaloClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientID' -AsPlainText
$HaloClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientSecret' -AsPlainText
$HaloScopes = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloScopes' -AsPlainText
$HaloURL = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloURL' -AsPlainText
$ORGTenantID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'ORGTenantID' -AsPlainText

# Create the PSCredential object
$CWCCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $CWCUsername, $CWCPassword
$ConnectCWC = @{
    Server = $CWCServer
    Credentials = $CWCCredentials
    secret = $CWCSecret | ConvertTo-SecureString -AsPlainText
}

# Connect to CWC API
Connect-CWC @ConnectCWC

# Connect to the Halo API
Connect-HaloAPI -URL $HaloURL -ClientID $HaloClientID -ClientSecret $HaloClientSecret -Scopes $HaloScopes

# Get all CWC sessions
$allSessions = Get-CWCSession -Type 'Access'

# Define commands to run on the remote machine
$comGetWMIObject = "powershell.exe -ExecutionPolicy Unrestricted Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem"
$comHardwareType = "powershell.exe -ExecutionPolicy Unrestricted (Get-CimInstance -Class Win32_ComputerSystem -Property PCSystemType).PCSystemType `n"
$comDSRegCMD = "dsregcmd /status"
$comGetBIOSDetails = "powershell.exe -ExecutionPolicy Unrestricted Get-WmiObject -Class Win32_BIOS"

# Define the hashtable to map PCSystemType values to human-readable formats
$pcSystemTypeMapping = @{
    0 = "Unspecified"
    1 = "Desktop"
    2 = "Mobile (Laptop)"
    3 = "Workstation"
    4 = "Enterprise Server"
    5 = "SOHO Server"
    6 = "Appliance PC"
    7 = "Performance Server"
    8 = "Maximum"
}

# Loop all sessions
foreach ($session in $allSessions) {
    $SessionID = $session.SessionID

    # Get session detail
    $deviceDetails =  Get-CWCSessionDetails -GUID $SessionID
    $isOnline = $deviceDetails.Online

    Write-Host "Processing Session: $SessionID" -ForegroundColor Cyan
        
    if ($isOnline -eq "True") {

        Write-Host "Device is online, running remote commands" -ForegroundColor Green
        
        # Run remote commands to get more device information
        $DSRegCMD = Send-RemoteCommand -GUID $SessionID -Command $comDSRegCMD
        $HardwareType = Send-RemoteCommand -GUID $SessionID -Command $comHardwareType
        $GetWMIObject = Send-RemoteCommand -GUID $SessionID -Command $comGetWMIObject
        $GetBIOSDetails = Send-RemoteCommand -GUID $SessionID -Command $comGetBIOSDetails
        
        # Convert the output of 'DSRegCMD' Command to a hashtable
        $lines = $DSRegCMD -split "`n" | Where-Object { $_ -match ':' }
        $DSRegCMDTable = @{}
        foreach ($line in $lines) {
            $parts = $line -split ':', 2
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            $DSRegCMDTable[$key] = $value
        }

        # Get Device name details
        $nameDetails = ConvertTo-HashTable -filteredOutput $GetWMIObject

        # Get Serial Number
        $BIOSDetails = ConvertTo-HashTable -filteredOutput $GetBIOSDetails

        # Search Halo for Device by Serial Number
        $HaloDevice = Get-HaloAsset -Search $BIOSDetails.SerialNumber

        Write-Host "Checking if device exists in Halo" -ForegroundColor Blue

        # If device is found in halo, take note of client_name and site_name, else set to null
        if ($HaloDevice) {
            $HaloClientName = $HaloDevice.client_name
            $HaloSiteName = $HaloDevice.site_name
            $HaloDeviceID = $HaloDevice.id

            Write-Host "Found device in Halo - DeviceID: $HaloDeviceID for $HaloClientName" -ForegroundColor Green

            # Update the 'Company' field to show the relevant client name
            Update-CWCCustomProperty -GUID $SessionID -Property 0 -Value $HaloClientName

            # Update the 'Location' field to show the relevant site name
            Update-CWCCustomProperty -GUID $SessionID -Property 1 -Value $HaloSiteName

        } else {
            $HaloClientName = $null
            $HaloSiteName = $null
        }

        # Get TenantID from the device
        $TenantID = $DSRegCMDTable['TenantId']

        Write-Host "Checking device join status" -ForegroundColor Blue

        # Check if device is Azure AD joined, Domain joined or within a Workgroup
        if ($DSRegCMDTable['DomainJoined'] -eq "Yes" -and $DSRegCMDTable['AzureAdJoined'] -eq "No") {

            Write-Host "Device is Domain Joined, updating Custom Properties" -ForegroundColor Magenta

            # Update the 'Identity Provider' field to show the relevant domain name
            Update-CWCCustomProperty -GUID $SessionID -Property 5 -Value $nameDetails.domain

            # Update the 'Join Status' field to 'AD Joined'
            Update-CWCCustomProperty -GUID $SessionID -Property 6 -Value "Domain Joined"

            # Update the 'Device Type' field to show the relevant PCSystemType
            Update-CWCCustomProperty -GUID $SessionID -Property 3 -Value $pcSystemTypeMapping[$HardwareType]

            # Set Device name as Session Name
            Update-CWCSessionName -GUID $SessionID -NewName $nameDetails.name

        } elseif ($DSRegCMDTable['AzureAdJoined'] -eq "Yes" -and $DSRegCMDTable['DomainJoined'] -eq "No") {

            Write-Host "Device is Azure AD Joined, updating Custom Properties" -ForegroundColor Magenta

            # Update the 'Identity Provider' field to show the tenant name
            Update-CWCCustomProperty -GUID $SessionID -Property 5 -Value $DSRegCMDTable['TenantName']

            # Update the 'Join Status' field to 'Azure AD Joined'
            Update-CWCCustomProperty -GUID $SessionID -Property 6 -Value "Azure AD Joined"

            # Update the 'Device Type' field to show the relevant PCSystemType
            Update-CWCCustomProperty -GUID $SessionID -Property 3 -Value $pcSystemTypeMapping[$HardwareType]

            # Get Intune management URL
            if ($TenantID -ne 'Alpha Scan Computers LTD') {
                $IntuneURL = "https://intune.microsoft.com/$TenantID/#view/"

                # Update the 'Intune Management URL' field to show the relevant URL
                Update-CWCCustomProperty -GUID $SessionID -Property 7 -Value $IntuneURL

            } elseif ($TenantID -eq 'Alpha Scan Computers LTD') {
                $TenantID = $ORGTenantID
                $IntuneURL = "https://intune.microsoft.com/$TenantID/#view/"

                # Update the 'Intune Management URL' field to show the relevant URL
                Update-CWCCustomProperty -GUID $SessionID -Property 7 -Value $IntuneURL

            }

            # Build report filter to search for TenantID
            $TenantIDReportFilter = @{
                id = 240
                filters = @(
                    @{
                        fieldname = 'Azure ID'
                        stringruletype = 2
                        stringruletext = "$($TenantID)"
                    }
                )
            }

            # Apply report filter 
            Set-HaloReport -Report $TenantIDReportFilter | Out-Null

            # Get report results
            $GetReportResults = Get-HaloReport -ReportID 240 -IncludeDetails -LoadReport
            $ReportResults = $GetReportResults.report.rows

            # Get Customer Name from TenantID
            $CustomerName = $ReportResults.'Customer Name'

            if ($HaloClientName) {
                # Do nothing
            } else {
                # Update the 'Company' field to show the relevant client name
                Update-CWCCustomProperty -GUID $SessionID -Property 0 -Value $CustomerName
            }

            # Set Device name as Session Name
            Update-CWCSessionName -GUID $SessionID -NewName $nameDetails.name

        } elseif ($DSRegCMDTable['AzureAdJoined'] -eq "No" -and $DSRegCMDTable['DomainJoined'] -eq "No") {
            Write-Host "Device is within a Workgroup, updating Custom Properties" -ForegroundColor Magenta

            # Update the 'Identity Provider' field to show 'Workgroup'
            Update-CWCCustomProperty -GUID $SessionID -Property 5 -Value "Workgroup"

            # Update the 'Join Status' field to 'Workgroup'
            Update-CWCCustomProperty -GUID $SessionID -Property 6 -Value "Workgroup"

            # Update the 'Device Type' field to show the relevant PCSystemType
            Update-CWCCustomProperty -GUID $SessionID -Property 3 -Value $pcSystemTypeMapping[$HardwareType]

            # Set Device name as Session Name
            Update-CWCSessionName -GUID $SessionID -NewName $nameDetails.name

        } elseif ($DSRegCMDTable['DomainJoined'] -eq "Yes" -and $DSRegCMDTable['AzureAdJoined'] -eq "Yes") {

            Write-Host "Device shows as both Domain Joined and Azure AD Joined, confirmation needed..." -ForegroundColor Magenta

            # Update the 'Identity Provider' field to show the relevant domain name
            Update-CWCCustomProperty -GUID $SessionID -Property 5 -Value $nameDetails.domain

            # Update the 'Join Status' field to 'AD Joined'
            Update-CWCCustomProperty -GUID $SessionID -Property 6 -Value "Domain Joined"

            # Update the 'Device Type' field to show the relevant PCSystemType
            Update-CWCCustomProperty -GUID $SessionID -Property 3 -Value $pcSystemTypeMapping[$HardwareType]

            # Set Device name as Session Name
            Update-CWCSessionName -GUID $SessionID -NewName $nameDetails.name

            # Log the device details to a file for review
            $deviceDetails | Out-File -FilePath "C:\Temp\CWCFailedDevices.txt" -Append

        }

    } else {
        Write-Host "Device is offline ... Skipping" -ForegroundColor Red
    }   

    Write-Host "Session $SessionID has been processed.. Moving to next device!" -ForegroundColor Yellow
}


<# Mapping of Custom Properties for reference
        0 = "Company"
        1 = "Location"
        2 = "Department"
        3 = "Device Type"
        4 = "Device Model"
        5 = "Identity Provider"
        6 = "Join Status"
        7 = "Intune URL"
#>