function ModifyChef  {
    [CmdletBinding()]
    param(
        [Parameter(mandatory=$true)][String]$Name,
        [Parameter(mandatory=$false)][String]$Environment,
        [Parameter(mandatory=$false)][Array]$RunList,
        [Parameter(mandatory=$false)][Array]$NodeAttributes
    )

    # Import chef validation functions
    . .\lib\Chef.ps1

    ValidateKnifeCli

    ValidateKnifeConfigFile

    # Get the node definition as json from the chef server
    # Later this will be converted to an object that can be manipulated by powerform
    # Warning: ConvertFrom-Json only works with a single string (not an array of strings)
    # use 'out-string' to convert it http://powershelldistrict.com/powershell-json/
    # ConvertFrom-Json also doesn't like json that doesn't start with [] 
    # http://stackoverflow.com/questions/24453320/invalid-json-primitive-error-when-converting-json-file
    Write-Host "Fetching $Name from chef server ..." -ForegroundColor Green
    $data = knife node show $Name -F json | out-string
    $Node = ConvertFrom-Json $data

    $validation = $true
    if (!(ChefEnvironmentExists $Environment)) {
        Write-Warning "Environment $Environment absent on chef server"
        $validation = $false
    }
    if (!(ChefRoleExists $RunList)) {
        Write-Warning "RunList validation failed"
        $validation = $false
    }
    if ([string]::IsNullOrEmpty($Environment) ) {
        Write-Warning "Environment must not be null"
        $validation = $false
    }
    if ($RunList.Length -lt 1) {
        Write-Host "Empty Runlist, continuing..." -ForegroundColor Magenta
    }

    if ($validation) {

        # Create temporary location for json file used by knife
        # This wont work on mac
        if (!(Test-Path $env:LOCALAPPDATA\powerform\cache\provisioners\chef )) {
            Write-Host "Creating directory $env:LOCALAPPDATA\powerform\cache\provisioners\chef"
            New-Item $env:LOCALAPPDATA\powerform\cache\provisioners\chef -ItemType Directory 
        }

        # Write Backup file
        Write-Host "Saving node backup to $env:LOCALAPPDATA\powerform\cache\provisioners\chef\$Name.previous.json"
        $Node | ConvertTo-Json -Compress -Depth 9| Out-File -Encoding "ASCII" -Force $env:LOCALAPPDATA\powerform\cache\provisioners\chef\$Name.previous.json

        # Keep track if changes are needed
        # If not, skip the upload. Saves time 
        $ChefChanges = $false
        if ($Environment) {
            if ($Node.chef_environment -ne $Environment) {
                Write-Host "Changing environment from '$($Node.chef_environment)' to '$Environment'"  -ForegroundColor Blue -BackgroundColor white
                $Node.chef_environment = $Environment
                $ChefChanges = $true
            }
            else {
                Write-Host "Environments are identical" -ForegroundColor Green
            }
        }
        if ($RunList) {
            if ($RunList -ne $Node.run_list) {
                Write-Verbose "RunList diff is $RunListDiff"
                Write-Host "Setting runlist to $RunList" -ForegroundColor Blue -BackgroundColor white
                $Node.run_list = $RunList
                $ChefChanges = $true
            }
            else {
                Write-Host "run_lists are identical" -ForegroundColor Green
            }
        }
        if ($NodeAttributes) {
            # Powerform doesn't diff node specific settings. 
            # Instead it just clobbers whatever is there every time a vm is modified.
            Write-Host "Overwriting node specific attributes" -ForegroundColor Blue -BackgroundColor white
            ConvertTo-Json -Depth 9 $NodeAttributes[0] 
            $Node.normal = $NodeAttributes[0]

            # By default all nodes have empty tag list '"normal": {"tags": []}'
            # if powerform config doesn't have tags, add empty array back
            if (!($Node.normal.tags)) {
                $tags = @()
                Write-Verbose "Adding empty tag list"
                $Node.normal | Add-Member -Name tags -Value $tags -MemberType NoteProperty
            }
            $ChefChanges = $true
        }
    }
    else {
        Write-Warning "Validation Checks Failed"
        break
    }

    if ($ChefChanges) {
        # Convert Powershell object to json and store in cache location
        # Upload json file to chef server, overwriting all node attributes, environments & runlists
        $Node | ConvertTo-Json -Compress -Depth 9| Out-File -Encoding "ASCII" -Force $env:LOCALAPPDATA\powerform\cache\provisioners\chef\$Name.json
        knife node from file $env:LOCALAPPDATA\powerform\cache\provisioners\chef\$Name.json
    } 
    else {
        Write-Host "No Chef changes required on $Name, skipping" -ForegroundColor Green
    }

}
