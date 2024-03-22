# Import the module
if (Get-module -ListAvailable -Name "icukAPI") { 
    Import-Module icukAPI
} else { 
    # Define the module name and URL
    $moduleName = "icukAPI"
    $moduleUrl = "https://raw.githubusercontent.com/Jcblmao/icukAPI/main/src/icukAPI/icukAPI.psm1?token=GHSAT0AAAAAACMTGMEXIMXZHDNLSNLVMMEWZO4W3YQ"

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