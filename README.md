# EasitPSHttpServer

A simple http server written in Powershell.
With this http server you can recieve exported objects from Easit GO and take action upon that object.
In its current configuration the server will use the cmdlet 'Start-Job' to run the powershell script
specified as identifier and if present in subfolder 'resources'.

## Install

- Example solution 1:
Start powershell http server as scheduled task as user local system every time the computer starts (when the correct path to the file Start-WebServer.ps1 is given):
schtasks.exe /Create /TN "Powershell Webserver" /TR "powershell -file C:\Users\username\Documents\Start-WebServer.ps1" /SC ONSTART /RU SYSTEM /RL HIGHEST /F

- Example solution 2:
Start powershell http server as scheduled task as user local system every time the computer starts (when the correct path to the file Start-WebServer.ps1 is given) on port 9180 regardless of name or ip:
schtasks.exe /Create /TN "Powershell Webserver" /TR "powershell -file C:\Users\username\Documents\Start-WebServer.ps1 http://+:9180/" /SC ONSTART /RU SYSTEM /RL HIGHEST /F

- Example solution 3:
Install a Windows service to start and stop it.

### More details

- Example solution 1:
You can start the webserver task manually with
  schtasks.exe /Run /TN "Powershell Webserver"
Delete the webserver task with
  schtasks.exe /Delete /TN "Powershell Webserver"

- Example solution 3:
Use a service helper (For example 'NSSM') to create the service.

### Misc

No adminstrative permissions are required for a binding to "localhost"
BINDING: http://localhost:8080/

Adminstrative permissions are required for a binding to network names or addresses.
[+] takes all requests to the port regardless of name or ip, * only requests that no other listener answers:
BINDING: http://+:9080/

## Support & Questions

Questions and issue can be sent to [githubATeasit](mailto:github@easit.com)