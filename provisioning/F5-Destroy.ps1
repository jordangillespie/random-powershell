function F5DestroyNode {
    [CmdletBinding()]
    param(
      [Parameter(mandatory=$true)][String]$VMName,
      [Parameter(mandatory=$false)][String]$Partition = 'Common'
    )

    $validation = $true
    if (!(F5PartitionExists -Partition $Partition)) {
        Write-Warning "Partition $Partition does not exist"
        $validation = $false
    }
    else {
        # Set the active partition (common, INTERNAL_SERVICES)
        Write-Verbose "Setting Active partition to $($Partition)"
        (Get-F5.iControl).ManagementPartition.set_active_partition( (,"$($Partition)"))
        $ActivePartition = (Get-F5.iControl).ManagementPartition.get_active_partition()
        Write-Verbose "Active partition is $($ActivePartition)"
    }

    if (!(F5MemberExists -VMName $VMName -Partition $Partition)) {
        Write-Warning "Could not find node $VMName in F5"
        if (F5MemberExists -VMName $VMName.ToUpper() -Partition $Partition) {
            Write-Warning "Found $($VMName.ToUpper()). VM Names should be lowercase. Proceeding with Uppercase name."
            $VMName = $VMName.ToUpper()
        }
        else {
            $validation = $false
        }
    }
    elseif ( (F5GetMemberPools -VMName $VMName -Partition $Partition).length -lt 1 ) {
        Write-Warning "Could not find any F5 Pools with $VMName"
    }

    if (!($validation)) {
        Write-Warning "F5 validation checks failed"
        Write-Warning "You may need to manually destroy VM in F5"
        break
    }
    else {

        ## Remove Members from Pools ##
        ###############################

        # Bug in remove_member_v2 only removes from 1 pool at a time
        $memberPools = F5GetMemberPools -VMName $VMName -Partition $Partition
        ForEach ($p in $memberPools) {
            # https://devcentral.f5.com/wiki/iControl.LocalLB__Pool__remove_member_v2.ashx
            $Node = New-Object -TypeName iControl.CommonAddressPort;
            $Node.address = $VMName
            # Port is required by Common::AddressPort
            # https://devcentral.f5.com/wiki/iControl.Common__AddressPort.ashx
            $Node.port = F5GetMemberPort -VMName $VMName -Partition $Partition  -Pool $p
            Write-Host "Removing $VMName from F5 pool $p"
            (Get-F5.iControl).LocalLBPool.remove_member_v2($p, $Node)
        }

        ## Remove Node ##
        #################
        # You can only remove a node by ip address, not name
        $ip = F5GetIpFromNode -VMName $VMName -Partition $Partition
        Write-Host "Removing $VMName from F5"
        # Sometimes fails to remove from pool on first try https://devcentral.f5.com/questions/what-does-root-folder-mean-when-it-comes-to-vertual-server-create
        #
        $errorCount = 0
        $success = $false
        while ($errorCount -lt 3 -and !$success) {
            try {
              (Get-F5.iControl).LocalLBNodeAddress.delete_node_address($ip)
              $success = $true
            } catch {
                Write-Warning "Unable to remove node $($ip) from F5. Trying $(3-$errorCount) more times"
                $errorCount++
            }
            if ($errorCount -ge 2) {
                Write-Error "Unable to remove node from f5. Exiting"
                exit 1
            }
        }

    }
    # Remove Node
}
