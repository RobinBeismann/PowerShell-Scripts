#Enter Time in UTC and get a list of Maintenance Windows

$timeZones = @{
    "Germany" = (Get-TimeZone | Select-Object -ExpandProperty Id)
    "San Francisco" = "Pacific Standard Time"
    "New York" = "Eastern Standard Time"
    "Ohio" = "Central Standard Time"
    "China" = "China Standard Time"
    "Tokyo" = "Tokyo Standard Time"
    "Seoul" = "Korea Standard Time"
}

$date = Read-Host("Enter Date in Format: hh:mm dd.MM.yyyy")
$utcDate = (Get-Date $date).ToUniversalTime()

$timeZones.GetEnumerator() | ForEach-Object {
    $site = $_.Name
    $zone = Get-TimeZone -Id $_.Value

    $lDate = $utcDate.Add( $zone.BaseUtcOffset ) 
    $lDate = (Get-Date -Date $lDate -Format "yyyy-MM-dd HH:mm")
    Write-Host("Location: $site`n`tLocal Time: $lDate `n`tTime Zone: $($zone.DisplayName)`n")
    
}

Set-Clipboard -Value $script:log -Confirm:$false
