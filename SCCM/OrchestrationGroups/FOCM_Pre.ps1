# Example Script for Failover Cluster Patching with Orchestration Groups (Pre-Script)
# You will either need to replace the Send-TeamsMessage Function or atleast fill it up with your webhook under $connectorUri

function Send-TeamsMessage($Message){
    $connectorUri = "https://outlook.office.com/webhook/"
    $body = [ordered]@{
        "@type" = "MessageCard"
        "summary" = "Cluster Patching is running on $env:Computername"
        "themeColor" = $(
            if($Message.ToLower().Contains("error")){
                "#eb4034"
            }else{
                "#a6a6a6"
            }
        )
        "sections" = @(
            @{
                activityTitle = "Cluster Patching"
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
     
    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body ($body | ConvertTo-Json -Depth 5) -Uri $connectorUri
}
 
try{
    $counter = 0
    $remainingRolesCount = 1
    Suspend-ClusterNode -Name $env:COMPUTERNAME -Drain
 
    while(
        ($counter -lt 60) -and
        $remainingRolesCount -ne 0
    ){
        $remainingRoles = Get-ClusterResource | Where-Object { $_.OwnerNode -eq $env:COMPUTERNAME }
        $remainingRolesCount = $remainingRoles.Count
        Write-Host("Node not empty (Running Roles: $($remainingRoles.Name -join ", ")), sleeping 60 seconds..")
        Start-Sleep -Seconds 15
        $counter = $counter + 1
    }
 
    if($remainingRolesCount -gt 0){
        Write-Error -Message "Roles failed to evacuate after 15 Minutes." -ErrorAction Stop
    }else{
        Write-Host("Evacuation successful, returning success.")
    }
    Send-TeamsMessage -Message "Host Role Evacuation successful."
    exit 0;
}catch{
    Write-Host("Failed to drain roles on $env:COMPUTERNAME, resuming.")
    Send-TeamsMessage -Message "Host Role Evacuation error: $_"
    Resume-ClusterNode -Name $env:COMPUTERNAME -Failback Policy -ErrorAction SilentlyContinue
    exit 1;
}