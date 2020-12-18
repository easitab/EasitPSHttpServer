param(
    $execDir, # Ex: $execDir = D:\Easit\PSHttpServer\resources
    $easitObjects # Object that hold all properties from the Easit object (Contact, Org, Status, Priority)
)

$today = Get-Date -Format "yyyy-MM-dd"
function Write-CustomLog {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline,ParameterSetName='string')]
        [string]$Message,
    
        [Parameter(ValueFromPipeline,ParameterSetName='object')]
        [object]$InputObject,
    
        [Parameter()]
        [string]$fileName = "logs\updateEmploymentActivities_$today.log",
    
        [Parameter()]
        [string]$Path = "$execDir\$fileName",
        
        [Parameter()]
        [ValidateSet('ERROR','WARN','INFO','VERBOSE','DEBUG')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$LogLevelSwitch = 'INFO'
    )
    # Format Date for our Log File
    $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($InputObject -and $Level -eq 'ERROR') {
        $Message = $InputObject.Exception
    }
    if ($InputObject -and $Level -ne 'ERROR') {
        $Message = $InputObject.ToString()
    }

    if (!(Test-Path $Path)) {
        $NewLogFile = New-Item "$Path" -Force -ItemType File
        "$FormattedDate - INFO - Created $NewLogFile" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
    }
    
    # Write message to error, warning, or verbose pipeline
    if ($Level -eq 'ERROR') {
        Write-Error "$Message" -ErrorAction Continue
        "$FormattedDate - $Level - $Message" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        if ($InputObject) {
            $InputObject | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        }
    } elseif ($Level -eq 'WARN') {
        Write-Warning "$Message" -WarningAction Continue
        "$FormattedDate - $Level - $Message" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        if ($InputObject) {
            $InputObject | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        }
    } elseif ($Level -eq 'INFO') {
        Write-Output "$Message"
        "$FormattedDate - $Level - $Message" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        if ($InputObject) {
            $InputObject | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
        }
    } elseif ($Level -eq 'VERBOSE') {
        Write-Verbose $Message
        if ($LogLevelSwitch -eq 'VERBOSE' -or $LogLevelSwitch -eq 'DEBUG') {
            "$FormattedDate - $Level - $Message" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
            if ($InputObject) {
                $InputObject | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
            }
        }
    } elseif ($Level -eq 'DEBUG' -and $LogLevelSwitch -eq 'DEBUG') {
        $DebugPreference = 'Continue'
        Write-Debug $Message
        if ($LogLevelSwitch -eq 'DEBUG') {
            "$FormattedDate - $Level - $Message" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
            if ($InputObject) {
                $InputObject | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
            }
        }
        $DebugPreference = ''
    } else {
        ## Nothin to do
    }
}

Write-CustomLog -Message "Script started" -Level INFO
try {
    $settings = Import-Csv -Path "$execDir\settings.csv" -Delimiter ';' -ErrorAction Stop
    Write-CustomLog -Message "Got settings file" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}

