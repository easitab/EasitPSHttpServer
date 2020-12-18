param(
    $execDir, # Ex: $execDir = D:\PSHttpServer\resources
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
        [string]$fileName = "logs\getGPO_$today.log",
    
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
Import-Module 'EasitGoWebservice' -Force
try {
    $settings = Import-Csv -Path "$execDir\settings.csv" -Delimiter ';' -ErrorAction Stop
    Write-CustomLog -Message "Got settings file" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
try {
    Write-CustomLog -Message "Retrieving GPInheritance for OU" -Level INFO
    $gpoLinks = (Get-GPInheritance -Target "$($easitObjects.ou)").GpoLinks
    Write-CustomLog -Message "Retrieved GPInheritance for OU" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
}
$easitGoWsParam = @{
    url = "$($settings.url)"
    api = "$($settings.apikey)"
}
[int]$count = $gpoLinks.Count
foreach ($link in $gpoLinks) {
    try {
        $gpo = Get-GPO -Guid "$($link.GpoId)" -ErrorAction Stop
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
    $itemToUpdate = @{
        ID = "$($easitObjects.id)"
        ModelMonitor = "$($gpo.Id)"
        Status = "$($gpo.GpoStatus)"
        ProjectDebit = "$($gpo.CreationTime)"
        RoomLocation = "$($gpo.ModificationTime)"
        ObjectDebit = "$($gpo.DomainName)"
        Manufacturer = "$($gpo.Description)"
        CityLocation = "$($gpo.DisplayName)"
        Impact = "$count"
    }
    try {
        Write-CustomLog -Message "Updating GPO in Easit GO" -Level INFO
        # Using custom importhandler
        Import-GOAssetItem @easitGoWsParam -ImportHandlerIdentifier 'getOrgsGPO' @itemToUpdate -ErrorAction Stop
        Write-CustomLog -Message "GPO updated in Easit GO" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
    $count = $count - 1
}
Write-CustomLog -Message "Script ended" -Level INFO