param(
    [parameter(mandatory=$true)][string]$hostname,
    [parameter(mandatory=$true)][string]$servicename,
    [parameter(mandatory=$false)][string]$logFile
)

if(!$logfile){
    $logFile = "E:\IT\scripts\logs\" + $hostname + "_" + $dateStamp + ".log"
}

$dateStamp = Get-Date -UFormat "%m-%d-%Y"

Function Write-Log{
	Param ([string]$logstring)
    $logline = "[$(Get-Date)] $logstring"
	Add-Content $logFile -value $logline
}

try{
    Write-Log "Starting bounceService for $servicename on $hostname"
    $svc = Get-Service $servicename -ComputerName $hostname
    if ($svc.status -eq "running"){
        Write-Log "Stopping $servicename on $hostname"
        $svc.stop()
        $count=0
        while ($svc.Status -ne "stopped") {
            Write-Log "Waiting 60 seconds for $servicename to stop on $hostname"
            Start-Sleep -Seconds 60
            $svc.refresh()
            $count++
            if ($count -ge 10) {
                Write-Log "$servicename has been stopping for over ten minutes, killing $servicename on $hostname"
                Invoke-Command -ComputerName $hostname -ScriptBlock {Get-Process netsage | kill -Force}
            }
        }
        $svc.Refresh()
        Write-Log "Starting $servicename back up on $hostname"
        $svc.Start()
        #echo "Starting NetSage"
        while ($svc.Status -ne "running") {
            Write-Log "Waiting 5 seconds for $servicename to start on $hostname"
            Start-Sleep -Seconds 5
            $svc.refresh()
        }
        Write-Log "bounceService completed for $hostname"
    }
    else{
        Write-Log "$servicename is not running on $hostname, exiting quietly"
    }
}
catch{
    Write-Log "Failed to restart $servicename on ${hostname}: $_"
}
