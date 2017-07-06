function ProvisionChef {
    [CmdletBinding()]
    param(
        [Parameter(mandatory=$true)][String]$Name,
        [Parameter(mandatory=$true)][String]$IP,
        [Parameter(mandatory=$true)][String]$OS,
        [Parameter(mandatory=$false)][Array]$RunList,
        [Parameter(mandatory=$false)][String]$Environment,
        [Parameter(mandatory=$false)][String]$IdentityFile,
        [Parameter(mandatory=$false)][String]$JsonAttribs,
        [Parameter(mandatory=$false)][String]$Username,
        [Parameter(mandatory=$false)][String]$Password,
        [Parameter(mandatory=$false)][String]$BootstrapVersion
    )

    # Import chef validation functions
    . .\lib\Chef.ps1

    ValidateKnifeCli

    ValidateKnifeConfigFile

    # Turn array into string since bootstrap command expects string 
    # @('role[foo]','role[bar]') becomes 'role[foo],role[bar]'
    $RunListString = $RunList -join ','


    if ($JsonAttribs) {
        # Chef + powershell requires nested strings
        # https://docs.chef.io/knife_node.html#id19
        # knife bootstrap -j '''{"foo":"bar"}'''
        # Add 2 or 3 single quotes here, the 3rd will be added when building the string
        $JsonAttribsString = "''" + $JsonAttribs + "''"
    }
    else {
        # If user doesn't provide jsonattrib, make sure it is empty preventing later step from thinking escape strings are content
        $JsonAttribsString = ""
    }

    # Join all possible bootstrap arguments into key value pairs
    # Generate the bootstrap command off only the keys that have valid values
    # e.g. user does not provide $JsonAttribs, omit "--json-attributes $JsonAttribs" from the bootstrap command
    $BootstrapValues = @{ `
      '--node-name' = "${Name}"; `
      '-x' = "${Username}"; `
      '-P' = "${Password}"; `
      '--run-list' = "${RunListString}"; `
      '--ENVIRONMENT' = "${Environment}"; `
      '--json-attributes' = ${JsonAttribsString}; `
      '-i' = "${IdentityFile}"; `
      '--bootstrap-version' = "${BootstrapVersion}" }
    $BootstrapCommand = new-object System.Text.stringbuilder

    foreach ($i in $BootstrapValues.keys) {
        if ( ![string]::IsNullOrEmpty($i) -and ![string]::IsNullOrEmpty($BootstrapValues[$i]) ) {
            $BootstrapCommand.append($i) | Out-Null
            $BootstrapCommand.append(" '") | Out-Null
            $BootstrapCommand.append($BootstrapValues[$i]) | Out-Null
            $BootstrapCommand.append("' ") | Out-Null
        } 
        else {
            Write-Verbose "skipping empty bootstrap value $($i)"
        }
    }

    if ($OS -like 'windows')
    {
        $command = "knife bootstrap windows winrm $IP $BootstrapCommand"
        Write-Host $command
        try {
            Invoke-expression $command
        } catch {
            Write-Error "Bootstrap failed"
            $_
            exit 1
        }
    }
    elseif ($OS -like 'linux')
    {
        $command = "knife bootstrap $IP --sudo $BootstrapCommand"
        Write-Host $command
        try {
            Invoke-expression $command
        } catch {
            Write-Error "Bootstrap failed"
            $_
            exit 1
        }
    }
    else
    {
        Write-Warning "OS must be either 'windows' or 'linux', not $($OS)"
        exit 1
    }
}
