param(
    $execDir, # Ex: $execDir = D:\Easit\PSHttpServer\resources
    $easitObjects # Object that hold all properties from the Easit object (Contact, Org, Status, Priority)
)

#Start-Transcript -Path "C:\Easit\PSHttpServer\resources\logs\addADUser.txt" -Append -Force
$today = Get-Date -Format "yyyy-MM-dd"
if (Get-WindowsFeature -Name 'RSAT-AD-PowerShell') {
    Write-CustomLog -Message "RSAT-AD-PowerShell feature installed" -Verbose
} else {
    try {
        Write-CustomLog -Message "Installing RSAT-AD-PowerShell feature" -Verbose
        Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop
        Write-CustomLog -Message "RSAT-AD-PowerShell feature installed" -Verbose
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
}
if (Get-WindowsFeature -Name 'gpmc') {
    Write-CustomLog -Message "GroupPolicy feature installed" -Verbose
} else {
    try {
        Write-CustomLog -Message "Installing GroupPolicy feature" -Verbose
        Add-WindowsFeature gpmc -ErrorAction Stop
        Write-CustomLog -Message "GroupPolicy feature installed" -Verbose
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
    }
}
function Write-CustomLog {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline,ParameterSetName='string')]
        [string]$Message,
    
        [Parameter(ValueFromPipeline,ParameterSetName='object')]
        [object]$InputObject,
    
        [Parameter()]
        [string]$fileName = "logs\addADUser_$today.log",
    
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
$managerOrgName = "$($easitObjects.managerOrgName)"
$ADOrganizationalUnitParameters = @{
    Filter = "Name -like '$managerOrgName'"
}
try {
    $userADorg = Get-ADOrganizationalUnit @ADOrganizationalUnitParameters -SearchBase "$($settings.SearchBase)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
if ($userADorg) {
    Write-CustomLog -Message "Found ADOrganizationalUnit object" -Level INFO
    Write-CustomLog -Message "DistinguishedName = $($userADorg.DistinguishedName)" -Level INFO
} else {
    Write-CustomLog -Message "ADOrganizationalUnit object is $false" -Level INFO
}

# Sanity check
if ("$($easitObjects.contactId)") {
    $newEmployeeUsername = "$($easitObjects.username)"
} else {
    $newEmployeeUsername = "$($easitObjects.firstname).$($easitObjects.lastname)"
}
$userMail = "${newEmployeeUsername}@easit.com"
$GetADUserParameters = @{
    Filter = "Mail -like '$userMail'"
}
try {
    $adUserCheck = Get-ADUser @GetADUserParameters -SearchBase "$($settings.SearchBase)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
    if (!($adUserCheck)) {
        $GetADUserParameters = @{
            Filter = "SamAccountName -like '$newEmployeeUsername'"
        }
        $adUserCheck = Get-ADUser @GetADUserParameters -SearchBase "$($settings.SearchBase)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
    }
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
if ("$($easitObjects.contactId)") {
    $AccountPassword = ConvertTo-SecureString -String "Password123" -AsPlainText -Force
    $userMail = "$($easitObjects.mail)"
    $adParameters = @{
        Name = "$($easitObjects.firstname) $($easitObjects.lastname)"
        DisplayName = "$($easitObjects.firstname) $($easitObjects.lastname)"
        SamAccountName = "$($easitObjects.username)"
        GivenName = "$($easitObjects.firstname)"
        Surname = "$($easitObjects.lastname)"
        Path = "OU=$($easitObjects.orgName),$($settings.SearchBase)"
        Server = "$($settings.adServer)"
        UserPrincipalName = "$($easitObjects.username)"
        AccountPassword = $AccountPassword
        Office = "$($easitObjects.orgName)"
        Title = "$($easitObjects.title)"
        Credential = $serverCred
    }
} else {
    $AccountPassword = ConvertTo-SecureString -String "Password123" -AsPlainText -Force
    $adParameters = @{
        Name = "$($easitObjects.firstname) $($easitObjects.lastname)"
        DisplayName = "$($easitObjects.firstname) $($easitObjects.lastname)"
        SamAccountName = "$newEmployeeUsername"
        GivenName = "$($easitObjects.firstname)"
        Surname = "$($easitObjects.lastname)"
        Path = "OU=$($easitObjects.managerOrgName),$($settings.SearchBase)"
        Server = "$($settings.adServer)"
        UserPrincipalName = "$newEmployeeUsername"
        AccountPassword = $AccountPassword
        Office = "$($easitObjects.managerOrgName)"
        Title = "$($easitObjects.title)"
        Credential = $serverCred
    }
}
if ($adUserCheck) {
    Write-CustomLog -Message "User with same mail or $newEmployeeUsername already present in Active Directory"
    Write-CustomLog -InputObject $adUserCheck -Level INFO
    Write-CustomLog -Message "Updating user in Active Directory"
    try {
        Set-ADUser @adParameters -ChangePasswordAtLogon $true -Enabled $true -OtherAttributes @{'mail'="$userMail"} -ErrorAction Stop
        Write-CustomLog -Message "User updated in Active Directory"
        $newADUser = Get-ADUser @GetADUserParameters -SearchBase "$($settings.SearchBase)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    Write-CustomLog -Message "No user with mail $($easitObjects.mail) or SamAccountName $newEmployeeUsername present in Active Directory"
    Write-CustomLog -Message "Creating user in Active Directory"
    try {
        New-ADUser @adParameters -ChangePasswordAtLogon $true -Enabled $true -OtherAttributes @{'mail'="$userMail"} -ErrorAction Stop
        Write-CustomLog -Message "User created in Active Directory"
        $newADUser = Get-ADUser @GetADUserParameters -SearchBase "$($settings.SearchBase)" -Server "$($settings.adServer)" -Credential $serverCred -ErrorAction Stop
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
}

Write-CustomLog -Message "OrganizationID = $($easitObjects.managerOrgId)"
Write-CustomLog -Message "ManagerID = $($easitObjects.managerId)"
Write-CustomLog -Message "FQDN = $($newADUser.DistinguishedName)"
Write-CustomLog -Message "ExternalId = $($newADUser.ObjectGUID)"
$easitWSParams = @{
    url = "$($settings.url)"
    apikey = "$($settings.apikey)"
}

if ("$($easitObjects.contactId)") {
    $createContactParams = @{
        ImportHandlerIdentifier = 'CreateContact'
        FQDN = "$($newADUser.DistinguishedName)"
        ExternalId = "$($newADUser.ObjectGUID)"
        ID = "$($easitObjects.id)"
    }
} else {
    $createContactParams = @{
        ImportHandlerIdentifier = 'CreateContact'
        OrganizationID = "$($easitObjects.managerOrgId)"
        ManagerID = "$($easitObjects.managerId)"
        FirstName = "$($easitObjects.firstname)"
        Surname = "$($easitObjects.lastname)"
        FQDN = "$($newADUser.DistinguishedName)"
        Username = "$newEmployeeUsername"
        ExternalId = "$($newADUser.ObjectGUID)"
        Email = "$userMail"
        Position = "$($easitObjects.position)"
        Title = "$($easitObjects.title)"
        Building = "$($easitObjects.building)"
        Room = "$($easitObjects.room)"
        Phone = "$($easitObjects.phone)"
    }
}

try {
    Write-CustomLog -Message "Creating user as contact"
    $easitContactWsResult = Import-GOContactItem @easitWSParams @createContactParams -ShowDetails -ErrorAction Stop
    Write-CustomLog -Message "Contact created in Easit GO, ID $easitContactWsResult" -Level INFO
} catch {
    Write-CustomLog -InputObject $_ -Level ERROR
    return
}
if (!("$($easitObjects.contactId)")) {
    try {
        Write-CustomLog -Message "Updating employee request $($easitObjects.id)"
        $updateRequestParams = @{
            ImportHandlerIdentifier = 'CreateRequestEmployment'
            ContactID = "$easitContactWsResult"
            ID = "$($easitObjects.id)"
            Username = "$newEmployeeUsername"
        }
        $easitRequestWsResult = Import-GORequestItem @easitWSParams @updateRequestParams -ErrorAction Stop
        Write-CustomLog -Message "Employee request ID $easitRequestWsResult updated" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
    try {
        Write-CustomLog -Message "Creating contact as user in Easit GO" -Level INFO
        $createContactParams = @{
            ImportHandlerIdentifier = 'addADUser'
            FirstName = "$($easitObjects.firstname)"
            Surname = "$($easitObjects.lastname)"
            Username = "$newEmployeeUsername"
            Email = "$userMail"
        }
        Import-GOContactItem @easitWSParams @createContactParams -ShowDetails -ErrorAction Stop
        Write-CustomLog -Message "Contact created as user in Easit GO" -Level INFO
    } catch {
        Write-CustomLog -InputObject $_ -Level ERROR
        return
    }
} else {
    Write-CustomLog -Message "Skipped update of employee request and skipped creating user in Easit GO"
}

Write-CustomLog -Message "Script ended" -Level INFO