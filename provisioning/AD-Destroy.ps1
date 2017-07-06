function Destroy-ActiveDirectory {
    param(
        [Parameter(mandatory=$true)][String]$VMName,
        [Parameter(mandatory=$true)][String]$ADServer,
        [Parameter(mandatory=$true)][Bool]$Replicate
    )
    #find the AD server to talk to
    Write-Host "Removing $VMName from Domain, if exists"
    try{
        $ADComputer = Get-ADComputer -Server $ADServer -Identity $VMName
        if ($ADComputer){
            $ADComputer | Remove-ADObject -Recursive -Confirm:$false
        }
    }
    catch{
        Write-Warning "Failed to remove $VMName from Active Directory, manual cleanup may be required, or the server was not joined to the domain."
    }

    if ($ADComputer -and $Replicate) {
        $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers
        ForEach ($dc in $Domain) {
            #replicate the change just made to this server out to all servers in the domain
            if ($ADServer -eq $dc.Name.Split('.')[0]){
                ForEach ($part in $dc.Partitions) {
                    Write-Host "$dcName - Syncing replicas from all servers for partition '$part'"
                    $dc.SyncReplicaFromAllServers($part, @('PushChangeOutward','CrossSite'))
                }
            }
        }
    }
}
