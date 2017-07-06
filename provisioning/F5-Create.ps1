function F5CreateMember {
    [CmdletBinding()]
    param(
      [Parameter(mandatory=$true)][String]$VMName,
      [Parameter(mandatory=$true)][String]$VMIP,
      [Parameter(mandatory=$false)][String]$Port = 80,
      [Parameter(mandatory=$true)][Array]$Pools,
      [Parameter(mandatory=$false)][String]$Partition = 'Common',
      [Parameter(mandatory=$false)][Array]$HealthMonitors
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

    if (F5MemberExists -VMName $VMName -Partition $Partition) {
        Write-Warning "Member $VMName already exists" 
        $validation = $false
    }
    if (F5IPInUse -IP $VMIP -Partition $Partition) {
        Write-Warning "$VMIP already taken"
        $validation = $false
    }
    # TODO: validate health checks

    if (!($validation)) {
        Write-Warning "F5 validation checks failed, You may need to manually create VM in F5, see ./lib/Create-Provisioner-F5.ps1"
        break
    }
    else {
        Write-Verbose "F5 validation checks passed"

        ## Create Machine ##
        ####################
        # 0 = max connections, 0 = unlimited
        (Get-F5.iControl).LocalLbNodeAddressV2.create($VMName, $VMIP, 0)
        Write-Host "$VMName - $VMIP added to F5"

        ## Add Health Checks if any ##
        ##############################
        if ($HealthMonitors.length -ge 1 ) {
            Write-Host "Adding F5 Health Checks $HealthMonitors"
            # https://devcentral.f5.com/questions/set-existing-monitor-on-existing-node-in-powershell-f5-big-ip
            $MonitorRule = New-Object -TypeName iControl.LocalLBMonitorRule
            $MonitorRule.type = "MONITOR_RULE_TYPE_SINGLE"
            $MonitorRule.monitor_templates = $HealthMonitors
            (Get-F5.iControl).LocalLBNodeAddressV2.set_monitor_rule(@($VMName), $MonitorRule)
        }

        ## Add metadata ##
        ##################
        Write-Verbose "Adding Metadata go to F5 member"
        (Get-F5.iControl).LocalLbNodeAddressV2.add_metadata($VMName,('powerform'), ('true'))

        ## Add Description ##
        #####################
        $now = get-date -f s
        (Get-F5.iControl).LocalLbNodeAddressV2.set_description( (,$VMName), (, "created with powerform $now") )
        
        ## Add machine to pools ##
        ##########################
        # add_member_v2 only adds first pool in array because of bug

          $Pools | % {
            # Handle both syntaxes of pool state : ['foo'] and [{'foo':'disabled'}]
            if ($_.gettype().Name -eq 'PSCustomObject') {
                # If {"foo": "disabled", "port": "808" }, filter down to just 'foo'
                $_pool = [String]$_.psobject.properties.Name
                # Support custom port: { 'foo':{ "state":'disabled', 'port': '808' }}
                if ($_.psobject.properties.value.port) {
                    Write-Verbose "Found custom port $($_.psobject.properties.value.port)"
                    $_port = $_.psobject.properties.value.port
                }
            } elseif ($_.gettype().Name -eq 'String') {
                $_pool = $_
            } else {
                Write-Error "Unsupported pool type $($_.gettype().Name) for $($_)"
                break
            }
            if (!(F5PoolsExist -Partition $Partition -Pools $_pool)) {
                Write-Host "--------------------------------------------------"
                Write-Host "Pool $($_pool) does not exist. powerform can create it" -ForegroundColor Red
                Write-Host "but you will need to manually add the health monitor and assign a vip" -ForegroundColor Red
                Write-Host "the default load balancing will be 'round robin' " -ForegroundColor Red
                Write-Host "exiting will abort powerform execution and leave system in inconsistent state' " -ForegroundColor Red
                Write-Host "-------------------------------------------------------------------------------"

                $answer = Read-Host "Create f5 pool $($_pool)?  : y/n"
                while("y","n" -notcontains $answer)
                {
                    $answer = Read-Host "Create f5 pool $($_pool)?  : y/n"
                }
                if ($answer -eq 'n') {
                    break
                } else {
                    if ($_port) {
                        F5CreatePool -VMName $VMName -Pool $_pool -Port $_port -Partition $Partition
                    } else {
                        F5CreatePool -VMName $VMName -Pool $_pool -Port $Port -Partition $Partition
                    }
                }
            } else
            {
                if ($_port) {
                    # TODO: add with state
                    F5AddMemberToPools -VMName $VMName -Port $_port -Pool $_pool -Partition $Partition
                } else {
                    # TODO: add with state
                    F5AddMemberToPools -VMName $VMName -Port $Port -Pool $_pool -Partition $Partition
                }
            }
            # Since we check if $_port is defined on next loop, clear variable
            Remove-Variable _port -ErrorAction SilentlyContinue
        }
        
    }
}
