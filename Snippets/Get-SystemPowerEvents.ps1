#region StaticDefinitions 
$computerName = $env:computerName

$EventTypes = @(
     @{
        Type = "ResumeStandby"
        Filter = @{logname='System'; id=1; ProviderName='Microsoft-Windows-Power-Troubleshooter'}
     },
     @{
        Type = "SystemBoot"
        Filter = @{logname='System'; id=12; ProviderName='Microsoft-Windows-Kernel-General'}
     },
     @{
        Type = "StartStandby"
        Filter = @{logname='System'; id=42; ProviderName='Microsoft-Windows-Kernel-Power'}
     },
     @{
        Type = "ShutdownClean"
        Filter = @{logname='System'; id=1074}
     },
     @{
        Type = "RebootClean"
        Filter = @{logname='System'; id=1074}
     },
     @{
        Type = "RebootDirty"
        Filter = @{logname='System'; id=41}
     },
     @{
        Type = "ShutdownClean"
        Filter = @{logname='System'; id=6006}
     },
     @{
        Type = "ShutdownDirty"
        Filter = @{logname='System'; id=6008}
     },
     @{
        Type = "SystemBootEventLogStart"
        Filter = @{logname='System'; id=6005}
     },
     @{
        Type = "ShutdownEventLogEnd"
        Filter = @{logname='System'; id=6006}
     },
     @{
        Type = "UserInitiatedLogon"
        Filter = @{logname='Security'; id=4624}
        AdditionalProperties = @(
            @{
                Username = 1
            }
        )
     },
     @{
        Type = "UserInitiatedLogoff"
        Filter = @{logname='Security'; id=4647}
        AdditionalProperties = @(
            @{
                Username = 1
            }
        )
     },
     @{
        Type = "UserInitiatedUnlock"
        Filter = @{logname='Security'; id=4801}
        AdditionalProperties = @(
            @{
                Username = 1
            }
        )
     },
     @{
        Type = "UserInitiatedLock"
        Filter = @{logname='Security'; id=4800}
        AdditionalProperties = @(
            @{
                Username = 1
            }
        )
     }
    
)

#$ExportDateFormat = "yyyy/MM/dd HH:mm:ss"
$ExportDateFormat = "dd.MM.yyyy HH:mm:ss"
#endregion

#region Vars
$Events = @()
#endregion

#region Pull Logs
$AdditionalProperties = $EventTypes.AdditionalProperties.Keys | Sort-Object -Unique
$EventTypes.GetEnumerator() | ForEach-Object {
    $Type = $_
    Write-Host("[$(Get-Date) - $computerName] Querying $($_.Type)")

    Get-WinEvent -FilterHashtable $_.Filter -ComputerName $computerName -ErrorAction SilentlyContinue | ForEach-Object {
        $RawEvent = $_
        $Event = [PSCustomObject]@{
            Time = (Get-Date -Date $_.TimeCreated -Format $ExportDateFormat)
            Type = $Type.Type
            Message = $_.Message | ConvertTo-Json -Compress
            TimeRaw = $_.TimeCreated
        } 
        $AdditionalProperties | ForEach-Object {
            $Event | Add-Member -MemberType NoteProperty -Name $_ -Value ""
        }

        if($Type.AdditionalProperties){
            $Type.AdditionalProperties.GetEnumerator() | ForEach-Object {
                $Prop = $_
                if($RawEvent.Properties[$Prop.Values]){
                    $Event.$($Prop.Keys) = ([string]$RawEvent.Properties[$Prop.Values].Value)
                }
            }
        }
        
        $Events += $Event
    }
}

#endregion

#region Export Logs
Write-Host("[$(Get-Date) - $computerName] Sorting..")
$EventsSorted = $Events | Sort-Object -Property TimeRaw
$fileName = "ExportLogs_$($computerName)_$(Get-Date -Format "yyyyMMddHHmm")_Start-$(Get-Date -Date $EventsSorted[0].TimeRaw -Format "yyyyMMddHHmm")_End-$(Get-Date -Date $EventsSorted[-1].TimeRaw -Format "yyyyMMddHHmm").csv"
$Path = "$env:USERPROFILE\Desktop\$fileName"
Write-Host("[$(Get-Date) - $computerName] Exporting to `"$Path`"..")
$EventsSorted | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Force
$Path | Set-Clipboard
#endregion
