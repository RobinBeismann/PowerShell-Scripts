#region StaticDefinitions 
$computerName = $env:computerName

$EventTypes = @(
     @{
        Type = "ResumeStandby"
        Filter = @{logname=’System’; id=1; ProviderName='Microsoft-Windows-Power-Troubleshooter'}
     },
     @{
        Type = "SystemBoot"
        Filter = @{logname=’System’; id=12; ProviderName='Microsoft-Windows-Kernel-General'}
     },
     @{
        Type = "StartStandby"
        Filter = @{logname=’System’; id=42; ProviderName='Microsoft-Windows-Kernel-Power'}
     },
     @{
        Type = "Shutdown"
        Filter = @{logname=’System’; id=1074}
     },
     @{
        Type = "SystemBootEventLogStart"
        Filter = @{logname=’System’; id=6005}
     },
     @{
        Type = "ShutdownEventLogEnd"
        Filter = @{logname=’System’; id=6006}
     }
    
)

#$ExportDateFormat = "yyyy/MM/dd HH:mm:ss"
$ExportDateFormat = "dd.MM.yyyy HH:mm:ss"
#endregion

#region Vars
$Events = @()
#endregion

#region Pull Logs
$EventTypes.GetEnumerator() | ForEach-Object {
    $Type = $_
    Write-Host("[$(Get-Date) - $computerName] Querying $($_.Type)")
    Get-WinEvent -FilterHashtable $_.Filter -ComputerName $computerName | ForEach-Object {
        $Events += [PSCustomObject]@{
            Time = (Get-Date -Date $_.TimeCreated -Format $ExportDateFormat)
            Type = $Type.Type
            Message = $_.Message | ConvertTo-Json -Compress
            TimeRaw = $_.TimeCreated
        }
    }
}

#endregion

#region Export Logs
Write-Host("[$(Get-Date) - $computerName] Sorting..")
$EventsSorted = $Events | Sort-Object -Property TimeRaw
Write-Host("[$(Get-Date) - $computerName] Exporting..")
$fileName = "ExportLogs_$($computerName)_$(Get-Date -Format "yyyyMMddHHmm")_Start-$(Get-Date -Date $EventsSorted[0].TimeRaw -Format "yyyyMMddHHmm")_End-$(Get-Date -Date $EventsSorted[-1].TimeRaw -Format "yyyyMMddHHmm").csv"
$EventsSorted | Export-Csv -Path "$env:USERPROFILE\Desktop\$fileName" -NoTypeInformation -Encoding UTF8 -Delimiter ";"
#endregion