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

Start-Sleep -Seconds 90
try{
    $messageLogged = $false
    1..5 | ForEach-Object {
        if(!(Get-Service -Name "ClusSvc" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" })){
            Write-Host("Run: $_ - ClusSvc not running - starting..")
            Start-Service -Name "ClusSvc" -ErrorAction SilentlyContinue
            Write-Host("Run: $_ - ClusSvc not running - started - waiting 30 Seconds..")
            Start-Sleep -Seconds 30
            Write-Host("Run: $_ - ClusSvc checking again..")
        }else{
            if(!$messageLogged){
                Write-Host("Run: $_ - ClusSvc already running.")
                Start-Sleep -Seconds 30
                $messageLogged = $true
            }
        }
    }

    if(Get-ClusterNode -Name $env:COMPUTERNAME | Where-Object { $_.State -ne "Up" }){
        Resume-ClusterNode -Name $env:COMPUTERNAME -Failback NoFailback -ErrorAction Stop

        # Send Teams Message
        Send-TeamsMessage -Message "Host Role Giveback successful."

    }else{
        # Send Teams Message    
        Send-TeamsMessage -Message "Host Role Giveback not required, Node not paused."
    }

    exit 0;
}catch{
    Write-Host("Failed to resume.")
    
    # Send Teams Message 
    Send-TeamsMessage -Message "Host Role Giveback failed: $_"
        
    # Resume Cluster Node
    Resume-ClusterNode -Name $env:COMPUTERNAME -Failback NoFailback
    exit 1;
}
