function Create-DHCP {
    param(
        [Parameter(mandatory=$true)][String]$VMName,
        [Parameter(mandatory=$true)][String]$VMIP,
        [Parameter(mandatory=$true)][String]$VMMAC,
        [Parameter(mandatory=$true)][String]$DHCPServer,
        [Parameter(mandatory=$true)][String]$DHCPScope
    )
    try{
        Write-Host ("Adding $VMIP and $VMMAC to DCHP Scope: $DHCPScope")
        Add-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $DHCPScope -IPAddress $VMIP -ClientId $VMMAC -Name $VMName
    }
    catch{
        Write-Warning "Failed to Reserve $VMIP and $VMMAC in $DHCPScope on $DHCPServer. The VM will probably NOT get an IP."
    }
}
