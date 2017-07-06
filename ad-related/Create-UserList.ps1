param(
    [string]$Domain = ((Get-ADDomain).Name)
)
Import-Module ActiveDirectory

$report = "Name`tAccountName`tDescription`tEmailAddress`tLastLogonDate`tManager`tTitle`tDepartment`tCompany`twhenCreated`tAccountEnabled`tPasswordExpired`tPasswordLastSet`tNeverExpires`tNotRequired`tCannotChangePassword`tGroups`n"
$userList = Get-ADUser -Server $Domain -Filter * -Properties Name,SamAccountName,Description,EmailAddress,LastLogonDate,Manager,Title,Department,Company,whenCreated,Enabled,PasswordExpired,PasswordLastSet,PasswordNeverExpires,PasswordNotRequired,CannotChangePassword,MemberOf

$userList | ForEach-Object {
    $groups = $_.MemberOf | Get-ADGroup -Server $Domain | ForEach-Object {$_.Name} | Sort-Object
	$objectAttributes = $_.Name,$_.SamAccountName,$_.Description,$_.EmailAddress,$_.LastLogonDate,$_.Manager,$_.Title,$_.Department,$_.Company,$_.whenCreated,$_.Enabled,$_.PasswordExpired,$_.PasswordLastSet,$_.PasswordNeverExpires,$_.PasswordNotRequired,$_.CannotChangePassword
    $attributeLine = ($objectAttributes -join "`t") + "`t" + ($groups -join "`t") + "`n"
    $report += $attributeLine
}

# Save the output to a CSV file
$filename = "$Domain-Users-{0:yyyy-MM-dd}.csv" -f (Get-Date)
$report | Out-File ".\$filename"
