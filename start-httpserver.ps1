<#
.DESCRIPTION
	A simple http server written in Powershell.

	With this http server you can recieve exported objects from Easit GO and take action upon that object.
	In its current configuration the server will use the cmdlet 'Start-Job' to run the powershell script
	specified as identifier and if present in subfolder 'resources'.

.NOTES
	Copyright 2021 Easit AB

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.

#>
[CmdletBinding()]
Param(
	[string]$ServerSettingsPath
)

# Settings for logger
function Write-CustomLog {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline,ParameterSetName='string')]
        [string]$Message,
		[Parameter(ValueFromPipeline,ParameterSetName='object')]
        [object]$InputObject,
		[Parameter()]
        [ValidateSet('ERROR','WARN','INFO','VERBOSE','DEBUG')]
		[string]$Level = 'INFO',
		[Parameter()]
		[string]$LogName,
		[Parameter()]
		[string]$LogDirectory,
		[Parameter()]
		[int]$RotationInterval,
		[Parameter()]
		[string]$LogLevelSwitch,
		[Parameter()]
		[string]$ErrorHandling
	)
	$loggerHome = "$($MyInvocation.PSScriptRoot)"
	$logSetPath = Join-Path -Path "$loggerHome" -ChildPath 'loggerSettings.xml'
	if (Test-Path -Path "$logSetPath") {
		try {
			$loggerSettings = New-Object System.Xml.XmlDocument -ErrorAction Stop
			$loggerSettings.Load($logSetPath)
		} catch {
			throw $_
		}
	} else {
		Write-Verbose "Unable to find logger settings, using default settings"
	}
	if ([string]::IsNullOrWhiteSpace($LogName)) {
		$LogName = "$($loggerSettings.settings.LogName)"
		if ([string]::IsNullOrWhiteSpace($LogName)) {
			$LogName = 'PShttpServer'
		}
	}
	if ([string]::IsNullOrWhiteSpace($Level)) {
		$Level = 'INFO'
	}
	if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
		$LogDirectory = "$($loggerSettings.settings.LogDirectory)"
		if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
			$LogDirectory = 'logs'
		}
	}
	if ([string]::IsNullOrWhiteSpace($RotationInterval)) {
		$RotationInterval = "$($loggerSettings.settings.RotationInterval)"
		if ([string]::IsNullOrWhiteSpace($RotationInterval)) {
			$RotationInterval = 30
		}
	}
	if ([string]::IsNullOrWhiteSpace($LogLevelSwitch)) {
		$LogLevelSwitch = "$($loggerSettings.settings.LogLevelSwitch)"
		if ([string]::IsNullOrWhiteSpace($LogLevelSwitch)) {
			$LogLevelSwitch = 'INFO'
		}
	}
	if ([string]::IsNullOrWhiteSpace($ErrorHandling)) {
		$ErrorHandling = "$($loggerSettings.settings.ErrorHandling)"
		if ([string]::IsNullOrWhiteSpace($ErrorHandling)) {
			$ErrorHandling = 'SilentlyContinue'
		}
	}
	$FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$today = Get-Date -Format "yyyyMMdd"
	$LogName = "${LogName}_${today}.log"
	$LogRootDirectory = Join-Path -Path "$loggerHome" -ChildPath "$LogDirectory"
	$logOutputPath = Join-Path -Path "$LogRootDirectory" -ChildPath "$LogName"

	$writeToHost = "$($loggerSettings.settings.writeToHost)"
	if ([string]::IsNullOrWhiteSpace($writeToHost)) {
		$writeToHost = 'false'
	}
	$ErrorActionPreference = "$ErrorHandling"
	if ([string]::IsNullOrWhiteSpace($ErrorActionPreference)) {
		$ErrorActionPreference = 'SilentlyContinue'
	}
	
	if ($InputObject -and $Level -eq 'ERROR') {
        $Message = $InputObject.Exception
    }
    if ($InputObject -and $Level -ne 'ERROR') {
        $Message = $InputObject.ToString()
    }

	if (Test-Path $logOutputPath) {
        $logArchiveFiles = Get-ChildItem -Path "$LogRootDirectory\${logname}_*.log" -Force
        foreach ($logArchiveFile in $logArchiveFiles) {
            if ($logArchiveFile.CreationTime -lt ((Get-Date).AddDays(-30))) {
                "$($logArchiveFile.Name) is older than 30 days, removing.." | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
				try {
					Remove-Item "$($logArchiveFile.FullName)" -Force
				} catch {
					Write-Error $_
					exit
				}
                "$FormattedDate - INFO - Removed $($logArchiveFile.Name)" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
            }
        }
    }
	if (!(Test-Path $logOutputPath)) {
		$NewLogFile = New-Item "$logOutputPath" -Force -ItemType File
		"$FormattedDate - INFO - Created $NewLogFile" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
	}
	
	# Write message to error, warning, or verbose pipeline
    if ($Level -eq 'ERROR') {
		Write-Error "$Message" -ErrorAction Continue
		"$FormattedDate - $Level - $Message" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		if ($InputObject) {
			$InputObject | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		}
	} elseif ($Level -eq 'WARN') {
		Write-Warning "$Message" -WarningAction Continue
		"$FormattedDate - $Level - $Message" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		if ($InputObject) {
			$InputObject | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		}
	} elseif ($Level -eq 'INFO') {
		Write-Information "$Message" -InformationAction Continue
		"$FormattedDate - $Level - $Message" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		if ($InputObject) {
			$InputObject | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
		}
	} elseif ($Level -eq 'VERBOSE') {
		if ($LogLevelSwitch -eq 'VERBOSE' -or $LogLevelSwitch -eq 'DEBUG') {
			$VerbosePreference = 'Continue'
			Write-Verbose $Message
			"$FormattedDate - $Level - $Message" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
			if ($InputObject) {
				$InputObject | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
			}
		}
		$VerbosePreference = $null
	} elseif ($Level -eq 'DEBUG' -and $LogLevelSwitch -eq 'DEBUG') {
		if ($LogLevelSwitch -eq 'VERBOSE' -or $LogLevelSwitch -eq 'DEBUG') {
			$DebugPreference = 'Continue'
			Write-Debug $Message
			"$FormattedDate - $Level - $Message" | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
			if ($InputObject) {
				$InputObject | Out-File -FilePath "$logOutputPath" -Encoding UTF8 -Append -NoClobber
			}
		}
		$DebugPreference = $null
	} else {
		## Nothin to do
	}
	if ($writeToHost -eq 'true') {
		Write-Host "$FormattedDate - $Level - $Message"
	}
}
# End of settings for logger
if (!($ServerSettingsPath)) {
	$serverHome = Split-Path -Path "$($MyInvocation.MyCommand.Path)" -Parent
	$Path = Join-Path -Path "$serverHome" -ChildPath 'serverSettings.xml'
} else {
	$Path = "$ServerSettingsPath"
}
if (-not [System.Net.HttpListener]::IsSupported) {
	throw "Error: HttpListener is not supported for this OS!"
}

