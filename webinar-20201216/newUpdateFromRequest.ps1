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
        [string]$fileName = "logs\newUpdateFromRequest_$today.log",
    
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
function Send-MessageToTeams {
    [CmdletBinding()]
    param (
        [string] $Title = 'From Powershell',
        [string] $TitleText = 'A new request have been created',
        [string] $ActivityTitle = 'Request details',
        [string] $ActivitySubtitle = 'Section Subtitle',
        [string] $ActivityText = 'Hashtag someone?'
    )
    
    begin {
        $URI = ''
        # More information here: https://adamtheautomator.com/creating-adaptive-cards-via-teams-incoming-webhooks-using-powershell/
    }
    
    process {
        # @type - Must be set to `MessageCard`.
        # @context - Must be set to [`https://schema.org/extensions`](<https://schema.org/extensions>).
        # title - The title of the card, usually used to announce the card.
        # text - The card's purpose and what it may be describing.
        # activityTitle - The title of the section, such as "Test Section", displayed in bold.
        # activitySubtitle - A descriptive subtitle underneath the title.
        # activityText - A longer description that is usually used to describe more relevant data.

        $JSON = @{
            "@type"    = "MessageCard"
            "@context" = "<http://schema.org/extensions>"
            "title"    = "$Title"
            "text"     = "$TitleText"
            "sections" = @(
            @{
                "activityTitle"    = "$ActivityTitle"
                "activitySubtitle" = "$ActivitySubtitle"
                "activityText"     = "$ActivityText"
            }
            )
        } | ConvertTo-JSON
        $body = [System.Text.Encoding]::UTF8.GetBytes($json)
        # You will always be sending content in via POST and using the ContentType of 'application/json'
        # The URI will be the URL that you previously retrieved when creating the webhook
        $Params = @{
            "URI"         = $URI
            "Method"      = 'POST'
            "Body"        = $body
            "ContentType" = 'application/json'
        }
        try {
            Invoke-RestMethod @Params -ErrorAction Stop
        } catch {
            throw $_
        }
    }
    
    end {
        
    }
}
Write-CustomLog -Message "Script started" -Level INFO


try {
    Send-MessageToTeams -Title "$($easitObjects.itemtype) har skapats" -TitleText "$($easitObjects.itemtype) #$($easitObjects.id)" -ActivitySubtitle "$($easitObjects.subject)" -ActivityText "$($easitObjects.description)"
    Write-CustomLog -Message "Successfully sent message to Teams"
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
}
Write-CustomLog -Message "Script ended" -Level INFO