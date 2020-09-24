param(
    $execDir, # Ex: $execDir = D:\Easit\PSHttpServer\resources
    $easitObjects # Object that hold all properties from the Easit object (Contact, Org, Status, Priority)
)
$now = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
$logDir = Join-Path -Path "$execDir" -ChildPath 'logs'
$scriptName = $MyInvocation.MyCommand.Name.Trim('.ps1')
$outputFile = Join-Path -Path "$logDir" -ChildPath "$scriptName.log"
"$now - Script start!" | Out-File -FilePath "$outputFile" -Encoding UTF8 -Append

[int]$requestID =  $easitObjects.requestID

$urlWS = "http://yourEasitSystem/webservice/"
$apikey = "API key for Easit Webservice"

$adParameters = @{
    Name = 'First name'
    SamAccountName = 'username'
    Path = 'OU=Department,OU=Company,DC=demodomain,DC=internal'
    Server = 'adServerIP'
    Credential = ''
}
$userAttributes = @{
    title = "director"
    mail = "chewdavid@fabrikam.com"
}

Disable-ADAccount -Identity "samaccountname"

"$now - Script end!" | Out-File -FilePath "$outputFile" -Encoding UTF8 -Append