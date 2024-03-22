<#
    .NOTES
     Created on:   	2024-02-20 17:29:10
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
    .DESCRIPTION
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

# Check if the Az.KeyVault module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
} else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
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

# Create the PSCredential object
$CWCCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $CWCUsername, $CWCPassword
$ConnectCWC = @{
    Server = $CWCServer
    Credentials = $CWCCredentials
    secret = $CWCSecret | ConvertTo-SecureString -AsPlainText
}

# Connect to CWC API
Connect-CWC @ConnectCWC

# Load data from csv
$csvPath = "C:\temp\NinjaOneInstallers.csv"
$dataset = Import-Csv -Path $csvPath

# Prompt user for input until a valid company name is found
while ($true) {
    $companyName = Read-Host -Prompt "Enter the company name"

    # Search for user input in the "Organisation" column
    $matchingRows = $dataset | Where-Object { $_.Organisation -ilike "*$companyName*" }

    if ($matchingRows.Count -gt 0) {
        if ($matchingRows.Count -eq 1) {
            # Only one match or no duplicates
            $matchingRow = $matchingRows
        }
        else {
            # Handle duplicates by prompting for location
            Write-Host "Multiple matches found for '$companyName'. Please provide a location:"
            $locationName = Read-Host -Prompt "Enter the location"
            $matchingRow = $matchingRows | Where-Object { $_.Location -eq $locationName }
        }

        # Retrieve Installer URI
        $installerURI = $matchingRow.InstallerURI
        break
    }
    else {
        # No match found, suggest similar examples from the "Organisation" column
        $similarExamples = $dataset | Where-Object { $_.Organisation -ilike "*$companyName*" }
        if ($similarExamples) {
            Write-Host "Company name '$companyName' not found. Here are some similar examples:"
            $similarExamples | ForEach-Object {
                Write-Host "  $_.Organisation"
            }
        }
        else {
            Write-Host "No similar examples found for '$companyName'. Please try another company name."
        }
    }
}
$installerURI

# Define commands to use
$GetInstalledApps = 'powershell.exe "Get-WmiObject -Class Win32_InstalledWin32Program | Select-Object -Property Name, Version"'
$installNinjaRMM = "powershell.exe msiexec.exe /i $installeruri"

# Get all CWC sessions
$companySessions = Get-CWCSession -Type 'Access' -Group $CompanyName

# Loop all sessions
foreach ($session in $companySessions) {
    $SessionID = $session.SessionID

    # Get session detail
    $deviceDetails =  Get-CWCSessionDetails -GUID $SessionID
    $isOnline = $deviceDetails.Online

    Write-Host "Processing Session: $SessionID" -ForegroundColor Cyan
        
    if ($isOnline -eq "True") {

        Write-Host "Device is online, checking if NinjaOne is installed" -ForegroundColor Cyan
        
        # Run remote command to get installed applications
        $installedApps = Send-RemoteCommand -GUID $SessionID -Command $GetInstalledApps
        
        # Convert the output of installed apps command to a hashtable
        $lines = $installedApps -split "`n"
        $installedAppsTable = @{}
        foreach ($line in $lines[2..$lines.Length]) {
            $parts = $line -split '\s{2,}', 2
            $name = $parts[0].Trim()
            $version = $parts[1].Trim()
            $installedAppsTable[$name] = $version
        }

        # Check if NinjaRMM is installed
        $key = "NinjaRMMAgent"
        if ($installedAppsTable.ContainsKey($key)) {
            Write-Output "$key is installed with version $($installedAppsTable[$key])" -ForegroundColor Green
        } else {
            Write-Output "$key is not installed, installing now..." -ForegroundColor Yellow

            # Install NinjaRMM
            Send-RemoteCommand -GUID $SessionID -Command $installNinjaRMM



        }

    } else {
        Write-Host "Device is offline ... Skipping" -ForegroundColor Red
    }   

    Write-Host "Processing complete!" -ForegroundColor Green
}