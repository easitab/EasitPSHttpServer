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
        [string]$fileName = "logs\updateAssetFromPricelist_$today.log",
    
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
    Write-CustomLog -Message "Retrieving all assets connected to pricelist with ID $($easitObjects.id)" -Level INFO
    # Using custom view
    $temp = Get-GOItems @easitWSParams -importViewIdentifier 'AssetsWithPricelist' -ColumnFilter "pricelistID,EQUALS,$($easitObjects.id)"
    Write-CustomLog -Message "Got all assets connected to pricelist with ID $($easitObjects.id)" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
$items = @()
foreach ($tempItem in $temp.Envelope.Body.GetItemsResponse.Items.GetEnumerator()) {
    $tempObj = New-Object -TypeName psobject
    foreach ($tempItemProp in $tempItem.Property.GetEnumerator()) {
        $tempObj | Add-Member -MemberType NoteProperty -Name "$($tempItemProp.Name)" -Value "$($tempItemProp.InnerText)"
    }
    $items += $tempObj
    
}
Write-CustomLog -Message "Ativities in items: $($items.count)" -Level INFO

try {
    foreach ($obj in $items) {
        try {
            Write-CustomLog -Message "Sending update to $($obj.id) with price $($easitObjects.price)" -Level INFO
            # Using custom importhandler
            Import-GOAssetItem @easitWSParams -ImportHandlerIdentifier 'UpdatePriceFromPricelist' -ID "$($obj.id)" -FinancialNotes "$($easitObjects.price)"
            Write-CustomLog -Message "Updated $($obj.id)" -Level INFO
        } catch {
            Write-CustomLog -InputObject $_ -Level ERROR
            return
        }
    }
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}

try {
    $pricelistUpdateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    Write-CustomLog -Message "Sending update to $($easitObjects.id) - $pricelistUpdateTime" -Level INFO
    # Using custom importhandler
    Import-GOAssetItem @easitWSParams -ImportHandlerIdentifier 'UpdatePriceFromPricelist' -ID "$($easitObjects.id)" -LastInventoryDate "$pricelistUpdateTime"
    Write-CustomLog -Message "Updated $($easitObjects.id)" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
Write-CustomLog -Message "Script ended"