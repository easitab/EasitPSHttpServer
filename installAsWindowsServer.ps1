# Using NSSM to install server as Windows Service (https://nssm.cc/download).
# We do NOT support NSSM in any way and we do NOT expect users take this as a recommendation! It is only an example!
$nssm = "C:\Program Files\nssm\win64\nssm.exe"

# Name for Windows Service that runs server.
$serviceName = 'PSHttpServer'

$powershell = (Get-Command powershell).Source

# If this script and start-httpserver.ps1 is in the same folder you do not need to change this.
$scriptPath = "$PSScriptRoot\start-httpserver.ps1"

# Arguments used when starting service for server.
$arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath

# Installing server as Windows Service.
& $nssm install $serviceName $powershell $arguments

# Checking status for installed service.
& $nssm status $serviceName

# Starting Windows Service for server.
Start-Service $serviceName

# Getting service and display it in the console.
Get-Service $serviceName