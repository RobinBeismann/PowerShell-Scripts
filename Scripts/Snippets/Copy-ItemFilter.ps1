function Copy-ItemFilter($include,$sourcePath,$destPath){
    Get-ChildItem -Path $remoteBasePath -Recurse | ForEach-Object {
        if($_.PSisContainer){
            $path = Join-Path $destPath $_.FullName.Substring($sourcePath.length)
            if(!(Test-Path -Path $path -ErrorAction SilentlyContinue)){
                Write-CustomLog("Creating Directory: $path")
                New-Item -Path $path -ItemType Directory -Confirm:$false
            }
        }
        if($include.Contains(($_.Extension))){
            $path = Join-Path $destPath $_.FullName.Substring($sourcePath.length)
            if(!(Test-Path -Path $path -ErrorAction SilentlyContinue)){
                Write-CustomLog("Copying File: $path")
                $_ | Copy-Item -Destination $path -Confirm:$false
            }
        }    
    }
}
