function Destroy-DNS {
    param(
        [Parameter(mandatory=$true)][String]$VMName,
        [Parameter(mandatory=$true)][String]$DNSServer,
        [Parameter(mandatory=$true)][String]$DNSZone
    )
    $NodeARecord = Get-DnsServerResourceRecord -ZoneName $DNSZone -ComputerName $DNSServer -Node $VMName -RRType A -ErrorAction SilentlyContinue
    if ($NodeARecord){
        Write-Host "Remove DNS A record for $VMName"
        try{
            Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $DNSZone -InputObject $NodeARecord -Force
        }
        catch {
            Write-Warning "Failed to remove $VMName A Record from DNS, manual cleanup may be required"
        }
        $IPAddress = $NodeARecord.RecordData.IPv4Address.IPAddressToString
        $IPAddressArray = $IPAddress.Split(".")

        #this is specific to our lab vs. prod environments lab reverse zones are 254.10.in-addr.arpa and 200.10.in-addr.arpa where prod is 10.in-addr.arpa
        if ($IPAddressArray[1] -eq "254" -or $IPAddressArray[1] -eq "200"){
            $ReverseZoneName = "$($IPAddressArray[1]).$($IPAddressArray[0]).in-addr.arpa"
            $IPAddressFormatted = ($IPAddressArray[3]+"."+$IPAddressArray[2])
        }
        else {
            $ReverseZoneName = "$($IPAddressArray[0]).in-addr.arpa"
            $IPAddressFormatted = ($IPAddressArray[3]+"."+$IPAddressArray[2]+"."+$IPAddressArray[1])
        }
        $NodePTRRecord = Get-DnsServerResourceRecord -ZoneName $ReverseZoneName -ComputerName $DNSServer -Node $IPAddressFormatted -RRType Ptr -ErrorAction SilentlyContinue
        if($NodePTRRecord){
            Write-Host "Remove DNS PTR record for $VMName"
            try{
                Remove-DnsServerResourceRecord -ZoneName $ReverseZoneName -ComputerName $DNSServer -InputObject $NodePTRRecord -Force
            }
            catch {
                Write-Warning "Failed to remove $VMName PTR Record from DNS, manual cleanup may be required"
            }
        }
        else {
            Write-Warning "No PTR record found for $VMName"
        }
    }
    else {
        Write-Warning "No A Record found for $VMName, won't attempt PTR record removal either"
    }
}
