<#
    .NOTES
     Created on:   	2024-03-06 11:25:38
     Created by:   	Jacob Newman AKA @Jcblmao
     Organization: 	Alpha Scan Computers Ltd
.DESCRIPTION
    This script is used to quickly set the review status of tickets in Halo.
#>

# Get Az.KeyVault Module and install if not available
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
}
else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

# Get HaloAPI Module and install if not available
If (Get-Module -ListAvailable -Name "HaloAPI") { 
    Import-Module HaloAPI
} Else { 
    Install-Module HaloAPI -Force; Import-Module HaloAPI
}

$HaloClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientID' -AsPlainText
$HaloClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloClientSecret' -AsPlainText
$HaloScopes = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloScopes' -AsPlainText
$HaloURL = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'HaloURL' -AsPlainText

# Connect to the Halo API
Connect-HaloAPI -URL $HaloURL -ClientID $HaloClientID -ClientSecret $HaloClientSecret -Scopes $HaloScopes

# Prompt user to provide name of client to review/unreview
$ClientName = Read-Host -Prompt "Enter the name of the client to review/unreview"

# Search Halo for the client
$Client = Get-HaloClient -Search $ClientName

# If the client is found, prompt user for the review status
if ($Client) {
    $Tickets = Get-HaloTicket -ClientID $Client.id
    $reviewStatus = Read-Host -Prompt "Enter 'True' to mark as reviewed, 'False' to unreview"
} else {
    Write-Host "Client not found"
}

# Set tickets to be reviewed/unreviewed
foreach ($Ticket in $Tickets) {
    $id = $Ticket.id
    $idsummary = $Ticket.idsummary

    Write-Host "Processing ticket $idsummary" -ForegroundColor Yellow

    # Create update object
    $Update = @{
        id = $id
        reviewed = $reviewStatus
    }

    if ($reviewStatus -eq "True") {
        Write-Host "Updating ticket $($Ticket.id) to be reviewed" -ForegroundColor Cyan

        # Update the ticket
        Set-HaloTicket -Ticket $Update | Out-Null

        Write-Host "Ticket $($Ticket.id) has been marked as reviewed" -ForegroundColor Green

    } else {
        Write-Host "Ticket should be unreviewed, however due to a bug in the system, we first need to mark it as reviewed and then unreview it" -ForegroundColor Red
        
        Write-Host "Updating ticket $($Ticket.id) to be reviewed" -ForegroundColor Cyan
        # Set $reviewStatus to True
        $Update.reviewed = "True"
        # Update the ticket
        Set-HaloTicket -Ticket $Update | Out-Null
        
        Write-Host "Updating ticket $($Ticket.id) to be unreviewed" -ForegroundColor Cyan
        # Set $reviewStatus to False
        $Update.reviewed = "False"
        # Update the ticket
        Set-HaloTicket -Ticket $Update | Out-Null

        Write-Host "Ticket $($Ticket.id) has been marked as unreviewed" -ForegroundColor Green
    }
    <#
    Write-Host "Due to unknown bugs, we also need to check the actions on the ticket and mark them as unreviewed if necessary" -ForegroundColor Red

    # Check each action on the ticket to ensure nothing is missed
    $Actions = Get-HaloAction -TicketID $id

    foreach ($action in $Actions) {
        $actionID = $action.id
        Write-Host "Checking action $actionID"
        # Get more action details
        $fullaction = Get-HaloAction -ActionID $actionID -TicketID $id
        $reviewed = $fullaction.actreviewed
        if ($reviewed -eq "True") {
            # Build update object
            $actionUpdate = @{
                ticket_id = $id
                id = $actionID
                actreviewed = $reviewStatus
            }
            Write-Host "Updating action $actionID to be unreviewed" -ForegroundColor Cyan
            Set-HaloAction -Action $actionUpdate | Out-Null
            Write-Host "Action $actionID has been marked as unreviewed" -ForegroundColor Green
        } else {
            # Build update object
            $actionUpdate = @{
                ticket_id = $id
                id = $actionID
                actreviewed = "True"
            }
            Write-Host "Action $actionID is already unreviewed, marking as reviewed and then reverting back to unreviewed" -ForegroundColor Cyan
            Set-HaloAction -Action $actionUpdate | Out-Null
            $actionUpdate.actreviewed = "False"
            Set-HaloAction -Action $actionUpdate | Out-Null
            Write-Host "Action $actionID has been marked as unreviewed" -ForegroundColor Green
        }
    } 
    #>
}