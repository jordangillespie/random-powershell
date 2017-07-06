#Seek-AndDestroy.ps1
param(
    [Parameter(mandatory=$true)][string]$datacenter,
    [Parameter(mandatory=$false)][string]$logfile
)
if(!$logfile){
    $logfile = "\\us-prnas01\it\logs\Scripts\SeekAndDestroy\SeekAndDestroy_$(Get-Date -UFormat "%m-%d-%Y").log"
}

#get list of servers from chef server using knife search node
$JSON = $(knife search node "os:windows AND role:datacenter-$datacenter" -a ipaddress -F json)
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
$servers = ((New-Object System.Web.Script.Serialization.JavaScriptSerializer).Deserialize($JSON, [System.Collections.Hashtable])).rows

Import-Module ServerManager

foreach ($server in $servers.keys){
    if( $server -match "web" ){
        try{
            $wps = Get-WmiObject -Namespace 'root\WebAdministration' -Class 'WorkerProcess' -ComputerName $server
        }
        catch{
            if (!((Get-WindowsFeature -ComputerName $server -Name Web-Scripting-Tools).Installed)){
                Install-WindowsFeature -ComputerName $server Web-Scripting-Tools
            }
            $wps = Get-WmiObject -Namespace 'root\WebAdministration' -Class 'WorkerProcess' -ComputerName $server
        }
        foreach ($worker in $wps){
            $state = Invoke-WmiMethod -InputObject $worker -Name GetState
            if ($state.ReturnValue -eq 2){
                $logline = @{}
                $logline.Server = "$($worker.PSComputerName)"
                $logline.PID = "$($worker.ProcessId)"
                $logline.Action = "kill"
                $logline.AppPool = "$($worker.AppPoolName)"
                $logline.timeStamp = ((Get-Date).ToUniversalTime()).ToString("o")
                Add-Content $logFile -value ($logline|ConvertTo-Json -Compress -Depth 6)
                Invoke-Command -ComputerName $($worker.PSComputerName) -ScriptBlock {Stop-Process $args[0] -Force} -ArgumentList @($worker.ProcessId)
            }
        }
    }
}
