function Get-MailboxHashtable(){
    [CmdletBinding()]
    Param(
        $Identity
    )
    try{
        $mailbox = Get-EXOMailbox -Identity $user
    }catch{}
    
    if(!$mailbox){
        try{
            $mailbox = Get-Mailbox -Identity $user
        }catch{}
    }
    if(!($mailbox)){
        return $false
    }else{
        $mailboxObj = @{}
        $mailbox.PSObject.Members | ForEach-Object {
            $mailboxObj.$($_.Name) = $($_.Value)
        }
        return $mailboxObj
    }

}

function Compare-Hashtable(){
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]$Object,
        $ReferenceObject
    )
    $arr = @()
    $Object.GetEnumerator() | Foreach-Object {
        $val = $ReferenceObject.$($_.Name)
        if(
            ($val -and !$_.Value) -or
            (!$val -and $_.Value) -or
            ($val -ne $_.Value)     
        ){
            $arr += [PSCustomObject]@{
                Name = $_.Name
                Object = $_.Value
                Reference = $val
            }
        }
    }
    return ($arr | Sort-Object -Property Name)
}

$source = Get-MailboxHashtable -Identity ""
$dest = Get-MailboxHashtable -Identity ""

$source | Compare-Hashtable -ReferenceObject $dest | Out-GridView
