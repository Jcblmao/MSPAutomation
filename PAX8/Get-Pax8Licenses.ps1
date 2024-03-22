# Get Pax8 secrets from Azure Vault
$Pax8ClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'Pax8ClientID' -AsPlainText
$Pax8ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'Pax8ClientSecret' -AsPlainText
$Pax8Audience = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'Pax8Audience' -AsPlainText

# Defince Pax8 connection parameters
$uri = "https://login.pax8.com/oauth/token"
$headers = @{
    "Content-Type" = "application/json"
}

$auth = @{
    client_id = $Pax8ClientID
    client_secret = $Pax8ClientSecret
    audience = $Pax8Audience
    grant_type = "client_credentials"
} 

$json = $auth | ConvertTo-Json -Depth 2

$response = Invoke-WebRequest -Method POST -Uri $uri -ContentType 'application/json' -Body $json
$Pax8Token = ($Response | ConvertFrom-Json).access_token


$subscriptionID = "9c602489-cede-4bc5-bb5b-97d3c25ae10e"
$usageSummaryID = "c6fee73b-56ee-4914-bec5-d90426df55f9"
$billingPeriod = "2024-02"

$uri = "https://api.pax8.com/v2/usage-summaries/$usageSummaryID/usage-lines"
$headers = @{
    "content-type" = "application/json"
    "Authorization" = "Bearer $Pax8Token"
}

$usage = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
$usage
