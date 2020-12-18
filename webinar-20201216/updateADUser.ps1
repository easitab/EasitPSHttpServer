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
        [string]$fileName = "logs\updateADUser_$today.log",
    
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
if (Get-WindowsFeature -Name 'RSAT-AD-PowerShell') {
    Write-CustomLog -Message "RSAT-AD-PowerShell already feature installed" -Level Verbose
} else {
    try {
        Write-CustomLog -Message "Installing RSAT-AD-PowerShell feature" -Level Verbose
        Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop
        Write-CustomLog -Message "RSAT-AD-PowerShell feature installed" -Level Verbose
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
}
if (Get-WindowsFeature -Name 'gpmc') {
    Write-CustomLog -Message "GroupPolicy feature already installed" -Level Verbose
} else {
    try {
        Write-CustomLog -Message "Installing GroupPolicy feature" -Level Verbose
        Add-WindowsFeature gpmc -ErrorAction Stop
        Write-CustomLog -Message "GroupPolicy feature installed" -Level Verbose
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
}
try {
    $settings = Import-Csv -Path "$execDir\settings.csv" -Delimiter ';' -ErrorAction Stop
    Write-CustomLog -Message "Got settings file" -Level VERBOSE
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
try {
    $username = "$($settings.adUsername)"
    $password = ConvertTo-SecureString "$($settings.adPassword)" -AsPlainText -Force -ErrorAction Stop
    Write-CustomLog -Message "Converted password to secure string" -Level VERBOSE
    $serverCred = New-Object System.Management.Automation.PSCredential ($username,$password) -ErrorAction Stop
    Write-CustomLog -Message "Created PSCredential object" -Level VERBOSE
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
if ($easitObjects.disabled -eq 'true') { # Disable user in AD and Easit GO
    Write-CustomLog -Message "disabled = true" -Level VERBOSE
    try {
        Write-CustomLog -Message "Disabling account in Active Directory" -Level INFO
        Disable-ADAccount -Identity "$($easitObjects.username)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
        Write-CustomLog -Message "Account disabled in Active Directory" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
    try {
        Write-CustomLog -Message "Disabling account in Easit GO" -Level INFO
        # Using custom importhandler
        Import-GORequestItem -url "$($settings.url)" -apikey "$($settings.apikey)" -ImportHandlerIdentifier 'updateADUser' -Manager "$($easitObjects.username)" -Status "$($easitObjects.disabled)"
        Write-CustomLog -Message "Account disabled in Easit GO" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} elseif ($easitObjects.disabled -eq 'false') { # Enable user in AD and Easit GO
    Write-CustomLog -Message "disabled = false" -Level VERBOSE
    try {
        Write-CustomLog -Message "Enabling account in Active Directory" -Level INFO
        Enable-ADAccount -Identity "$($easitObjects.username)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
        Write-CustomLog -Message "Account enabled in Active Directory" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
    try {
        Write-CustomLog -Message "Enabling account in Easit GO" -Level INFO
        # Using custom importhandler
        Import-GORequestItem -url "$($settings.url)" -apikey "$($settings.apikey)" -ImportHandlerIdentifier 'updateADUser' -Manager "$($easitObjects.username)" -Status "$($easitObjects.disabled)"
        Write-CustomLog -Message "Account enabled in Easit GO" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else { # Failover
    Write-CustomLog -Message "disabled is not true or false" -Level INFO
}

Write-CustomLog -Message "Script end" -Level INFO
# Stop-Transcript