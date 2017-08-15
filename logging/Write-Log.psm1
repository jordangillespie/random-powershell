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
        [parameter(mandatory=$false)][string][ValidateSet("json","csv","text")]$Type="json"
    )
    switch($Type){
        "json" {
            $LogMessage = @{}
            $LogMessage.Message = $Message
            $LogMessage.Timestamp = ((Get-Date).ToUniversalTime()).ToString("o")
            $LogMessage.Server = $env:computername
            $LogMessage.Caller = $MyInvocation.PSCommandPath
            $LogMessage = $LogMessage|ConvertTo-Json -Compress
        }
        "csv" {
            if (!(Test-Path $Path)){
                Add-Content -Value "Message,Timestamp,Server,Caller" -Path $Path
            }
            $LogMessage = "$Message,$(((Get-Date).ToUniversalTime()).ToString("o")),$($env:computername),$($MyInvocation.PSCommandPath)"
        }
        "text" {
            $LogMessage = "[$(((Get-Date).ToUniversalTime()).ToString("o"))]`tServer:$($env:computername)`tCaller:$($MyInvocation.PSCommandPath)`tMessage:$Message"
        }
    }
    Add-Content -Value $LogMessage -Path $Path
}
Export-ModuleMember -Function Write-Log
