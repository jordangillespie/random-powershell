function DeprovisionChef {
    [CmdletBinding()]
    param(
        [Parameter(mandatory=$true)][String]$VM
    )
    # Import chef validation functions
    . .\lib\Chef.ps1

    ValidateKnifeCli

    ValidateKnifeConfigFile

    $nodeDeleteOrigional = knife node delete $VM -y
    if ($nodeDeleteOrigional) {
        knife client delete $VM -y
    }
    else {
        Write-Warning "Failed to delete node $VM, trying again all lower case"
        $nodeDeleteLower = knife node delete $VM.ToLower() -y
        if ($nodeDeleteLower) {
            knife client delete $VM.ToLower() -y
        }
        else {
            Write-Warning "Failed to delete node $VM, trying again all upper case"
            $nodeDeleteLower = knife node delete $VM.ToUpper() -y
            if ($nodeDeleteLower) {
                knife client delete $VM.ToUpper() -y
            }
            else {
                Write-Warning "Unable to delete node $VM. CamelCase vm names not supported, you will need to manually remove from chef server"
            }
        }
    }
}
