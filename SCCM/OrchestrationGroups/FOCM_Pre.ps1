function Send-TeamsMessage($Message){
    $connectorUri = "https://outlook.office.com/webhookurl"
    
    $fallbackMailRecipient = "<fallbackemail>"
    $fallbackMailSender = $env:Computername + "@contoso.com"
    $fallbackMailSmtp = "rh.contoso.com"
    $fallbackMailSubject = "Cluster Patching - $env:Computername"

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
     
    try{
        Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body ($body | ConvertTo-Json -Depth 5) -Uri $connectorUri
    }catch{
        # Teams hook not working, fall back to email..
        Write-Host("Failed to invoke Teams Hook, sending email..")
        Send-MailMessage -SmtpServer $fallbackMailSmtp -To $fallbackMailRecipient -Subject $fallbackMailSubject -BodyAsHtml $Message -From $fallbackMailSender
    }
}
 
try{
    $counter = 0
    $remainingRolesCount = 1

    # Send Teams Message
    Send-TeamsMessage -Message "Host Role Evacuation started."

    # Suspend Cluster Node
    Suspend-ClusterNode -Name $env:COMPUTERNAME
 
    Get-ClusterSharedVolume | Where-Object { $_.OwnerNode -eq $env:COMPUTERNAME } | ForEach-Object {
        Write-Host("Moving CSV $($_.Name) off current host")
        $_ | Move-ClusterSharedVolume
    }

    do{
        Get-ClusterGroup | Where-Object { $_.OwnerNode -eq $env:COMPUTERNAME -and $_.State -ne "Offline" } | ForEach-Object {
            if($_.GroupType -eq "VirtualMachine"){
                Write-Host("Moving VM $($_.Name) off current host")
                $_ | Move-ClusterVirtualMachineRole -MigrationType Live -ErrorAction SilentlyContinue -Wait 0
            }else{
                Write-Host("Moving Non-VM $($_.Name) off current host")
                $_ | Move-ClusterGroup -ErrorAction SilentlyContinue
            }
        }
        
        $remainingRoles = Get-ClusterGroup | Where-Object { $_.OwnerNode -eq $env:COMPUTERNAME -and $_.State -ne "Offline" } 
        $remainingRolesCount = $remainingRoles.Count
        if($remainingRolesCount -gt 0){
        Write-Host("Node not empty (Running Roles: $($remainingRoles.Name -join ", ")), sleeping 60 seconds..")
            Start-Sleep -Seconds 60
            $counter = $counter + 1
        }     
    }while(
        ($counter -le 31) -and
        $remainingRolesCount -ne 0
    )
 
    if($remainingRolesCount -gt 0){
        Write-Error -Message "Roles failed to evacuate after 30 Minutes." -ErrorAction Stop
    }else{
        Write-Host("Evacuation successful, returning success.")
    }
    Send-TeamsMessage -Message "Host Role Evacuation successful."
    exit 0;
}catch{
    Write-Host("Failed to drain roles on $env:COMPUTERNAME, resuming.")

    # Send Teams Message
    Send-TeamsMessage -Message "Host Role Evacuation error: $_"

    # Resume Cluster Node
    Resume-ClusterNode -Name $env:COMPUTERNAME -Failback NoFailback -ErrorAction SilentlyContinue
    exit 1;
}
