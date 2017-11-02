<#
 .Synopsis
  Writes out a file or updates the LastWriteTime on files passed to it. Similar to the linux `touch` command.

 .Description
  Supports touching a single file or accepts pipeline input for multiple files.

 .Parameter file
  The path or paths to be touched.


 .Example
   # Touch a file located in C:\temp\file.txt
   Touch-File "C:\temp\file.txt"

 .Example
   # Touch all files in C:\temp
   (Get-ChildItem C:\temp).FullName | Touch-File
#>
Function Touch-File {
    param(
        [parameter(mandatory=$true,Position=1,ValueFromPipeline=$true)][string[]]$file
    )
    Begin {
        Write-Verbose "Touching all files passed to this function"
    }
    Process {
        if(Test-Path $file) {
            Write-Verbose "Updating LastWriteTime on $(Get-ChildItem $file) from $($(Get-ChildItem $file).LastWriteTime) to $(Get-Date)"
            (Get-ChildItem $file).LastWriteTime = Get-Date
        }
        else {
            Write-Verbose "Creating empty file: $file"
            echo $null > $file
        }
    }
    End {
        Write-Verbose "Done Touching files"
    }
}
Export-ModuleMember -Function Touch-File
