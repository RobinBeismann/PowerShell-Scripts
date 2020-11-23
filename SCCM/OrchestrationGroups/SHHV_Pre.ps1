# Example Script for Single Hyper-V Host Patching with Orchestration Groups (Pre-Script)
# 	- Saves all current VM States
#	- Shuts down those with Integration Tools
#	- Saves/Freezes those without Integration Tools
# You will either need to replace the Send-TeamsMessage Function or atleast fill it up with your webhook under $connectorUri

function Send-TeamsMessage($Message){
    $connectorUri = "https://outlook.office.com/webhook/"
    $body = [ordered]@{
        "@type" = "MessageCard"
        "summary" = "SHHV Patching is running on $env:Computername"
        "themeColor" = $(
            if($Message.ToLower().Contains("error")){
                "#eb4034"
            }else{
                "#a6a6a6"
            }
        )
        "sections" = @(
            @{
                activityTitle = "SHHV Patching"
                facts = @(
                    @{
                        name = "Server"
                        value = $env:COMPUTERNAME
                    },
                    @{
                        name = "Message"
                        value = $Message
                    }
                )            
            }
        )
    }
     
    $null = Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body ($body | ConvertTo-Json -Depth 5) -Uri $connectorUri
}
 
$tempDir = "C:\OrchestrationPatching"
$file = "VMState.xml"
$filePath = "$tempDir\$file"
Send-TeamsMessage -Message "Server Patching Run started.."
 
if(Test-Path -Path $filePath -ErrorAction SilentlyContinue){
    try{
        Remove-Item -Path $filePath -ErrorAction Stop
    }catch{
        Send-TeamsMessage -Message "Could not delete state file from last patching cycle, stopping orchestration!"
    }
}

if (
    # VMs found, save their state and shut them down or pause them depending on Integration tools
    (
        $VMNoShut = Get-VM | Where-Object {$_.State -eq 'Running'} |
        Get-VMIntegrationService |
        Where-Object {$_.Name -eq 'Shutdown' -and $_.OperationalStatus -ne 'NoContact'}
    )
){
    #Create TempDir
    if(!(Test-Path -Path $tempDir)){
        Write-Host("Creating Directory for Patching under $tempDir")
        New-Item -ItemType Directory -Path $tempDir -Force
    };
     
    try{
        Get-VM -ErrorAction Stop | Export-Clixml -Path $filePath -Force -ErrorAction Stop
    }catch{
        Send-TeamsMessage -Message "Failed to save current VM status, exiting."
        Write-Host("Unable to export VM State to $filePath - error: $_")
        exit 1;
    }
 
    try{
        #Shutdown VMs with Integration Services
        Get-VM | Where-Object { $_.State -eq 'Running' } | Get-VMIntegrationService | Where-Object { $_.Name -eq 'Shutdown'  -and $_.OperationalStatus -ne 'NoContact' } | Select-Object -ExpandProperty 'VMName' | ForEach-Object {
            Send-TeamsMessage -Message "Shutting down VM $($_.Name).."
            $_ | Stop-VM
        }
        #Freeze VMs without Integration Services
        Get-VM | Where-Object { $_.State -eq 'Running' } | Get-VMIntegrationService | Where-Object { $_.Name -eq 'Shutdown'  -and $_.OperationalStatus -eq 'NoContact' } | Select-Object -ExpandProperty 'VMName' | ForEach-Object {
            Send-TeamsMessage -Message "Freezing/Pausing VM $($_.Name).."
            $_ | Save-VM
        }
    }catch{
        Write-Host("Failed to stop VMs: $_ - resuming.")
        $VMs = Import-Clixml -Path $filePath
        $VMs | Where-Object { $_.State.Value -eq "Running" } | Sort-Object { ($_.Name -like "*DC*") } -Descending | ForEach-Object {
            Send-TeamsMessage -Message "Starting VM $($_.Name).."
            Write-Host("Starting $($_.Name).")
            Start-VM -Name $_.Name -ErrorAction Ignore
            Resume-VM -Name $_.Name -ErrorAction Ignore
            if($_.Name -like "*DC*"){
                Write-Host("VM $($_.Name) looks like a DC, sleeping 60 seconds before booting other VMs..")
                Start-Sleep -Seconds 30
            }
        }
        exit 1;
    }
    Send-TeamsMessage -Message "Patching and Rebooting Host.."
}elseif( #No running VMs
    ($VMs = Get-VM) -and
    ($VMs.Count -gt 0) -and
    !($VMs | Where-Object {$_.State -eq 'Running'})
){
    Send-TeamsMessage -Message "No running VMs found, patching and rebooting host."
}else{ #Unknown status -> better break instead of messing things up    
    $VMNoShut;
    exit 1;
}
exit 0;