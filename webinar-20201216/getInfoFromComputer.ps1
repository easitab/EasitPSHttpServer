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
        [string]$logname = 'getInfoFromComputer',

		[Parameter()]
        [string]$logFolderName = 'logs',
	
		[Parameter(Mandatory=$false)]
		[Alias('LogPath')]
		[string]$Path = (Join-Path -Path "$execDir" -ChildPath "${logFolderName}\${logname}_${today}.log"),
        
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
    if (Test-Path $Path) {
		$logDir = Split-Path -Path $Path
        $logArchiveFiles = Get-ChildItem -Path "$logDir\${logname}_*.log" -Force
        foreach ($logArchiveFile in $logArchiveFiles) {
            if ($logArchiveFile.CreationTime -lt ((Get-Date).AddDays(-30))) {
                "$($logArchiveFile.Name) is older than 30 days, removing.." | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
				try {
					Remove-Item "$($logArchiveFile.FullName)" -Force
				} catch {
					Write-Error $_
					exit
				}
                "Removed $($logArchiveFile.Name)" | Out-File -FilePath "$Path" -Encoding UTF8 -Append -NoClobber
            }
        }
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
if ("$($easitObjects.ipAdress)" -match '^l.+') {
    $localhost = $true
}
try {
    $username = "$($settings.adUsername)"
    $password = ConvertTo-SecureString "$($settings.adPassword)" -AsPlainText -Force -ErrorAction Stop
    Write-CustomLog -Message "Converted password to secure string" -Level INFO
    $serverCred = New-Object System.Management.Automation.PSCredential ($username,$password) -ErrorAction Stop
    Write-CustomLog -Message "Created PSCredential object" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
if ($localhost) {
    Write-CustomLog -Message "Localhost is true" -Level INFO
} else {
    try {
        $session = New-CimSession -ComputerName "$($easitObjects.ipAdress)" -Credential $serverCred -ErrorAction Stop
    } catch {
        Remove-CimSession $session
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

try {
    $installedHotFixes = Get-HotFix -ErrorAction Stop # Only executed local, need to be changed to support remote computers
    foreach ($hotfix in $installedHotFixes) {
        if ($hotfixes) {
            $hotfixes = "$hotfixes `n$($hotfix.HotFixID) - $($hotfix.Description) - $($hotfix.InstalledOn)"
        } else {
            $hotfixes = "$($hotfix.HotFixID) - $($hotfix.Description) - $($hotfix.InstalledOn)"
        }
    }
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}

$easitWSParams = @{
    url = "$($settings.url)"
    apikey = "$($settings.apikey)"
}
if ($localhost) {
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $serverName = $osInfo.CSName
        $serialNumber = $osInfo.SerialNumber
        $osInfo.Name -match 'Microsoft\s(.*)\|.*\|.*' | Out-Null
        $osInfoName = $Matches[1]
    } catch {
        Remove-CimSession $session
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $session -ErrorAction Stop
        $serverName = $osInfo.CSName
        $serialNumber = $osInfo.SerialNumber
        $osInfo.Name -match 'Microsoft\s(.*)\|.*\|.*' | Out-Null
        $osInfoName = $Matches[1]
    } catch {
        Remove-CimSession $session
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

if ($localhost) {
    try {
        #Processor name
        $computerCpuName = (Get-CimInstance -ClassName win32_Processor -ErrorAction Stop).Name
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        #Processor name
        $computerCpuName = (Get-CimInstance -ClassName win32_Processor -CimSession $session -ErrorAction Stop).Name
        
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

if ($localhost) {
    try {
        #Processor speed
        $clockSpeedMhz = (Get-CimInstance win32_Processor -ErrorAction Stop).MaxClockSpeed
        $clockSpeedGhz = $clockSpeedMhz / 1000
        $computerCpuClockSpeed =  [math]::Round($clockSpeedGhz,1).ToString().Replace(",", ".") + " GHz"
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        #Processor speed
        $clockSpeedMhz = (Get-CimInstance win32_Processor -CimSession $session -ErrorAction Stop).MaxClockSpeed
        $clockSpeedGhz = $clockSpeedMhz / 1000
        $computerCpuClockSpeed =  [math]::Round($clockSpeedGhz,1).ToString().Replace(",", ".") + " GHz"
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

if ($localhost) {
    try {
        # Summarize disk size
        $computerTotalDiskSize = 0
        $disks = Get-CimInstance Win32_LogicalDisk -Filter DriveType=3 -ErrorAction Stop | Select-Object DeviceID, @{'Name'='Size'; 'Expression'={[math]::truncate($_.size / 1GB)}}, @{'Name'='Freespace'; 'Expression'={[math]::truncate($_.freespace / 1GB)}}
        foreach ($disk in $disks){
            $computerTotalDiskSize = $computerTotalDiskSize + $disk.Size.ToString("N0")
        }
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        # Summarize disk size
        $computerTotalDiskSize = 0
        $disks = Get-CimInstance Win32_LogicalDisk -Filter DriveType=3 -CimSession $session | Select-Object DeviceID, @{'Name'='Size'; 'Expression'={[math]::truncate($_.size / 1GB)}}, @{'Name'='Freespace'; 'Expression'={[math]::truncate($_.freespace / 1GB)}}
        foreach ($disk in $disks){
            $computerTotalDiskSize = $computerTotalDiskSize + $disk.Size.ToString("N0")
        }
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

if ($localhost) {
    try {
        # RAM
        $computerRam = (Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Measure-Object -Property capacity -Sum).sum /1gb
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        # RAM
        $computerRam = (Get-CimInstance Win32_PhysicalMemory -CimSession $session -ErrorAction Stop | Measure-Object -Property capacity -Sum).sum /1gb
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

if ($localhost) {
    try {
        #Modell PC
        $computerManufacturer = (Get-CimInstance win32_computersystem -ErrorAction Stop).Manufacturer
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    try {
        #Modell PC
        $computerManufacturer = (Get-CimInstance win32_computersystem -CimSession $session -ErrorAction Stop).Manufacturer
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

try {
    $itemParams = @{
        ProcessorSpeed = "$computerCpuClockSpeed"
        SerialNumber = "$serialNumber"
        HardriveSize = "$computerTotalDiskSize"
        InternalMemory = "$computerRam"
        OperatingSystem = "$osInfoName"
        Description = "$computerCpuName"
        TheftId = "$hotfixes"
        Manufacturer = "$computerManufacturer"
        DNSName = "$serverName"
        ID = "$($easitObjects.id)"
        Status = "Aktiv"
    }
    Write-CustomLog -Message "Sending update to Easit GO..."
    Import-GOAssetItem @easitWSParams -ImportHandlerIdentifier 'CreateAssetServer' @itemParams -ErrorAction Stop
    Write-CustomLog -Message "Successfully sent update to Easit GO"
} catch {
    return $_
}
Remove-CimSession $session
Get-CimSession | Remove-CimSession
Write-CustomLog -Message "Script end" -Level INFO