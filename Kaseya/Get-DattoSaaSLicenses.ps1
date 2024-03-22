<#	
	.NOTES
	 Created on:   	15/02/2024 14:11
	 Created by:   	Jacob Newman AKA @Jcblmao on GitHub
	 Organization: 	Alpha Scan Computers Ltd
	.DESCRIPTION
		A script used to query the Datto API for all customers and their 
        billable seats. 
        It will then update the customer in Halo with the correct number of 
        billable seats and create a licence if one does not exist.
    .INSTRUCTIONS
        You will need to add environment variables to your device for this script to work.
#>

# Get Az.KeyVault Module and install if not available
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
}
else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

# Get DattoAPI Module and installing.
If (Get-Module -ListAvailable -Name "DattoAPI") { 
    Import-Module DattoAPI
} Else { 
    Install-Module DattoAPI -Force; Import-Module DattoAPI
}

$DattoAPIEndpoint = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'DattoAPIEndpoint' -AsPlainText
$DattoAPIKey = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'DattoAPIKey' -AsPlainText
$DattoAPISecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'DattoAPISecret' -AsPlainText
$HaloClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientID' -AsPlainText
$HaloClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientSecret' -AsPlainText
$HaloScopes = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloScopes' -AsPlainText
$HaloURL = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloURL' -AsPlainText

# Set Datto logon information
Add-DattoBaseURI -base_uri $DattoAPIEndpoint
Add-DattoAPIKey -Api_Key_Public $DattoAPIKey -Api_Key_Secret $DattoAPISecret

# Connect to the Halo API
Connect-HaloAPI -URL $HaloURL -ClientID $HaloClientID -ClientSecret $HaloClientSecret -Scopes $HaloScopes

# Get Customers from Datto
$customers = Get-DattoSaaS

# Create hashtable to keep track of billable seats
$billableSeatsCount = @{}

# Loop all Datto customers
foreach ( $customer in $customers ) {
    
    # Get the saasCustomerId
    $DattoSaaSCustomerId = $customer.saasCustomerId

    # Initialize the count for this customer
    $billableSeatsCount[$customer.saasCustomerName] = 0

    # Get all seats
    $seats = Get-DattoSeat -saasCustomerId $DattoSaaSCustomerId
     
    # Loop all seats
    foreach ( $seat in $seats ) {
        
        # Get all billable seats
        if ($seat.billable) {

            # Increment the count for this customer
            $billableSeatsCount[$customer.saasCustomerName]++
        }
        else {
        }
    }
    
    # Print the count of billable seats for this customer
    Write-Host "Number of billable seats for '$($customer.saasCustomerName)' is $($billableSeatsCount[$customer.saasCustomerName])." -ForegroundColor Cyan
    
    # Build report filter to search for CFsaasCustomerID
    $SaaSCustomerIdReportFilter = @{
        id = 240
        filters = @(
            @{
                fieldname = 'DattoSaaSID'
                stringruletype = 2
                stringruletext = "$($DattoSaaSCustomerId)"
            }
        )
    }

    # Apply report filter 
    Set-HaloReport -Report $SaaSCustomerIdReportFilter | Out-Null

    # Get report results
    $GetReportResults = Get-HaloReport -ReportID 240 -IncludeDetails -LoadReport

    $ReportResults = $GetReportResults.report.rows

    $HaloCustomerID = $ReportResults.'Customer ID'
    $HaloDattoSaaSID = $ReportResults.'DattoSaaSID'
        
    # Match CFsaasCustomerID to Customerid
    if ($HaloDattoSaaSID -eq $DattoSaaSCustomerId) {

        # Match Successful
        Write-Host "ID's Match! `nChecking licenses for '$($customer.saasCustomerName)'" -ForegroundColor Green

        # Check if licence exists at customer
        # Build Report Filter to check for licence
        $LicenceReportFilter = @{
            id = 267
            filters = @(
                @{
                    fieldname = 'Customer ID'
                    numericruletype = 2
                    numericvalue = "$HaloCustomerID"
                }
                @{
                    fieldname = 'Status'
                    stringruletype = 0
                    stringrulevalues = @(
                        @{
                            value = 'Active'
                        },
                        @{
                            value = 'PendingCancel'
                        }
                    )
                }
                @{
                    fieldname = 'Deleted'
                    stringruletype = 0
                    stringrulevalues = @(
                        @{
                            value = 'False'
                        }
                    )
                }
            )
        }

        # Apply report filter
        Set-HaloReport -Report $LicenceReportFilter | Out-Null

        # Get licence report results
        $GetLicenceReportResults = Get-HaloReport -ReportID 267 -IncludeDetails -LoadReport

        # Get all licences
        $Licences = $GetLicenceReportResults.report.rows

        # Initialize match counter
        $matchCount = 0

        # Loop all licences
        foreach ( $licence in $licences ) {
        
            # Match correct licence
            if ($licence.license -match "^Datto SaaS Protection") {

                Write-Host "Found licence match!" -ForegroundColor Green

                # Increment match counter
                $matchCount++

                # Build update variable
                $LicenceUpdate = @{
                    id = $licence.'License ID'
                    count = $($billableSeatsCount[$customer.saasCustomerName])
                    client_id = $HaloCustomerID
                    supplier_id = 1630
                    vendor = 1630
                    manufacturer = "Datto"
                    billing_cycle = "Monthly"
                    term_duration = "Monthly"
                    status = "Active"
                    end_date = "1901-01-01T00:00:00"
                }

                Write-Host "Updating licence with id: $($licence.'License ID') for '$($Customer.saasCustomerName)'." -ForegroundColor Cyan

                Set-HaloSoftwareLicence -SoftwareLicence $LicenceUpdate | Out-Null
            }
            else {
                Write-Host "ID ($($licence.'License ID')) is not a match, moving on.." -ForegroundColor Red
            }
        }

        # Print total matches 
        Write-Host "Matched Licences for $($customer.saasCustomerName) is: $matchCount" -ForegroundColor Yellow

        # Create licence if there are no matched licences
        if ($matchCount -eq 0){

            Write-Host "No matches found, creating licence in Halo." -ForegroundColor Cyan

            # Build create variable
            $LicenceCreate = @{
                type = 1
                name = "Datto SaaS Protection - 1M ($($customer.retentionType))"
                count = $($billableSeatsCount[$customer.saasCustomerName])
                client_id = $HaloCustomerID
                supplier_id = 1630
                vendor = 1630
                manufacturer = "Datto"
                billing_cycle = "Monthly"
                term_duration = "Monthly"
                status = "Active"
                end_date = "1901-01-01T00:00:00"
                notes = "Created via PowerShell SaaS Licence script."
            }

            # Create licence on customer
            New-HaloSoftwareLicence -SoftwareLicence $LicenceCreate | Out-Null

            $newSubscription = Get-HaloSoftwareLicence -SoftwareLicence $LicenceCreate

            Write-Host "Succesfully created software subscription '$($newSubscription.name)' with id '$($newSubscription.id)'" -ForegroundColor Cyan
        }
        else {
        }
    }
}