#Removes SIP Addresses from Linked Mailboxes
Get-ADUser -Filter * -Properties msExchMasterAccountSid, proxyAddresses | ForEach-Object {
    if($_.msExchMasterAccountSid){
        [array]$proxyAddresses = $_.proxyAddresses | Where-Object { !($_.StartsWith("SIP:")) -and !($_.StartsWith("sip:")) }
        [array]$newProxyAddresses = @()
        $proxyAddresses | % {
            [array]$newProxyAddresses += @( ([string]$_) )
        }
         $_ | Set-ADUser -Replace @{ ProxyAddresses = $newProxyAddresses }
    }
}
