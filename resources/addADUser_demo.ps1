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
    Name = 'Anders Thyrsson2'
    SamAccountName = 'anth2'
    Path = 'OU=Solna,OU=Easit,DC=demodomain,DC=internal'
    Server = '172.28.170.10'
    Credential = $serverCred
}
$userAttributes = @{
    title = "director"
    mail = "chewdavid@fabrikam.com"
}

New-ADUser @adParameters -OtherAttributes @userAttributes

"$now - Script end!" | Out-File -FilePath "$outputFile" -Encoding UTF8 -Append