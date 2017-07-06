function Destroy-DHCP {
    param(
        [Parameter(mandatory=$true)][String]$VMIP,
        [Parameter(mandatory=$true)][String]$DHCPServer,
        [Parameter(mandatory=$true)][String]$DHCPScope
    )
    try{
        Write-Host "Remove DHCP Reservation, if exists"
        Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $DHCPScope | where IPaddress -EQ $VMIP | Remove-DhcpServerv4Reservation -ComputerName $DHCPServer
    }
    catch {
        Write-Warning "Failed to remove $VMIP DHCP Reservation, manual cleanup may be required"
    }
    try{
        Write-Host "Remove DHCP Lease, if exists"
        Get-DhcpServerv4Lease -ComputerName $DHCPServer -ScopeId $DHCPScope | where IPaddress -EQ $VMIP | Remove-DhcpServerv4Lease -ComputerName $DHCPServer
    }
    catch {
        Write-Warning "Failed to remove $VMIP DHCP Lease, manual cleanup may be required"
    }
}
