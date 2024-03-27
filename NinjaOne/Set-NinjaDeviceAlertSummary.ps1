# Check if the Az.KeyVault module is already imported, if not, install and import it
if (Get-Module -ListAvailable -Name "Az.KeyVault") { 
    Import-Module Az.KeyVault
}
else { 
    Install-Module Az.KeyVault -Force; Import-Module Az.KeyVault
}

$Start = Get-Date

$NinjaOneInstance = "eu.ninjarmm.com"
$NinjaOneClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneSSClientID' -AsPlainText
$NinjaOneClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneSSClientSecret' -AsPlainText

$OverviewCompany = 'Global Overview'
$SummaryField = 'deviceAlertSummary'

function Get-AlertsTable ($Alerts, $MaxChars, $CountAlerts) {

    [System.Collections.Generic.List[string]]$ParsedTable = @()

    if (($CountAlerts | Measure-Object).count -gt 0) {
  
        [System.Collections.Generic.List[PSCustomObject]]$WidgetData = @()
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-circle-xmark"></i>&nbsp;&nbsp;' + $(($CountAlerts | Where-Object { $_.Severity -eq 'CRITICAL' } | Measure-Object).count)
                Description = 'Critical'
                Colour      = '#D53948'
            })
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-triangle-exclamation"></i>&nbsp;&nbsp;' + $(($CountAlerts | Where-Object { $_.Severity -eq 'MAJOR' } | Measure-Object).count)
                Description = 'Major'
                Colour      = '#FAC905'
            })
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-circle-exclamation"></i>&nbsp;&nbsp;' + $(($CountAlerts | Where-Object { $_.Severity -eq 'MODERATE' } | Measure-Object).count)
                Description = 'Moderate'
                Colour      = '#337AB7'
            })
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-circle-exclamation"></i>&nbsp;&nbsp;' + $(($CountAlerts | Where-Object { $_.Severity -eq 'MINOR' } | Measure-Object).count)
                Description = 'Minor'
                Colour      = '#949597'
            })
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-circle-info"></i>&nbsp;&nbsp;' + $(($CountAlerts | Where-Object { $_.Severity -eq 'NONE' } | Measure-Object).count)
                Description = 'None'
                Colour      = '#949597'
            })
    

        $WidgetHTML = (Get-NinjaOneWidgetCard -Data $WidgetData -SmallCols 3 -MedCols 3 -LargeCols 5 -XLCols 5 -NoCard)
        $ParsedTable.add($WidgetHTML)
        $ParsedTable.add('<table>')
        $ParsedTable.add('<tr><th>Created</th><th></th><th>Device</th><th>Organization</th><th style="white-space: nowrap;">Severity</th><th style="white-space: nowrap;">Priority</th><th style="white-space: nowrap;">Last 30 Days</th><th>Message</th></tr>')

        foreach ($ParsedAlert in $Alerts) {
            $HTML = '<tr class="' + $ParsedAlert.RowClass + '">' +
            '<td style="white-space: nowrap;">' + ($ParsedAlert.Created).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") + '</td>' +
            '<td style="white-space: nowrap;"><i style="color: ' + $ParsedAlert.OnlineColour + ';" class="' + $ParsedAlert.OnlineIcon + '"></i></td>' +
            '<td style="white-space: nowrap;"><a href="https://' + $NinjaOneInstance + '/#/deviceDashboard/' + $ParsedAlert.DeviceID + '/overview">' + $ParsedAlert.Device + '</a></td>' +
            '<td style="white-space: nowrap;"><a href="https://' + $NinjaOneInstance + '/#/customerDashboard/' + $ParsedAlert.OrgID + '/overview">' + $ParsedAlert.OrgName + '</a></td>' +
            '<td style="white-space: nowrap;"><i style="color: ' + $ParsedAlert.SeverityColour + ';" class="' + $ParsedAlert.SeverityIcon + '"></i> ' + (Get-Culture).TextInfo.ToTitleCase($ParsedAlert.Severity.ToLower()) + '</td>' +
            '<td style="white-space: nowrap;"><i style="color: ' + $ParsedAlert.PiorityColour + ';" class="' + $ParsedAlert.PiorityIcon + '"></i> ' + (Get-Culture).TextInfo.ToTitleCase($ParsedAlert.Piority.ToLower()) + '</td>' +
            '<td style="white-space: nowrap;">' + $ParsedAlert.Last30Days + '</td>' +
            '<td>' + ($ParsedAlert.Message).Substring(0, [Math]::Min(($ParsedAlert.Message).Length, $MaxChars)) + '</td>' + '</tr>'

            $ParsedTable.add($HTML)
        }

        $ParsedTable.add('</table>')
    } else {
        [System.Collections.Generic.List[PSCustomObject]]$WidgetData = @()
        $WidgetData.add([PSCustomObject]@{
                Value       = '<i class="fas fa-circle-check"></i>'
                Description = 'No Alerts'
                Colour      = '#26a644'
            })
        $WidgetHTML = (Get-NinjaOneWidgetCard -Data $WidgetData -SmallCols 3 -MedCols 3 -LargeCols 5 -XLCols 5 -NoCard)
        $ParsedTable.add($WidgetHTML)
    }

    Return $ParsedTable
}

