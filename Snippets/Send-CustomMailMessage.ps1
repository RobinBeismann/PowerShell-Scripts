#Implements mosts of the Parameters Send-MailMessage has, however allows to send anonymously instead of using the current kerberos session as the normal Send-MailMessage Cmdlet does.
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
