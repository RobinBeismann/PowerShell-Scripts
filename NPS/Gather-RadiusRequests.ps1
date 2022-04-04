#This script gathers RADIUS Requests and formats them to a readable and searchable table
$servers = Read-Host("Enter RADIUS Server FQDNs (Semicola delimited)")

$radiusServers = $servers.Split(";")

$eventsSum = @()

$xmlFilter = [xml]@"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='NPS']]]</Select>
    <Select Path="Security">*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and Task = 12552]]</Select>
  </Query>
</QueryList>
"@

$formatedEvents = New-Object System.Collections.ArrayList

$radiusServers | ForEach-Object {
    Write-Host("Gathering Events for $_")
    $eventsSum += Invoke-Command -ComputerName $_ -ArgumentList $xmlFilter -ScriptBlock {
        param($xmlFilter)

        $authenticationEvents = @()

        Get-WinEvent -FilterHashtable @{ logName = 'Security'; ID = 6272, 6273 } -MaxEvents 99999999 -ErrorAction SilentlyContinue | ForEach-Object {
            $authenticationEvents += $_
        }
        
        $authenticationEvents | ForEach-Object {
            switch($_.Id){
                6272 {
                    $action = "Granted"
                }
                6273 {
                    $action = "Denied"
                }
            }

            $user = $_.Properties[1].Value
            $radius = $_.Properties[19].Value
            $ap = $_.Properties[15].Value
            $ssid = $_.Properties[17].Value

            [ordered]@{
                User = $user
                Server = $radius
                AP = $ap
                Action = $action
                Time = $_.TimeCreated
            }                
        }          
    }
}

$eventsSum | ForEach-Object {
    $formatedEvents.Add([PSCustomObject]$_)
}


$formatedEvents | Out-GridView