if (Test-Path -Path "$Path") {
	try {
		$serverSettings = New-Object System.Xml.XmlDocument -ErrorAction Stop
		$tempServerSettings = New-Object System.Xml.XmlDocument -ErrorAction Stop
		$serverSettings.Load($Path)
	} catch {
		Write-CustomLog -Message "Error: Unable to load server settings" -Level ERROR
		Write-CustomLog -InputObject $_ -Level ERROR
		break
	}
}
if (!(Test-Path -Path "$Path")) {
	Write-CustomLog -Message "Error: Unable to find server settings" -Level ERROR
	
}
$BindingUrl = "$($serverSettings.settings.BindingUrl)"
if ([string]::IsNullOrWhiteSpace($BindingUrl)) {
	Write-CustomLog -Message "BindingUrl is null or whitespace " -Level ERROR
	break
}
$Port = "$($serverSettings.settings.Port)"
if ([string]::IsNullOrWhiteSpace($Port)) {
	Write-CustomLog -Message "Port is null or whitespace " -Level ERROR
	break
}
$Basedir = "$($serverSettings.settings.Basedir)"
if ([string]::IsNullOrWhiteSpace($Basedir)) {
	Write-CustomLog -Message "Basedir is null or whitespace " -Level ERROR
	break
}
$ErrorHandling = "$($serverSettings.settings.ErrorHandling)"
if ([string]::IsNullOrWhiteSpace($ErrorHandling)) {
	Write-CustomLog -Message "ErrorHandling is null or whitespace " -Level ERROR
	break
}

$Binding = "$BindingUrl"+':'+"$Port/"

$uri = $Binding -as [System.URI]
if (!($null -ne $uri.AbsoluteURI -and $uri.Scheme -match 'http|https')) {
	Write-CustomLog -Message "URL to server failed uri test" -Level ERROR
	break
}

