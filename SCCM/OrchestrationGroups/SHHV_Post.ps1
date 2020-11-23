# Example Script for Single Hyper-V Host Patching with Orchestration Groups (Post-Script)
# 	- Starts all VMs based on their state before shutdown
#	- Starts by starting any VMs with "DC" (Domain Controller) in the name
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
Send-TeamsMessage -Message "Server Patching finished, starting VMs.."
 
$lError = $false

if(Test-Path -Path $filePath -ErrorAction SilentlyContinue){ 
    $VMs = Import-Clixml -Path $filePath
    $VMs | Where-Object { $_.State.Value -eq "Running" } | Sort-Object { ($_.Name -like "*DC*") } -Descending | ForEach-Object {
        Send-TeamsMessage -Message "Starting VM $($_.Name).."
        Write-Host("Starting $($_.Name).")
        try{
            Start-VM -Name $_.Name -ErrorAction Ignore
            Resume-VM -Name $_.Name -ErrorAction Ignore
            if($_.Name -like "*DC*"){
                Write-Host("VM $($_.Name) looks like a DC, sleeping 60 seconds before booting other VMs..")
                Start-Sleep -Seconds 30
            }
        }catch{
            $lError = $true
            Send-TeamsMessage -Message "VM $($_.Name) failed to start: $_"
        }
    }
}else{
    Send-TeamsMessage -Message "No previous VMs State found, not starting any VMs."
}
 
if(!$lError){
    Send-TeamsMessage -Message "Finished Patching - VMs have been started up"
}else{
    Send-TeamsMessage -Message "ERROR - VM startup failed, please review above errors!"
    exit 1;
}
exit 0;