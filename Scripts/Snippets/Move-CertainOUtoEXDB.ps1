Add-PSSnapIn Microsoft.Exchange.*

$DN = @{
        "DummyDN" = "Dest-DB"

    }
    
Get-Mailbox -Filter * -ResultSize 999999999 | % {
    $distinguishedName = $_.distinguishedName
    if(
        ($db = (($DN.GetEnumerator() | Where-Object { $distinguishedName.Endswith($_.Key) }).Value)) -and
        !(Get-MoveRequest | Where-Object { ($_.distinguishedName -eq $distinguishedName)  -and ($_.Status -ne "Completed") } ) -and
        $_.Database -ne $db
     ){
        $jobName = "Move $($_.DisplayName) to $db"
        Write-Host("Creating Job: $jobName")
        New-MoveRequest -Identity $_.Id -TargetDatabase $db -BatchName $jobName

    }
}
