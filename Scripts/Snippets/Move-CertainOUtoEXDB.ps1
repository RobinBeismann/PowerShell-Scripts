Add-PSSnapIn Microsoft.Exchange.*
Get-Mailbox -Filter * | Where-Object {
    $_.DistinguishedName.EndsWith("xyz")
} | % {
    $jobName = "Move $($_.DisplayName)"
    Write-Host("Creating Job: $jobName")
    New-MoveRequest -Identity $_.Id -TargetDatabase "DB07" -BatchName $jobName

}
