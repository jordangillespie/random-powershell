 If ((get-process | Where-Object{$_.Name -eq "OUTLOOK"}).Count -gt 0)
 {
  Stop-Process -name "OUTLOOK" -force
  }
 $today= Get-Date -format "MM-dd-yyyy HH.mm"
 $CurrentDate = Get-Date
 $days="-1"
 $filterlastwritetime=$CurrentDate.AddDays($days)
 $drv=Get-WmiObject -class win32_Logicaldisk | Where { $_.DriveType -eq 3 -and $_.DeviceID -ne 'C:'}
 $location= $drv.DeviceID +"\backup"
 
 if (!(Test-Path -path $location))
 {
 md $location
 $pst=Get-WmiObject -Query "Select * from CIM_DataFile Where Extension = 'pst'"
 }
 else
 {
 $pst=Get-WmiObject -Query "Select * from CIM_DataFile Where Extension = 'pst'"
 }
 Copy-Item $pst.Name $location -Force -Recurse
 cd $location
 dir | where-object{$_.LastWriteTime -gt $filterlastwritetime} | rename-item -newname {$_.name+ ($today)+".pst"} 
 

$Daysback = "-30"
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $location | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
