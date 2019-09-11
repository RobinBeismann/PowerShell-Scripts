<#
Sends Mails based on Task Sequence Title, Task Sequence Step and LastActionStatus
This for example might look like:
[Success]: Task Sequence "Task Sequence Name" on RandomPCName (Step: "Status Mail: Logs uploaded")
The task sequence name, the PC Name and the Step name are retrieved from the SMS Environment

Simply embed this script into a task sequence powershell step and it will inform you as soon as it reaches the step
#>

#Load SMS TS Env
$tsenv = New-Object -ComObject 'Microsoft.SMS.TSEnvironment' -ErrorAction 'Stop'
$status = $tsenv.Value('_SMSTSLastActionSucceeded')
if($status -eq $false -or $status -eq "false"){
    $status = "Error"
}else{
    $status = "Success"
}

#region Static definitions
$smtpSender = $tsenv.Value('OSDComputerName') + "@tasksequence." + ($tsenv.Value('SMSTSMP').Split("://")[-1]) #Computername@tasksequence.ManagementPoint
$smtpRecipient = "it@consoto.com"
$smtpServer = "smtphost.contoso.com"
$smtpSubject = "[$status]: Task Sequence `"$($tsenv.Value('_SMSTSPackageName'))`" on $($tsenv.Value('OSDComputerName')) (Step: `"$($tsenv.Value('_SMSTSCurrentActionName'))`")"
$smtpBody = $smtpSubject
#endregion

#region functions
function Send-CustomMailMessage(){
    param(
        [string]$SmtpServer,
        [string]$from,
        [string]$subject,
        [array]$to,
        [string]$body,
        [switch]$BodyAsHtml,
        [array]$attachments,
        [string]$ReplyTo,
        [array]$CC
    )
    
    $message = New-Object System.Net.Mail.MailMessage
    $to | ForEach-Object {
        $message.To.Add($_)
    }

    if($CC){
        $CC | ForEach-Object {
            $message.CC.Add($_)
        }
    }
    
    $message.From = $from
    $message.Subject = $subject
    $message.Body = $body

    if($BodyAsHtml){
        $message.IsBodyHTML = $true
    }

    if($ReplyTo){
        $message.ReplyTo = $ReplyTo
    }

    if($attachments){
        $attachments | % {
            if(Test-Path -Path $_){
                $message.Attachments.Add($_)
            }else{
                Write-Error("Couldn't find attachment $_, breaking")
                break;
            }
        }
    }

    $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($message)
    
}
#endregion

Send-CustomMailMessage -SmtpServer $smtpServer -from $smtpSender -subject $smtpSubject -to $smtpRecipient -body $smtpBody
