[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	$Time = "03:00"
)

if(!($time -match "^\d\d:\d\d$")){
    Write-Host("Error: Time is not properly formatted!")
    exit 1;
}

$timeSplit = $time.Split(":")
$hour = $timeSplit[0]
$minute = $timeSplit[1]

$currentTime = Get-Date

if(
    ($hour -gt $currentTime.Hour) -or
    (
        ($hour -eq $currentTime.Hour) -and
        ($minute -gt $currentTime.Minute)
    )
){
    Write-Host("Reboot is for today.")
    $rebootDay = $currentTime
}else{
    Write-Host("Reboot is for tomorrow.")
    $rebootDay = $currentTime.AddDays(1)
}
$rebootTime = Get-Date -Hour $hour -Minute $minute -Day $rebootDay.Day -Month $rebootDay.Month -Second 0

$timeToReboot = $rebootTime - $currentTime
Write-Host("Time until reboot: $($timeToReboot.Hours)h $($timeToReboot.Minutes)min $($timeToReboot.Seconds)sec")
$null = Start-Process -FilePath "shutdown.exe" -ArgumentList "-r -t $([math]::Round($timeToReboot.TotalSeconds)) -f"