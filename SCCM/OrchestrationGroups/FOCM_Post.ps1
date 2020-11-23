# Example Script for Failover Cluster Patching with Orchestration Groups (Post-Script)
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
    Resume-ClusterNode -Name $env:COMPUTERNAME -ErrorAction Stop
    Send-TeamsMessage -Message "Host Role Giveback successful."
    exit 0;
}catch{
    Write-Host("Failed to resume.")
    Send-TeamsMessage -Message "Host Role Giveback failed: $_"
    Resume-ClusterNode -Name $env:COMPUTERNAME
    exit 1;
}