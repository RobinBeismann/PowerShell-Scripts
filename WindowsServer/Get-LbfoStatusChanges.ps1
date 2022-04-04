<#----------------------------------------------------------------------------------------------------------------------------
April 2022 - Robin Beismann

Searches for Event ID 16949 in the System Event log and resolves the Adapter Instance GUID to the Adapter Name and MAC Address.
This allows to find events where a NIC Team Member goes down.

----------------------------------------------------------------------------------------------------------------------------#>

[array]$hosts = "host1", "host2"

$NICs = @{}

$tbl = $hosts | ForEach-Object {
    $hostname = $_
    Write-Host("[$hostname] Querying Host..")

    $events = Get-WinEvent -ComputerName $hostname -FilterHashtable @{
        ID = 16949
        LogName = 'System'
    } 
    
    Write-Host("[$hostname] Processing Host..")
    $events | ForEach-Object {
        $event = $_
        $nicGuid = $_.Properties.Value[1]
        if(!($NICs.$hostname)){
            Write-Host("[$hostname] Retrieving NICs..")
            $NICs.$hostname = Invoke-Command -ComputerName $hostname -ScriptBlock { Get-NetAdapter }
            Write-Host("[$hostname] Retrieved NICs.")
        }
        $nic = $NICs.$hostname | Where-Object { $_.InstanceId -eq $nicGuid }

        [PSCustomObject]@{
            Host = $hostname
            Time = ($event.TimeCreated | Get-Date -Format "yyyy\/MM\/dd HH:mm:ss")
            NICName = $nic.Name
            NICMacAddress = $nic.MacAddress
        }
    }
}

$tbl | Out-GridView