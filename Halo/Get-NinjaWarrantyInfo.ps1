<#
    .NOTES
     Created on:   	2024-03-07 10:50:02
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
.DESCRIPTION
    description
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

# Check if the HaloAPI module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "HaloAPI") { 
    Import-Module HaloAPI
} else { 
    Install-Module HaloAPI -Force; Import-Module HaloAPI
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

# Get all devices from HaloPSA
$devices = Get-HaloAsset 