$resourceRoot = Join-Path -Path "$serverHome" -ChildPath "$Basedir"
if (!(Test-Path $resourceRoot)) {
	Write-CustomLog -Message "No valid resource folder ($resourceRoot) provided!" -Level ERROR
	break
}
# Starting the powershell webserver
Write-CustomLog -Message "Starting powershell http server..." -Level INFO
try {
	$listener = New-Object System.Net.HttpListener
	$listener.Prefixes.Add($Binding)
	$listener.Start()
} catch {
	Write-CustomLog -Message "Unable to start server" -Level ERROR
	Write-CustomLog -Message "$_" -Level ERROR
	exit
}
$error.Clear()
try {
	Write-CustomLog -Message "Powershell http server started." -Level INFO
	Write-CustomLog -Message "Listening on $Binding" -Level INFO
	Write-CustomLog -Message "Looking for resources at $resourceRoot" -Level INFO
	while ($listener.IsListening) {
		# analyze incoming request
		$httpContext = $listener.GetContext()
		$httpRequest = $httpContext.Request
		$httpRequestMethod = $httpRequest.HttpMethod
		$httpRequestURLPath = $httpRequest.Url.LocalPath
		$received = "$httpRequestMethod $httpRequestURLPath"
		Write-CustomLog -Message "received = $received" -Level VERBOSE
		$requestUrl = $httpRequest.Url.OriginalString
		$httpContentType = $httpRequest.ContentType
		if ($HttpRequest.HasEntityBody) {
			$Reader = New-Object System.IO.StreamReader($HttpRequest.InputStream)
			$requestContent = $Reader.ReadToEnd()
		}
		$HttpResponse = $HttpContext.Response
		$HttpResponse.Headers.Add("Content-Type","text/plain")
		$responseSent = $false
		# check for known commands
		switch ($received)
		{			
			"POST /fromeasit" { # execute script
				$tempServerSettings.Load($Path)
				$HttpResponse.StatusCode = 200
				$htmlResponse = '<html><body>Sucess!</body></html>'
				$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
				$HttpResponse.ContentLength64 = $buffer.Length
				$HttpResponse.OutputStream.Write($buffer, 0, $buffer.Length)
				$HttpResponse.Close()
				$responseOutputSetting = "$($tempServerSettings.settings.ResponseOutput)"
				if ($responseOutputSetting -eq 'true') {
					Write-CustomLog -Message "$HttpResponse" -Level INFO
				}
				$responseSent = $true
				Write-CustomLog -Message "ContentType = $httpContentType" -Level VERBOSE
				$requestOutputSetting = "$($tempServerSettings.settings.RequestOutput)"
				if ($requestOutputSetting -eq 'true') {
					Write-CustomLog -Message "$requestContent" -Level INFO
				}
				if ($httpContentType -eq 'text/xml; charset=UTF-8') {
					$match = $requestContent -match 'identifier">(.*)<\/'
					$identifier = $Matches[1]
					[xml]$requestContentXML = $requestContent
					$items = $requestContentXML.EasitImport.Items.ChildNodes
					$easitObjects = @()
					foreach ($item in $items) {
						$objectUID = $item.Attributes.Value
						$propertiesHash = [ordered]@{
							UID = $objectUID
						}
						$properties = $items.ChildNodes
						foreach ($property in $properties.ChildNodes) {
							$xmlPropertyName = $property.Attributes.Value
							$xmlPropertyValue = $property.innerText
							$keys = @($propertiesHash.keys)
							foreach ($key in $keys) {
								$keyMatch = $false
								if ($key -eq $xmlPropertyName) {
									$keyMatch = $true
									[array]$currentPropertyValueArray = $propertiesHash[$key]
									[array]$propertyValueArray = $currentPropertyValueArray
									[array]$propertyValueArray += $xmlPropertyValue
									$propertiesHash.Set_Item($xmlPropertyName, $propertyValueArray)
								}
							}
							if (!($keyMatch)) {
								$propertiesHash.Set_Item($xmlPropertyName, $xmlPropertyValue)
							}
						}
						$object = New-Object PSObject -Property $propertiesHash
						$easitObjects += $object
					}
					# Ex: $execDir = D:\Easit\PSHttpServer\resources
					$execDir = Join-Path -Path "$serverHome" -ChildPath "$Basedir"
					$executable = Join-Path -Path "$execDir" -ChildPath "$identifier.ps1"
					if (Test-Path "$executable") {
						try {
							Write-CustomLog -Message "Creating job, executing $executable with identifier $identifier" -Level INFO
							Start-Job -Name "$identifier" -FilePath "$executable" -ArgumentList @($execDir,$easitObjects) -ErrorAction Stop
							Write-CustomLog -Message "Job successfully created" -Level INFO
						} catch {
							Write-CustomLog -Message "$_" -Level ERROR
							Write-CustomLog -Message "Error executing / running script!" -Level ERROR
						}
					} else {
						Write-CustomLog -Message "Cannot find script ($executable)!" -Level ERROR
					}
					$jobCleanup = Get-Job -State Completed | Remove-Job
				} else {
					Write-CustomLog -Message "Invalid Content-Type!" -Level INFO
				}
			}

			"POST /toeasit" {
				$tempServerSettings.Load($Path)
				$HttpResponse.StatusCode = 200
				$htmlResponse = '<html><body>Sucess!</body></html>'
				Write-CustomLog -Message "ContentType = $httpContentType" -Level INFO
				if ($httpContentType -contains 'application/json') {
					$requestObjects = ConvertFrom-Json $requestContent
					if ($requestUrl -match '(\?|\&)identifier=(.*)(\&)?') {
						$keyString = $Matches[2]
						if ($keyString -match '&') {
							$paramKeys = $keyString -split '&'
							$identifierJSON = $paramKeys[0]
						} else {
							$identifierJSON = $Matches[2]
						}
					}
					$execDir = Join-Path -Path "$serverHome" -ChildPath "$Basedir"
					$executable = Join-Path -Path "$execDir" -ChildPath "$identifierJSON.ps1"
					if (Test-Path "$executable") {
						try {
							Write-CustomLog -Message "Creating job, executable $executable" -Level INFO 
							$execDir = Join-Path -Path "$serverHome" -ChildPath "$Basedir"
							$job = Start-Job -Name "$identifier" -FilePath "$executable" -ArgumentList @($execDir,$requestObjects)
							Write-CustomLog -Message "Job successfully created" -Level INFO
						} catch {
							Write-CustomLog -Message "$_" -Level ERROR
							Write-CustomLog -Message "Error executing / running script!" -Level ERROR
						}
					} else {
						Write-CustomLog -Message "Cannot find script ($executable)!" -Level ERROR
					}
					$jobCleanup = Get-Job -State Completed | Remove-Job
				} else {
					Write-CustomLog -Message "Invalid Content-Type!" -Level INFO
				}
			}

			"GET /quit"	{
				$HttpResponse.StatusCode = 200
				$htmlResponse = 'Stopping powershell http server... Goodbye!'
				Write-CustomLog -Message "Stopping powershell http server..." -Level INFO
				exit
			}

			"GET /exit"	{
				$HttpResponse.StatusCode = 200
				$htmlResponse = 'Stopping powershell http server... Goodbye!'
				Write-CustomLog -Message "Stopping powershell http server..." -Level INFO
				exit
			}

			"GET /status"	{
				$HttpResponse.StatusCode = 200
				Write-CustomLog -Message "Everything is goooooood!!!" -Level INFO
				$htmlResponse = 'Staus: OK!'

			}
			"GET /favicon.ico" {
				# Block to stop polution of log with 'Received unknown endpoint or action! GET /favicon.ico'
			}
			default	{
				$HttpResponse.StatusCode = 404
				$htmlResponse = 'Unknown endpoint or action!'
				Write-CustomLog -Message "Received unknown endpoint or action! $received"  -Level INFO
				}
			}
		if (!($responseSent)) {
			$buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlResponse)
			$HttpResponse.ContentLength64 = $buffer.Length
			$HttpResponse.OutputStream.Write($buffer, 0, $buffer.Length)
			# $HttpResponse | Out-File "C:\Easit\PSHttpServer\logs\response.txt"
			$HttpResponse.Close()
		}
	}
} catch {
	$fullExceptionMessage = "$($_.Exception.InnerException)"
	$smallExceptionMessage = "$($_.Exception.Message)"
	$exceptionScriptStack = "$($_.Exception.ScriptStackTrace)"
	$exceptionStackTrace = "$($_.Exception.StackTrace)"
	if ($exceptionMessage) {
		Write-CustomLog -Message "Message: $smallExceptionMessage" -Level WARN
	}
	Write-CustomLog -Message "Full exception: `n$fullExceptionMessage" -Level ERROR
	if ($exceptionStackTrace) {
		Write-CustomLog -Message "StackTrace: `n$exceptionStackTrace" -Level ERROR
	}
	if ($exceptionScriptStack) {
		Write-CustomLog -Message "ScriptStackTrace: `n$exceptionScriptStack" -Level ERROR
	}
	Write-CustomLog -Message "$_" -Level ERROR
} finally {
	$jobCleanup = Get-Job -State Completed | Remove-Job
	if ($jobCleanup) {
		Write-CustomLog -Message "Removed completed jobs" -Level VERBOSE
	} else {
		Write-CustomLog -Message "No completed jobs to remove" -Level VERBOSE
	}
	# Stop powershell webserver
	$listener.Stop()
	$listener.Close()
	Write-CustomLog -Message "Powershell http server stopped." -Level INFO
}