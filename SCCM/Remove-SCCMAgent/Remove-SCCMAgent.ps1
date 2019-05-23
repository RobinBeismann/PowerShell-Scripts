function Write-CustomLog($text){
    Write-Host($text)
    $text  | Out-File -FilePath "$env:SystemRoot\Remove-SCCMAgent.ps1.log" -Confirm:$false -Append
}

Write-CustomLog -Text "Started Removing SCCM Agent"
Write-CustomLog -Text "Starting ccmsetup.exe /uninstall"
Start-Process -Verb RunAs -Wait -WindowStyle Hidden -FilePath "$env:SystemRoot\ccmsetup\ccmsetup.exe" -ArgumentList @("/uninstall")
Write-CustomLog -Text "Starting CCMDelCert.exe"
Start-Process -Verb RunAs -Wait -WindowStyle Hidden -FilePath "$env:SystemRoot\System32\CCMDelCert.exe"
Write-CustomLog -Text "Removing $env:SystemRoot\SMSCfg.ini"
Remove-Item -Recurse -Force -Confirm:$false -Path "$env:SystemRoot\SMSCfg.ini"
Write-CustomLog -Text "Removing $env:SystemRoot\ccmsetup"
Remove-Item -Recurse -Force -Confirm:$false -Path "$env:SystemRoot\ccmsetup"
Write-CustomLog -Text "Removing $env:SystemRoot\ccm"
Remove-Item -Recurse -Force -Confirm:$false -Path "$env:SystemRoot\ccm"
Write-CustomLog -Text "Removing $env:SystemRoot\ccmcache"
Remove-Item -Recurse -Force -Confirm:$false -Path "$env:SystemRoot\ccmcache"

Write-CustomLog -Text "Removing WMI Namespace CCM"
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='CCM'" -Namespace 'root' | Remove-WmiObject -Confirm:$false
Write-CustomLog -Text "Removing WMI Namespace sms"
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='sms'" -Namespace 'root\cimv2' | Remove-WmiObject -Confirm:$false

Write-CustomLog -Text "Removed SCCM Agent, removing Scheduled Task"

Unregister-ScheduledTask -TaskName "Remove-SCCMAgent" -Confirm:$false

Restart-Computer -Confirm:$false -Force