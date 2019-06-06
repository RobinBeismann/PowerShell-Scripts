function Show-TSBlockingMessage(){
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]$Title = "Information",
        [Parameter(Mandatory=$true)]$Message,
        [Parameter(Mandatory=$false)]$Timeout = 0
    )

    #Check if we're running inside a task sequence
    $IsTSEnv = $false
    try{
        New-Object -ComObject 'Microsoft.SMS.TSEnvironment' -ErrorAction 'Stop'
        $IsTSEnv = $true
    }catch{}

    #Check if we have to hide the progress UI as we would spawn in the background otherwise
    if(
        $IsTSEnv -and
        !$script:tsProgressUIClosed -and 
        ($progressUI = New-Object -ComObject Microsoft.SMS.TsProgressUI)
    ){                
        $progressUI = $progressUI.CloseProgressDialog()
        $script:tsProgressUIClosed = $true          
    }

    #Create the message
    $shellObj = New-Object -ComObject wscript.shell
    $shellObj.Popup($message,$timeout,$title,0x0) | Out-Null

}
