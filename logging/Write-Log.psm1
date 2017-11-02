<#
 .Synopsis
  Writes out a log line to a file in a standard consistent format.

 .Description
  Supports writing out a log line in json, csv and plain text to a file.

 .Parameter Message
  The content of the log message.

 .Parameter Path
  The path to the file to be written, can be a local path - C:\temp\log.log or
  a UNC path - \\filer01\log.log

 .Parameter Type
  The type of output, options are json, csv, and text.


 .Example
   # Write a json (default) log line to C:\temp\log.log.
   Write-Log -Message "My Log Entry" -Path "C:\temp\log.log"

 .Example
   # Write a csv log line to C:\temp\log.log.
   Write-Log -Message "My Log Entry" -Path "C:\temp\log.log" -Type csv

 .Example
   # Write a tab delimited plain text log line to C:\temp\log.log.
   Write-Log -Message "My Log Entry" -Path "C:\temp\log.log" -Type text
#>
function Write-Log {
    param(
        [parameter(mandatory=$true)][string]$Message,
        [parameter(mandatory=$true)][string]$Path,
        [parameter(mandatory=$false)][string][ValidateSet("json","csv","text")]$Type="json",
        [parameter(mandatory=$false)]$additional
    )
    switch($Type){
        "json" {
            $LogMessage = [ordered]@{}
            $LogMessage.Timestamp = ((Get-Date).ToUniversalTime()).ToString("o")
            $LogMessage.Message = $Message
            if ($additional) {
                $LogMessage.Additional = @{}
                $LogMessage.Additional = $additional
            }
            $LogMessage.Server = $env:computername
            $LogMessage.Caller = $MyInvocation.PSCommandPath
            $LogMessage.User = [Environment]::UserName
            $LogMessage = $LogMessage|ConvertTo-Json -Compress -Depth 6
        }
        "csv" {
            if (!(Test-Path $Path)){
                Add-Content -Value "Timestamp,Message,Server,Caller,User" -Path $Path
            }
            $LogMessage = "$(((Get-Date).ToUniversalTime()).ToString("o")),$Message,$($env:computername),$($MyInvocation.PSCommandPath),$([Environment]::UserName)"
        }
        "text" {
            $LogMessage = "[$(((Get-Date).ToUniversalTime()).ToString("o"))]`tUser:$([Environment]::UserName)`tServer:$($env:computername)`tCaller:$($MyInvocation.PSCommandPath)`tMessage:$Message" 
        }
    }
    Add-Content -Value $LogMessage -Path $Path
}
Export-ModuleMember -Function Write-Log
