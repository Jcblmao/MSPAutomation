function Get-KQMSalesOrder {
    <#
        .SYNOPSIS
            Gets sales orders from the Kaseya Quote Manager API.
        .DESCRIPTION
            Retrieves sales orders from the Kaseya Quote Manager API - supports a variety of filtering parameters.
        .OUTPUTS
            A powershell object containing the response.
    #>
    [CmdletBinding()]
    Param(
        # Sales Order ID
        [Parameter(Mandatory=$false)]
        [Int64]$SalesOrderID,
    )
    






}



# Define API base URL
$baseUrl = "https://api.kaseyaquotemanager.com/v1"

# Define the endpoint
$endpoint = "SalesOrderLine"

$SalesOrderID = 2197

# Define the full URL
$url = "$baseUrl/$endpoint"+"?salesorderID="+"$SalesOrderID"

# Get the API key from Azure Key Vault
$apiKey = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'KaseyaQuoteManagerAPIKey' -AsPlainText

# Define the headers for use within this script
$headers=@{}
$headers.Add("content-type", "application/x-www-form-urlencoded")
$headers.Add("apiKey", $apiKey)

# Send the request
$response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body '='

$response = $response.Content | ConvertFrom-Json


foreach ($line in $response) {
    $line
}




__________________________________________




$quote = Get-HaloQuote -QuoteID 181
$quoteLines = $quote.lines

foreach ($line in $quoteLines) {
    # Print important information about the quote line
    Write-Host "Product Code: $($line.productcode)"
    Write-Host "Item ID: $($line.item_id)"
    Write-Host "Item Recurring: $($line.item_recurring)"
    Write-Host "Name: $($line.Name)"
    Write-Host "Price: $($line.Price)"
    Write-Host "Net Total: $($line.net_total)"
    Write-Host "Base Price: $($line.baseprice)"
    Write-Host "Cost Price: $($line.costprice)"
    Write-Host "Profit: $($line.profit)"
    Write-Host "Quantity: $($line.quantity)"
    Write-Host "Tax: $($line.tax)`n"
    Write-Host "Total Price: $($line.total_price)"
    Write-Host "Net Total Total: $($line.total_net_total)"
    Write-Host "Total Cost Price: $($line.total_costprice)"
    Write-Host "Total Profit: $($line.total_profit)"
    Write-Host "Total Tax: $($line.total_tax)`n"
    Start-Sleep -Seconds 10
}