$easitWSParams = @{
    url = "$($settings.url)"
    apikey = "$($settings.apikey)"
}
try {
    # Using custom view
    $temp = Get-GOItems @easitWSParams -importViewIdentifier 'RequestNewEmploymentActivites' -ColumnFilter "ParentID,EQUALS,$($easitObjects.parentId)"
    Write-CustomLog -Message "Got all activities for employment request $($easitObjects.parentId)" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
$items = @()
$completedActivities = @()
$ongoingActivities = @()
$notStartedActivities = @()
foreach ($tempItem in $temp.Envelope.Body.GetItemsResponse.Items.GetEnumerator()) {
    $tempObj = New-Object -TypeName psobject
    foreach ($tempItemProp in $tempItem.Property.GetEnumerator()) {
        # Write-CustomLog -Message "$($tempItemProp.Name) - $($tempItemProp.InnerText)" -Level INFO
        $tempObj | Add-Member -MemberType NoteProperty -Name "$($tempItemProp.Name)" -Value "$($tempItemProp.InnerText)"
    }
    $tempString = "$($tempObj.Aktivitetsstatus)"
    if ("$tempString" -match '^P.+') {
        # Write-CustomLog -Message "$tempString eq $($tempObj.Aktivitetsstatus) - ParentID = $($tempObj.parentId) - ID $($tempObj.id)" -Level INFO
    } elseif ("$tempString" -match '^Ej.+') {
        # Write-CustomLog -Message "$tempString eq $($tempObj.Aktivitetsstatus) - ParentID = $($tempObj.parentId) - ID $($tempObj.id)" -Level INFO
    } elseif ("$tempString" -match '^A.+') {
        # Write-CustomLog -Message "$tempString eq $($tempObj.Aktivitetsstatus) - ParentID = $($tempObj.parentId) - ID $($tempObj.id)" -Level INFO
    } else {
        Write-CustomLog -Message "No match was done, $($tempObj.Aktivitetsstatus)" -Level INFO
    }
    #Write-CustomLog -Message "Aktivitetsstatus = $($tempObj.Aktivitetsstatus) - ParentID = $($tempObj.parentId) - ID $($tempObj.id)" -Level INFO
    $items += $tempObj
    
}
Write-CustomLog -Message "Ativities in items: $($items.count)" -Level INFO

$completedActivities = $items | Where-Object -Property Aktivitetsstatus -Match '^A.+'
$ongoingActivities = $items | Where-Object -Property Aktivitetsstatus -Match '^P.+'
$notStartedActivities = $items | Where-Object -Property Aktivitetsstatus -Match '^E.+'

$ongoingActivitiesStage1 = $ongoingActivities | Where-Object -Property Stadie -EQ '1'
$notStartedActivitiesStage1 = $notStartedActivities | Where-Object -Property Stadie -EQ '1'

$ongoingActivitiesStage2 = $ongoingActivities | Where-Object -Property Stadie -EQ '2'
$notStartedActivitiesStage2 = $notStartedActivities | Where-Object -Property Stadie -EQ '2'

$notStartedActivitiesStage3 = $notStartedActivities | Where-Object -Property Stadie -EQ '3'

if ($notStartedActivities) {
    Write-CustomLog -Message "There are some activites to be started!" -Level INFO
    if ($notStartedActivitiesStage1) {
        Write-CustomLog -Message "Some ativities in stage 1 have not been started!" -Level INFO
    } else {
        Write-CustomLog -Message "All ativities in stage 1 have been started!" -Level INFO
        if ($ongoingActivitiesStage1) {
            Write-CustomLog -Message "There are ongoing ativities in stage 1!" -Level INFO
        } else {
            Write-CustomLog -Message "There are NO ongoing ativities in stage 1!" -Level INFO
            if ($notStartedActivitiesStage2) {
                Write-CustomLog -Message "Updating not started activeties in stage 2!" -Level INFO
                foreach ($activity in $notStartedActivitiesStage2) {
                    try {
                        Write-CustomLog -Message "Sending update to $($activity.Id)" -Level INFO
                        # Using custom importhandler
                        Import-GORequestItem @easitWSParams -ImportHandlerIdentifier 'updateEmploymentActivity' -ID "$($activity.Id)" -Status "ongoing"
                        Write-CustomLog -Message "Updated $($activity.Id)!" -Level INFO
                    } catch {
                        Write-CustomLog -InputObject $_ -Level ERROR
                        return
                    }
                }
            } else {
                Write-CustomLog -Message "All ativities in stage 2 have been started!" -Level INFO
                if ($ongoingActivitiesStage2) {
                    Write-CustomLog -Message "There are ongoing ativities in stage 2!" -Level INFO
                } else {
                    Write-CustomLog -Message "There are NO ongoing ativities in stage 2!" -Level INFO
                    if ($notStartedActivitiesStage3) {
                        Write-CustomLog -Message "Updating not started activeties in stage 3!" -Level INFO
                        foreach ($activity in $notStartedActivitiesStage3) {
                            try {
                                Write-CustomLog -Message "Sending update to $($activity.Id)" -Level INFO
                                # Using custom importhandler
                                Import-GORequestItem @easitWSParams -ImportHandlerIdentifier 'updateEmploymentActivity' -ID "$($activity.Id)" -Status "ongoing"
                                Write-CustomLog -Message "Updated $($activity.Id)" -Level INFO
                            } catch {
                                Write-CustomLog -InputObject $_ -Level ERROR
                                return
                            }
                        }
                    } else {
                    }
                }
            }
        }
    }
} else {
    Write-CustomLog -Message "All ativities have been started!" -Level INFO
    if ($ongoingActivities) {
        Write-CustomLog -Message "There are ongoing ativities!" -Level INFO
    } else {
        Write-CustomLog -Message "There are NO ongoing ativities!" -Level INFO
        if ($completedActivities) {
            Write-CustomLog -Message "There are completed ativities!" -Level INFO
        } else {
            Write-CustomLog -Message "There are NO completed ativities!" -Level INFO
        }
    }
}
Write-CustomLog -Message "Script ended" -Level INFO