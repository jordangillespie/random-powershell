function F5ModifyNode {
    [CmdletBinding()]
    param(
      [Parameter(mandatory=$true)][String]$VMName,
      [Parameter(mandatory=$false)][String]$Partition = 'Common',
      [Parameter(mandatory=$false)][String]$Port = 80,
      [Parameter(mandatory=$false)][Array]$Pools, # Could be in format ['foo'], or [{'foo': { "state": "disabled" }}] or [{'foo': {"state": "disabled",'port':'42'}}]
      [Parameter(mandatory=$false)][Array]$HealthMonitors
    )

    # Get vm parition, if doesn't match, change it
    $validation = $true
    if (!(F5PartitionExists $Partition)) {
        Write-Warning "Partition $($Partition) does not exist"
        $validation = $false
    }
    # F5PoolsExist handles both ['foo'] and [{'foo':disabled}] syntaxes
    if ( $Pools.length -le 0) {
        Write-Host "No F5 Pools defined"
    } elseif (!(F5PoolsExist -Partition $Partition -Pools $Pools)) {
        # Allow adding of Pools
        #$validation = $false
    } else {

    }

    if ( $HealthMonitors.length -le 0) {
        Write-Host "No HealthMonitors defined"
    } else {
        $HealthMonitors | % {
            # TODO: not yet implemented
            if (!(F5MemberHealthMonitorExists -VMName $VMName -HealthMonitor $_ )) {
                $validation = $false
            }
        }
    }

    # TODO: Add support for health monitors
    # TODO: Should support changing port of vm?
    # TODO: implement partition check, that will be tricky

    if ($validation) {

        # 1. Add missing pools
        ######################
        Write-Host "Looking for pools to add"
        $memberPools = F5GetMemberPools -VMName $VMName -Partition $Partition | Foreach-object { $_ -replace "/$($Partition)/", '' }

        Write-Verbose "F5-Modify memberPools are $($memberPools)"

        # Itterate over powerform pools, see if powerform has any that aren't on f5
        $Pools | % {
            # Extract 'foo' from full object: {'foo':{ "state":"disabled" }}
            if ($_.gettype().Name -eq 'PSCustomObject') {
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
            # Create pool if doesn't exist
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
            }
            
            # Add member to pool
            if ($memberPools -eq $null -or !($memberPools -contains $_pool)) {
                # Pool defined in powerform, but not active in f5. Adding it
                Write-Host "Adding $($VMName) to F5 Pool: '$($_pool)'" -ForegroundColor Blue -BackgroundColor white
                # TODO support changing port number, This will fail if port has changed
                if ($_port) {
                    Write-Host "Using custom port $($_port)"
                    F5AddMemberToPools -VMName $VMName -Port $_port -Pools $_pool -Partition $Partition
                } else {
                    F5AddMemberToPools -VMName $VMName -Port $Port -Pools $_pool -Partition $Partition
                }
            }
            # Since we check if $_port is defined on next loop, clear variable
            Remove-Variable _port -ErrorAction SilentlyContinue
        }

        # 2. Remove extra pools
        #######################
        Write-Host "Looking for pools to remove"
        $memberPools = F5GetMemberPools -VMName $VMName -Partition $Partition | Foreach-object { $_ -replace "/$($Partition)/", '' }
        if ($memberPools -ne $null) {
            # Take the powerform list of pools, reduce it to just the names. e.g [{'foo':'enabled'}] maps to 'foo'
            $powerformPools = @()
            $Pools | % {
                # Handle both syntaxes of pool state : ['foo'] and [{'foo':{"state": "disabled"}}]
                if ($_.gettype().Name -eq 'PSCustomObject') {
                    $powerformPools += [String]$_.psobject.properties.Name
                } elseif ($_.gettype().Name -eq 'String') {
                    $powerformPools += $_
                } else {
                    Write-Error "Unsupported pool type $($s.gettype().Name) for $($_)"
                    break
                }
            }
            $memberPools | % {
                if (!($powerformPools -contains $_)) {
                    # Pool in F5, but not in powerform, remove it
                    Write-Host "Removing $($VMName) from F5 Pool: '$($_)'" -ForegroundColor blue -BackgroundColor White
                    # Get the member port number from the f5
                    $_port = F5GetMemberPort -VMName $VMName -Partition $Partition -Pool $_
                    F5RemoveMemberFromPools -VMName $VMName -Port $_port -Pools $_ -Partition $Partition
                }
            }
        } else {
            Write-Host "$($VMName) not in any pools, nothing to remove"
        }

        # 3. Set member state in pools (disabled, forced offline, enabled)
        ##################################################################
        Write-Host "Looking for pool states to change"
        $memberPoolsFullName = F5GetMemberPools -VMName $VMName -Partition $Partition | Foreach-object { $_ -replace "/$($Partition)/", '' }

        # Create hashes of all f5 states {"foo": {"state": "enabled","port": "42" }}, If not defined, set to 'enabled'
        $F5States = @{}
        $PowerformStates = @{}
        $memberPools | % {
            # Create object of every actual state in f5. {"foo": {"state": "enabled", "port": "9000"}}
            if (F5MemberExistsInPool -VMName $VMName -Pool $_ -Partition $Partition) {
                $F5States.$_  = @{ state = $(F5GetMemberPoolState -VMName $VMName -Partition $Partition -Pool $_) ; port = $(F5GetMemberPort -VMName $VMName -Partition $Partition -Pool $_) }
            } else {
                Write-Host "$($VMName) not in pool $($_). Skipping f5 fetch"
            }
        }
        # F5States is a hash, can't print hashes with write-verbose. Convert to json
        Write-Verbose "F5 Member States are:"
        Write-Verbose "$(ConvertTo-Json -Depth 9 $F5States)"
        $Pools | % {
            # Handle both syntaxes of pool state : ['foo'] and [{'foo':{"state":'disabled', "port": "42" }}]
            if ($_.gettype().Name -eq 'PSCustomObject') {
                # $Pool is a powershell custom object, and $PowerformStates is a hash, get the object properies
                $pool_name = $_.psobject.properties.Name
                $PowerformStates.$pool_name = @{}
                if ($_.psobject.properties.value.state) {
                    $PowerformStates.$pool_name.state = $_.psobject.properties.value.state
                } else {
                    $PowerformStates.$pool_name.state = "enabled"
                }
                if ($_.psobject.properties.value.port) {
                    $PowerformStates.$pool_name.port = $_.psobject.properties.value.port
                } else {
                    $PowerformStates.$pool_name.port = $Port
                }
            } elseif ($_.gettype().Name -eq 'String') {
                $PowerformStates.$_ = @{ state = "enabled"; port = $Port }
            } else {
                Write-Error "Unsupported pool type $($_.gettype().Name) for $($_)"
                break
            }
        }
        Write-Verbose "Powerform Member States are:"
        Write-Verbose "$(ConvertTo-Json -Depth 9 $PowerformStates)"
        # Theoretically the number of F5 pools a member is in should now match the powerform state
        # especially because we just querried the f5. If that isn't the case, throw a big warning
        if ( $F5States.length -ne $PowerformStates.length ) {
            Write-Error "==============================================="
            Write-Error "F5 Desired state inconsistent from actual state"
            Write-Error "F5 State: "
            $F5State = $F5States.Getenumerator() | % { "$($_.Name):$($_.Value)" }
            Write-Error "Poweform State:"
            $PowerformStates.Getenumerator() | % { "$($_.Name):$($_.Value)" }
            Write-Error "==============================================="
            break
        }
        # Change the F5 state if it doesn't match what powerform says it should have
        # if the pool/member does not have a health check defined (blue square),
        # it is in a permanent 'offline' state and any attempt by powerform to change it will be ignored by the F5. 
        if ( $F5States.length -gt 0 ) {
            $F5States.GetEnumerator() | % {
                if ( ($F5States.($_.key).state) -ne ($PowerformStates.($_.key).state) ) {
                    Write-Host "$($_.key) $($F5States.($_.key).state) in F5, yet $($PowerformStates.($_.key).state) in powerform"
                    if ( ($F5States.($_.key).port) -ne ($PowerformStates.($_.key).port) ) {
                        Write-Verbose "F5 port '$(($_.key).port)' doesn't match powerform port '$($PowerformStates.($_.key).port)'"
                        Write-Host "Powerform doesn't yet support changing f5 port, aborting" -ForegroundColor Red
                        break
                    } else {
                        F5SetMemberPoolState -VMName $VMName -Port $F5States.($_.key).port -Partition $Partition -Pool $_.key -State $PowerformStates.($_.key).state
                    }
                } else {
                    Write-Verbose "$($VMName) already set to $($F5States.($_.key).state) which matches $($PowerformStates.($_.key).state) in pool $($_.key)"
                }
            }
        } else {
            Write-Verbose "$($VMName) not found in any F5 pools"
        }

    } else {
        Write-Warning "Validation Checks Failed"
        break
    }
}