try {

    $moduleName = "NinjaOneDocs"
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Install-Module -Name $moduleName -Force -AllowClobber
    } else {
        $latestVersion = (Find-Module -Name $moduleName).Version
        $installedVersion = (Get-Module -ListAvailable -Name $moduleName).Version | Sort-Object -Descending | Select-Object -First 1

        if ($installedVersion -ne $latestVersion) {
            Update-Module -Name $moduleName -Force
        }
    }
    Import-Module $moduleName

    # Fix for PSCustomObjects being broken in 7.4.0
    $ExecutionContext.SessionState.LanguageMode = 'FullLanguage'

    Connect-NinjaOne -NinjaOneInstance $NinjaOneInstance -NinjaOneClientID $NinjaOneClientID -NinjaOneClientSecret $NinjaOneClientSecret
    Write-Output "$(Get-Date): Fetching Core Data"
    $Alerts = Invoke-NinjaOneRequest -Method GET -Path 'alerts' -Paginate
    $Devices = Invoke-NinjaOneRequest -Method GET -Path 'devices' -Paginate
    $Organizations = Invoke-NinjaOneRequest -Method GET -Path 'organizations' -Paginate
    $Locations = Invoke-NinjaOneRequest -Method GET -Path 'locations' -Paginate
    $CurrentAlerts = (Invoke-NinjaOneRequest -Method GET -Path 'queries/scoped-custom-fields' -QueryParams "fields=$SummaryField" -Paginate).results


    Write-Output "$(Get-Date): Fetching Activities"

    $31DaysAgo = Get-NinjaOneTime -Date ((Get-Date).adddays(-31)) -Seconds
    [System.Collections.Generic.List[PSCustomObject]]$Activities = (Invoke-NinjaOneRequest -Method GET -Path 'activities' -QueryParams "status=TRIGGERED&pageSize=1000&after=$31DaysAgo").activities

    $Count = ($Activities.id | measure-object -Minimum).minimum

    $PageSize = 1000

    $Found = $False
 
    do {

        $Result = Invoke-NinjaOneRequest -Method GET -Path 'activities' -QueryParams "status=TRIGGERED&pageSize=$($PageSize)&olderThan=$($Count)&after=$31DaysAgo"

        if (($Result.Activities | Measure-Object).count -gt 0) {
            $Activities.AddRange([System.Collections.Generic.List[PSCustomObject]]$Result.Activities)
            $Count = ($Result.Activities.id | measure-object -Minimum).Minimum
            $Measurement = $($Result.Activities.id | measure-object -Minimum -Maximum)
            Write-Host "Min: $($Measurement.Minimum) Max: $($Measurement.Maximum)"
        } else {
            $Found = $True
        }

    } while ($Found -eq $False)

    [System.Collections.Generic.List[PSCustomObject]]$ParsedAlerts = @()

    Write-Output "$(Get-Date): Processing Organizations"
    foreach ($Org in $Organizations) {
        Write-Host "$(Get-Date): Processing $($Org.name)"
        $OrgDevices = $Devices | where-object { $_.organizationId -eq $Org.id }
        $OrgAlerts = $Alerts | Where-Object { $_.deviceId -in $OrgDevices.id }
        Foreach ($Alert in $OrgAlerts) {
            $CurrentActivity = $Activities | Where-Object { $_.seriesUid -eq $Alert.uid }
            if (($CurrentActivity | Measure-Object).count -ne 1) {
                $AssociatedTriggers = $Null
                $CurrentActivity = (Invoke-NinjaOneRequest -Method GET -Path 'activities' -QueryParams "status=TRIGGERED&seriesUid=$($Alert.uid)").Activities
            }

            $AssociatedTriggers = $Activities | Where-Object { $_.sourceConfigUid -eq $Alert.sourceConfigUid -and $_.deviceId -eq $Alert.deviceId }
            $AlertDevice = $Devices | Where-Object { $_.id -eq $Alert.deviceId }
            $AlertLocation = $Locations | Where-Object { $_.id -eq $AlertDevice.locationId }
            
            if ($AlertDevice.offline -eq $True) {
                $OnlineColour = '#949597'
                $OnlineIcon = 'fas fa-plug'
            } else {
                $OnlineColour = '#26a644'
                $OnlineIcon = 'fas fa-plug'
            }

            Switch ($CurrentActivity.severity) {
                'CRITICAL' { $SeverityIcon = 'fas fa-circle-xmark'; $SeverityColour = '#D53948'; $SeverityScore = 5; $RowClass = 'danger' }
                'MAJOR' { $SeverityIcon = 'fas fa-triangle-exclamation'; $SeverityColour = '#FAC905'; $SeverityScore = 4; $RowClass = 'warning' }
                'MODERATE' { $SeverityIcon = 'fas fa-circle-exclamation'; $SeverityColour = '#337AB7 '; $SeverityScore = 3; $RowClass = 'other' }
                'MINOR' { $SeverityIcon = 'fas fa-circle-exclamation'; $SeverityColour = '#949597'; $SeverityScore = 2; $RowClass = 'unknown' }
                'NONE' { $SeverityIcon = 'fas fa-circle-info'; $SeverityColour = '#949597'; $SeverityScore = 1; $RowClass = '' }
                default { $SeverityIcon = 'fas fa-circle-info'; $SeverityColour = '#949597'; $SeverityScore = 1; $RowClass = '' }
            }

            Switch ($CurrentActivity.priority) {
                'HIGH' { $PiorityIcon = 'fas fa-circle-arrow-up'; $PiorityColour = '#D53948'; $PiorityScore = 5 }
                'MEDIUM' { $PiorityIcon = 'fas fa-circle-arrow-right'; $PiorityColour = '#FAC905'; $PiorityScore = 4 }
                'LOW' { $PiorityIcon = 'fas fa-circle-arrow-down'; $PiorityColour = '#337AB7'; $PiorityScore = 3 }
                'NONE' { $PiorityIcon = 'fas fa-circle-info'; $PiorityColour = '#949597'; $PiorityScore = 2 }
                default { $PiorityIcon = 'fas fa-circle-info'; $PiorityColour = '#949597'; $PiorityScore = 2 }
            }

            $TotalCount = ($AssociatedTriggers | Measure-Object).count
            $Last30DaysAlerts = $AssociatedTriggers | Where-Object { $_.activityTime -gt (Get-NinjaOneTime -Date (Get-Date).AddDays(-30) -Seconds) } | Sort-Object activityTime
        
            # Get the current date
            $today = Get-Date

            # Initialize variables to track consecutive days and status
            $consecutiveDays = 0
            $previousStatus = $null
            $HTMLHistory = ''

            # Loop through the last 30 days
            for ($i = 0; $i -le 30; $i++) {
                # Calculate the date to check
                $dateToCheck = $today.AddDays(-$i)

                # Check if any alerts were created on this date
                $alertsOnThisDay = $Last30DaysAlerts | Where-Object { (Get-TimeFromNinjaOne -Date ($_.activityTime) -Seconds).Date -eq $dateToCheck.Date }
                $currentStatus = if ($alertsOnThisDay.Count -gt 0) { "#D53948" } else { "#cccccc" }

                # Check if the status changed or it's the last iteration
                if ($currentStatus -ne $previousStatus -or $i -eq 30) {
                    if ($consecutiveDays -gt 0) {
                        # Calculate width of the span
                        $width = $consecutiveDays * 3  # Example width calculation
                        $color = if ($previousStatus -eq "#D53948") { "#D53948" } else { "#cccccc" }
                        $HTMLHistory = "<div style='background-color: $color; width: ${width}px;'></div>" + $HTMLHistory
                    }

                    # Reset for the new status
                    $consecutiveDays = 0
                }

                # Increment the day count and update the previous status
                $consecutiveDays++
                $previousStatus = $currentStatus
            }

            # End of HTML output
            $HTMLHistory = '<div style="display: flex; height: 20px;">' + $HTMLHistory + '</div>'

            $ParsedAlerts.add([PSCustomObject]@{
                    Created        = Get-TimeFromNinjaOne -Date $Alert.createTime -seconds
                    Updated        = Get-TimeFromNinjaOne -Date $Alert.updateTime -seconds
                    Device         = $AlertDevice.systemName
                    DeviceID       = $AlertDevice.id
                    OnlineIcon     = $OnlineIcon
                    OnlineColour   = $OnlineColour
                    OrgName        = $Org.name
                    OrgID          = $Org.id
                    LocName        = $AlertLocation.name
                    LocID          = $AlertLocation.id
                    Message        = $Alert.message
                    Severity       = if ($CurrentActivity.severity) { $CurrentActivity.severity } else { 'None' }
                    Piority        = if ($CurrentActivity.priority) { $CurrentActivity.priority } else { 'None' }
                    SeverityIcon   = $SeverityIcon 
                    SeverityColour = $SeverityColour
                    SeverityScore  = $SeverityScore
                    PiorityIcon    = $PiorityIcon
                    PiorityColour  = $PiorityColour
                    PiorityScore   = $PiorityScore
                    RowClass       = $RowClass
                    TotalCount     = $TotalCount
                    Last30Days     = $HTMLHistory
                })


        }

        $OrgAlertsTable = ($ParsedAlerts | Where-object { $_.OrgID -eq $Org.id } | Sort-Object SeverityScore, PiorityScore, Created -Descending)
        $ParsedTable = Get-AlertsTable -Alerts $OrgAlertsTable -CountAlerts $OrgAlertsTable  -MaxChars 300
        

        $OrgHTML = "$($ParsedTable -join '')"
        
        $CurrentAlert = $CurrentAlerts | Where-Object { $_.scope -eq 'ORGANIZATION' -and $_.entityId -eq $Org.id }
        if (($CurrentAlert.fields."$SummaryField".html -replace '<[^>]+>', '') -ne ($OrgHTML -replace '<[^>]+>', '')) {
            $OrgUpdate = [PSCustomObject]@{
                "$SummaryField" = @{'html' = $OrgHTML }
            }
            $Null = Invoke-NinjaOneRequest -Method PATCH -Path "organization/$($Org.id)/custom-fields" -InputObject $OrgUpdate
        }      

    }

    Write-Output "$(Get-Date): Generating Global View"
    # Set Global View
    $OverviewMatch = $Organizations | Where-Object { $_.name -eq $OverviewCompany }
    if (($OverviewMatch | Measure-Object).count -eq 1) {
        $ParsedTable = Get-AlertsTable -Alerts ($ParsedAlerts | Sort-Object SeverityScore, PiorityScore, Message, Created -Descending | select-object -first 100) -MaxChars 100 -CountAlerts $ParsedAlerts
        $GlobalHTML = "$($ParsedTable -join '')"
        
        $CurrentAlert = $CurrentAlerts | Where-Object { $_.scope -eq 'ORGANIZATION' -and $_.entityId -eq $OverviewMatch.id }
        if (($CurrentAlert.fields."$SummaryField".html -replace '<[^>]+>', '') -ne ($GlobalHTML -replace '<[^>]+>', '')) {
            $OrgUpdate = [PSCustomObject]@{
                "$SummaryField" = @{'html' = $GlobalHTML }
            }
            $Null = Invoke-NinjaOneRequest -Method PATCH -Path "organization/$($OverviewMatch.id)/custom-fields" -InputObject $OrgUpdate
        }
        
    }

    Write-Output "$(Get-Date): Processing Device Custom Fields"
    # Set Each Device
    Foreach ($UpdateDevice in $Devices) {
        $DeviceAlerts = ($ParsedAlerts | Where-object { $_.DeviceID -eq $UpdateDevice.id } | Sort-Object SeverityScore, PiorityScore, Created -Descending)
        $ParsedTable = Get-AlertsTable -MaxChars 300 -Alerts $DeviceAlerts -CountAlerts $DeviceAlerts
        $DeviceHTML = "$($ParsedTable -join '')"

        $CurrentAlert = $CurrentAlerts | Where-Object { $_.scope -eq 'NODE' -and $_.entityId -eq $UpdateDevice.id }

        if (($CurrentAlert.fields."$SummaryField".html -replace '<[^>]+>', '') -ne ($DeviceHTML -replace '<[^>]+>', '')) {
            $DeviceUpdate = [PSCustomObject]@{
                "$SummaryField" = @{'html' = $DeviceHTML }
            } 
            $Null = Invoke-NinjaOneRequest -Method PATCH -Path "device/$($UpdateDevice.id)/custom-fields" -InputObject $DeviceUpdate
        }
        
    }

    Write-Output "$(Get-Date): Processing Device Custom Fields" 

    Write-Output "$(Get-Date): Complete Total Runtime: $((New-TimeSpan -Start $Start -End (Get-Date)).TotalSeconds) seconds"

} catch {
    Write-Output "Failed to Generate Documentation: $_"
    exit 1
}

    # Copy information to Halo
    # Define the reconnection parameters for connecting to NinjaRMM API
    $ReconnectionParameters = @{
        Instance = 'eu'
        ClientID = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientID' -AsPlainText
        ClientSecret = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneClientSecret' -AsPlainText
        RefreshToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'NinjaOneRefreshToken' -AsPlainText
        UseTokenAuth = $True
    }
    
    # Connect to NinjaRMM API using the reconnection parameters
    Connect-NinjaOne @ReconnectionParameters
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
    <style>body{margin:0;background-color:white;word-break:break-word;font-family:inter,sans-serif;white-space:pre-wrap}*,::after,::before{box-sizing:border-box}img{max-width:100%;height:auto}h1,h2{margin-top:10px}blockquote{padding:10px 20px;margin:0 0 10px;border-left:5px solid #EEE;white-space:pre-wrap;overflow-wrap:break-word;word-break:break-word}ol,ul{list-style-type:revert}li,p,ul{color:#151617;font-size:14px;font-weight:400;word-wrap:break-word}ul.unstyled{list-style-type:none;padding:0;margin:0}h1{color:#151617;font-size:24px;font-weight:600;word-wrap:break-word}h2{color:#151617;font-size:20px;font-weight:500;word-wrap:break-word}h3{color:#151617;font-size:16px;font-weight:500;word-wrap:break-word}h4{color:#5B666C;font-size:14px;font-weight:400;word-wrap:break-word}h5{color:#5B666C;font-size:12px;font-weight:400;word-wrap:break-word}strong{color:#151617;font-size:14px;font-weight:600;word-wrap:break-word}a{color:#337AB7;text-decoration:none}a:hover{color:#23527c}a:active{color:#23527c}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:8px;border-bottom:.5px solid #CAD0D6}th{color:#151617;font-size:14px;font-weight:500;line-height:21px;word-wrap:break-word}td{color:#363B3E;font-size:14px;font-weight:400;line-height:21px;word-wrap:break-word}tbody tr:hover{background-color:#EFF1F3}tr.danger{padding:7px 8px;border-left:6px #D53948 solid}tr.warning{padding:7px 8px;border-left:6px #FAC905 solid}tr.success{padding:7px 8px;border-left:6px #007644 solid}tr.unknown{padding:7px 8px;border-left:6px #949597 solid}tr.other{padding:7px 8px;border-left:6px #337AB7 solid}.field-container{justify-content:center;align-items:center;max-width:100%;gap:10px;overflow:auto}.card{padding:24px;background:#FFF;border-radius:4px;border:.5px #CAD0D6 solid;flex-direction:column;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex}.card-title{color:#151617;font-size:16px;font-weight:500;line-height:24px;word-wrap:break-word}.card-title-box{align-self:stretch;justify-content:space-between;align-items:center;gap:149px;display:inline-flex}.card-link-box{border-radius:4px;justify-content:center;align-items:center;gap:8px;display:flex}.card-link{color:#337AB7;font-size:14px;font-weight:500;line-height:14px;word-wrap:break-word}.card-body{color:#151617;font-size:14px;font-weight:400;line-height:24px;word-wrap:break-word;width:100%}.stat-card{width:100%;padding:24px;border-radius:4px;border:.5px #CAD0D6 solid;flex-direction:column;gap:8px;display:inline-flex;justify-content:center;align-items:center;margin:0;padding-top:36px;padding-bottom:36px;text-align:Center;margin-bottom:24px;height:148px}.stat-value{height:50%;font-size:40px;color:#ccc;margin-bottom:10px}.stat-desc{height:50%;white-space:nowrap}.btn{padding:12px;background:#337AB7;border-radius:4px;justify-content:center;align-items:center;display:inline-flex;color:#FFF;font-size:14px;font-weight:500;line-height:14px;word-wrap:break-word;text-decoration:none;border:1px solid transparent;transition:background-color .3s ease,border-color .3s ease;outline:0}.btn:hover{background:#115D9F}.btn:focus{border:1px solid #337AB7}.btn.secondary{background:#FFF;color:#337AB7;padding:12.5px;border:.5px solid #CAD0D6}.btn.secondary:hover{background:#EFF1F3}.btn.secondary:focus{border-color:1px solid #337AB7}.btn.danger{background:#C6313A;color:#FFF;border:.5px solid transparent}.btn.danger:hover{background:#A71C25}.btn.danger:focus{border-color:1px solid #337AB7}.info-card{width:100%;padding:12px;background:#EBF2F8;border-radius:4px;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex;margin-bottom:10px}.info-icon{text-align:center;color:#337AB7;font-size:14px;font-weight:900;word-wrap:break-word}.info-text{flex-direction:column;justify-content:flex-start;align-items:flex-start;gap:8px;display:inline-flex}.info-title{color:#151617;font-size:14px;font-weight:600;word-wrap:break-word}.info-description{color:#151617;font-size:14px;font-weight:400;word-wrap:break-word}.info-card.error{background-color:#FBEBED}.info-card.error .info-icon{color:#C6313A}.info-card.warning{background-color:#FBEBED}.info-card.warning .info-icon{color:#FAC905}.info-card.success{background-color:#E6F2E5}.info-card.success .info-icon{color:#007644}.tag{padding:2px 8px;background:#018200;border-radius:2px;justify-content:center;align-items:center;gap:8px;display:inline-flex;color:#FFF;font-size:14px;font-weight:400;word-wrap:break-word}.tag.disabled{background:#E8E8EA;color:#6E6D7A}.tag.expired{background:#E8E8EA;color:#211F33}.close{position:absolute;top:24px;right:27px;color:#211F33;text-decoration:none;font-size:24px;font-weight:300}.nowrap{white-space:nowrap}.linechart{width:100%;height:50px;display:flex}.chart-key{display:inline-block;width:20px;height:20px;margin-right:10px}</style>
"@
    
    # Set a variable containing the html close tag to append to the html
    $htmlClose = @"
    </html>
"@
    
    # Combine the css, html and htmlclose variables to create html output
    $html = $css + $NinjaDeviceOverview.deviceAlertSummary.html + $htmlClose

    # Export the html to a file
    $html | Out-File -FilePath "C:\temp\NinjaDeviceOverview.html" -Force
    $filePath = "C:\temp\NinjaDeviceOverview.html"
    $repoOwner = "jcblmao"
    $repoName = "MSPAutomation"
    $branchName = "main"
    $commitMessage = "Update NinjaOne Device Overview"
    $gitHubToken = Get-AzKeyVaultSecret -VaultName 'jdev' -Name 'GithubToken' -AsPlainText

    # Get old HTML file's SHA blob
    $fileInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/contents/HTML/NinjaDeviceOverview.html" -Headers @{Authorization = "Bearer $gitHubToken"}
    $shaBlob = $fileInfo.sha

    # Delete old HTML
    $body = @{
        message = $commitMessage
        sha = $shaBlob
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/contents/HTML/NinjaDeviceOverview.html" -Method Delete -Body $body -Headers @{Authorization = "Bearer $gitHubToken"; 'Content-Type' = 'application/json'}

    $fileContent = Get-Content -Path $filePath -Raw
    $fileContentBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($fileContent))

    $body = @{
        path = "HTML"
        message = $commitMessage
        content = $fileContentBase64
        branch = $branchName
    } | ConvertTo-Json

    $headers = @{
        Authorization = "Bearer $gitHubToken"
    }

    Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/contents/HTML/NinjaDeviceOverview.html" -Method Put -Body $body -Headers $headers