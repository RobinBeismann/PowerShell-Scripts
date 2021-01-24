$Logshare = ""
$Computerlogshare = "$logshare\$($env:Computername)"
$tempDir = "$($env:temp)\LogUploadTemp"
$tempLogArchive = "$($env:temp)\LogUploadArchive.zip"
$eventLogs = "system", "security", "application", "installations"

if(!(Test-Path -Path $Computerlogshare)){
    Write-Host("Creating $Computerlogshare")
    New-Item -Path $Logshare -Force -ErrorAction SilentlyContinue -Name $env:Computername -ItemType Directory | Out-Null
}

$logPaths = @()
#Get path for SCCM client Log files
if(
    ($Logpath = Get-ItemProperty -Path "HKLM:\Software\Microsoft\CCM\Logging\@Global" -ErrorAction SilentlyContinue) -and
    ($Log = $logpath.LogDirectory)
){
    Write-Host("Extracted $Log as Logpath for CCM")
    $logPaths += $Log
}
#Add generic log paths
$logPaths += "C:\Windows\ccmsetup\Logs"
# Add additional log paths like $logPaths += "C:\ProgramData\<Company>\Logs"

#Create Temp Directory
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

#Loop through log paths, create and create a copy
$logPaths | ForEach-Object {
    if(Test-Path -Path $_ -ErrorAction SilentlyContinue){
        Write-Host("Adding Log Folder $_")
        $plainPath = $_.Replace("/","_")
        $plainPath = $plainPath.Replace("\","_")
        $plainPath = $plainPath.Replace(":","_")
        $plainPath = $plainPath.Replace(".","_")
        $plainLogPath = "$tempDir\$plainPath"

        Copy-Item -Path $_ -Destination $plainLogPath -Recurse -Force
    }else{
        Write-Host("Log Folder $_ does not exist")
    }
}
Get-ChildItem -Path "Env:" | Out-File -FilePath "$tempDir\environment.txt"

#Gather Eventlogs
New-Item -Path "$tempDir\eventlogs" -ItemType Directory -Force | Out-Null
Get-WmiObject -Class "Win32_NTEventlogFile" | ForEach-Object {
    Write-Host("Backing up eventlog " + $_.LogFileName)
    $null = $_.BackupEventlog("$tempDir\eventlogs\$($_.LogFileName).evtx")
}

#Create a .zip archive with sccm logs
Write-Host("Compressing $tempDir to $tempLogArchive")
Compress-Archive -Path $tempDir -CompressionLevel Optimal -DestinationPath $tempLogArchive

#Copy zipped logfile to servershare
Write-Host("Uploading $tempLogArchive to $Computerlogshare")
Copy-Item -Path $tempLogArchive -Destination $Computerlogshare

#Cleanup temporary files/folders
Write-Host("Deleting $tempDir")
Remove-Item -Path $tempDir -Recurse -Force | Out-Null
Write-Host("Deleting $tempLogArchive")
Remove-Item -Path $tempLogArchive -Recurse -Force | Out-Null
