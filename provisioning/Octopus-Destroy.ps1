function OctopusDestroyMachine {
    [CmdletBinding()]
    param(
        [Parameter(mandatory=$true)][String]$VMName,
        [Parameter(mandatory=$false)][String]$OctopusServer = 'https://octopus.netdocuments.com',
        [Parameter(mandatory=$true)][String]$ApiKey
      )

    $validation = $true
    # Validate can connect through API
    #TODO: implement api test

    # Validate machine exists
    $allMachines = (GetAllOctopusMachines -OctopusServer $OctopusServer -ApiKey $ApiKey)
    if (!($allMachines.Name -contains $VMName)) {
        Write-Warning "Unable to find machine $VMName on Octopus Server"
        $validation = $false
    }

    # Delete machine
    if ($validation -eq $true) {
        Write-Host "Deleting $VMName from Octopus Server"
        $MachineID = GetOctopusMachineIDFromName -allMachines $allMachines -VMName $VMName
        try {
          DeleteOctopusMachine -OctopusServer $OctopusServer -ApiKey $ApiKey -MachineID $MachineID
        }
        catch {
          Write-Warning "Unable to delete $VM from Octopus Server"
        }
    }
    else {
        Write-Warning "Octopus validation checks failed, skipping"
        break
    }
}
