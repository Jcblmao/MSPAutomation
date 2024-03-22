<#
    .NOTES
     Created on:   	2024-03-22 16:03:45
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
}
else { 
    Install-Module NinjaOne -Force; Import-Module NinjaOne
}

# Check if the HaloAPI module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "HaloAPI") { 
    Import-Module HaloAPI
}
else { 
    Install-Module HaloAPI -Force; Import-Module HaloAPI
}

# Define the reconnection parameters for connecting to NinjaRMM API
$NinjaReconnectionParameters = @{
    Instance     = 'eu'
    ClientID     = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientID' -AsPlainText
    ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientSecret' -AsPlainText
    RefreshToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneRefreshToken' -AsPlainText
    UseTokenAuth   = $True
}

# Connect to NinjaRMM API using the reconnection parameters
Connect-NinjaOne @NinjaReconnectionParameters

# Get device overview custom field contents from NinjaOne
$NinjaDeviceOverview = Get-NinjaOneOrganisationCustomFields -organisationId 82

# Set a variable containing the css content to prepend to the html
$css = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Inter">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
    <link rel="stylesheet" href="https://eu.ninjarmm.com/wysiwyg/css/regular.min.6.4.0.css" />
    <link rel="stylesheet" href="https://eu.ninjarmm.com/wysiwyg/css/solid.min.6.4.0.css" />
    <link rel="stylesheet" href="https://eu.ninjarmm.com/wysiwyg/css/brands.min.6.4.0.css" />
    <link rel="stylesheet" href="https://eu.ninjarmm.com/wysiwyg/css/bootstrap-grid.min.5.3.1.css" />
</head>
<style>body{margin:0;background-color:transparent;word-break:break-word;font-family:inter,sans-serif;white-space:pre-wrap}*,::after,::before{box-sizing:border-box}img{max-width:100%;height:auto}h1,h2{margin-top:10px}blockquote{padding:10px 20px;margin:0 0 10px;border-left:5px solid #EEE;white-space:pre-wrap;overflow-wrap:break-word;word-break:break-word}ol,ul{list-style-type:revert}li,p,ul{color:#151617;font-size:14px;font-weight:400;word-wrap:break-word}ul.unstyled{list-style-type:none;padding:0;margin:0}h1{color:#151617;font-size:24px;font-weight:600;word-wrap:break-word}h2{color:#151617;font-size:20px;font-weight:500;word-wrap:break-word}h3{color:#151617;font-size:16px;font-weight:500;word-wrap:break-word}h4{color:#5B666C;font-size:14px;font-weight:400;word-wrap:break-word}h5{color:#5B666C;font-size:12px;font-weight:400;word-wrap:break-word}strong{color:#151617;font-size:14px;font-weight:600;word-wrap:break-word}a{color:#337AB7;text-decoration:none}a:hover{color:#23527c}a:active{color:#23527c}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:8px;border-bottom:.5px solid #CAD0D6}th{color:#151617;font-size:14px;font-weight:500;line-height:21px;word-wrap:break-word}td{color:#363B3E;font-size:14px;font-weight:400;line-height:21px;word-wrap:break-word}tbody tr:hover{background-color:#EFF1F3}tr.danger{padding:7px 8px;border-left:6px #D53948 solid}tr.warning{padding:7px 8px;border-left:6px #FAC905 solid}tr.success{padding:7px 8px;border-left:6px #007644 solid}tr.unknown{padding:7px 8px;border-left:6px #949597 solid}tr.other{padding:7px 8px;border-left:6px #337AB7 solid}.field-container{justify-content:center;align-items:center;max-width:100%;gap:10px;overflow:auto}.card{padding:24px;background:#FFF;border-radius:4px;border:.5px #CAD0D6 solid;flex-direction:column;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex}.card-title{color:#151617;font-size:16px;font-weight:500;line-height:24px;word-wrap:break-word}.card-title-box{align-self:stretch;justify-content:space-between;align-items:center;gap:149px;display:inline-flex}.card-link-box{border-radius:4px;justify-content:center;align-items:center;gap:8px;display:flex}.card-link{color:#337AB7;font-size:14px;font-weight:500;line-height:14px;word-wrap:break-word}.card-body{color:#151617;font-size:14px;font-weight:400;line-height:24px;word-wrap:break-word;width:100%}.stat-card{width:100%;padding:24px;border-radius:4px;border:.5px #CAD0D6 solid;flex-direction:column;gap:8px;display:inline-flex;justify-content:center;align-items:center;margin:0;padding-top:36px;padding-bottom:36px;text-align:Center;margin-bottom:24px;height:148px}.stat-value{height:50%;font-size:40px;color:#ccc;margin-bottom:10px}.stat-desc{height:50%;white-space:nowrap}.btn{padding:12px;background:#337AB7;border-radius:4px;justify-content:center;align-items:center;display:inline-flex;color:#FFF;font-size:14px;font-weight:500;line-height:14px;word-wrap:break-word;text-decoration:none;border:1px solid transparent;transition:background-color .3s ease,border-color .3s ease;outline:0}.btn:hover{background:#115D9F}.btn:focus{border:1px solid #337AB7}.btn.secondary{background:#FFF;color:#337AB7;padding:12.5px;border:.5px solid #CAD0D6}.btn.secondary:hover{background:#EFF1F3}.btn.secondary:focus{border-color:1px solid #337AB7}.btn.danger{background:#C6313A;color:#FFF;border:.5px solid transparent}.btn.danger:hover{background:#A71C25}.btn.danger:focus{border-color:1px solid #337AB7}.info-card{width:100%;padding:12px;background:#EBF2F8;border-radius:4px;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex;margin-bottom:10px}.info-icon{text-align:center;color:#337AB7;font-size:14px;font-weight:900;word-wrap:break-word}.info-text{flex-direction:column;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex}.info-title{color:#151617;font-size:14px;font-weight:600;word-wrap:break-word}.info-description{color:#151617;font-size:14px;font-weight:400;word-wrap:break-word}.info-card.error{background-color:#FBEBED}.info-card.error .info-icon{color:#C6313A}.info-card.warning{background-color:#FBEBED}.info-card.warning .info-icon{color:#FAC905}.info-card.success{background-color:#E6F2E5}.info-card.success .info-icon{color:#007644}.tag{padding:2px 8px;background:#018200;border-radius:2px;justify-content:center;align-items:center;gap:8px;display:inline-flex;color:#FFF;font-size:14px;font-weight:400;word-wrap:break-word}.tag.disabled{background:#E8E8EA;color:#6E6D7A}.tag.expired{background:#E8E8EA;color:#211F33}.close{position:absolute;top:24px;right:27px;color:#211F33;text-decoration:none;font-size:24px;font-weight:300}.nowrap{white-space:nowrap}.linechart{width:100%;height:50px;display:flex}.chart-key{display:inline-block;width:20px;height:20px;margin-right:10px}</style>
"@

# Set a variable containing the html close tag to append to the html
$htmlClose = @"
</html>
"@

# Combine the css, html and htmlclose variables to create html output
$html = $css + $NinjaDeviceOverview.deviceAlertSummary.html + $htmlClose

# Export the html to a file
$html | Out-File -FilePath "C:\temp\NinjaDeviceOverview.html" -Force