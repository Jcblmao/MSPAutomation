if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
}
else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

$HaloClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientID' -AsPlainText
$HaloClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientSecret' -AsPlainText
$HaloScopes = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloScopes' -AsPlainText
$HaloURL = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloURL' -AsPlainText
$WasabiAccessKey = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'WasabiAccessKey' -AsPlainText
$WasabiSecretKey = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'WasabiSecretKey' -AsPlainText

# Get the current date
$currentDate = Get-Date

# Calculate the start of last month
$fromDate = $currentDate.AddMonths(-1).ToString("yyyy-MM-01")

# Calculate the end of last month
$toDate = $currentDate.AddDays(-$currentDate.Day).ToString("yyyy-MM-dd")

# Define the API URL with the calculated dates
$apiUrl = "https://billing.wasabisys.com/utilization/bucket/?withname=true&from=$fromDate&to=$toDate"

# Define the authentication header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "$WasabiAccessKey" + ":" + "$WasabiSecretKey")

# Send a request to the API
try {
    $Buckets = Invoke-RestMethod -Uri $apiUrl -Method 'GET' -Headers $headers -SkipHeaderValidation
} catch {
    Write-Host $_.Exception.Response.StatusCode.value__
    Write-Host $_.Exception.Message
    Write-Host $_.Exception | Format-List -Force
}

# Connect to the Halo API
Connect-HaloAPI -ClientID $HaloClientID -ClientSecret $HaloClientSecret -Scopes $HaloScopes -URL $HaloURL

# Get all customers with wasabi bucket id from Halo
$allClients = Get-HaloClient -Fullobjects 
$WasabiClients = $allClients | Where-Object {
    $_.customfields -match 'CFWasabiBucketID' -and $_.customfields.value -ne $null
}

# Loop all Wasabi clients
foreach ($client in $WasabiClients) {
    # Get the Wasabi bucket ID
    $WasabiBucketID = $client.customfields | Where-Object { $_.name -eq 'CFWasabiBucketID' } | Select-Object -ExpandProperty value

    # Get the Wasabi bucket from the API
    $WasabiBucket = $Buckets | Where-Object { $_.bucketId -eq $WasabiBucketID }

    # Print the Wasabi bucket usage
    Write-Host "The Wasabi bucket '$($WasabiBucket.bucketName)' used $($WasabiBucket.size) GB of storage in the last month." -ForegroundColor Cyan
}

# Build report to search for CFWasabiBucketID
$WasabiBucketIDReportFilter = @{
    id = 240
    filters = @(
        @{
            fieldname = 'WasabiBucketID'
            stringruletype = 2
            stringruletext = "$($WasabiBucketID)"
        }
    )
}


<# Create hashtable to keep track of billable seats
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
    
    # Build report filter to search CFsaasCustomerID
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

<# 

# Print all customers and their number of billable seats
Write-Host "`nFinal count of billable seats for each customer:" -ForegroundColor Yellow

$billableSeatsCount.GetEnumerator() | Sort-Object Name | ForEach-Object {
 
       $HaloSoftwareLicenseCreate = @{
            name = Datto SaaS Protection
            product_sku = 
            vendor_product_sku =
            count = $($_.Value)
            purchase_price =
            price =
            start_date = 
            end_date =
            billing_cycle = Monthly
            autorenew = True
            vendor =
            distributor =
            manufacturer = 
            supplier_name =
            is_active = True
            deleted = False
            requested_quantity =
            requested_quantity_date =
        }

    Write-Host "Customer Name: $($_.Name), Number of billable seats: $($_.Value)" -ForegroundColor Cyan
}

#>