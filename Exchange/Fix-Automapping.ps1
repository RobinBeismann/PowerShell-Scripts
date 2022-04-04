#Load Modules
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;
Import-Module ActiveDirectory

#Define the mailbox
$mailbox = "mailboxIdentifier"

#Retrieve the mailbox from Exchange
$mailbox = Get-Mailbox -Identity $mailbox

#Build a list of SIDs which have fullaccess on this mailbox
$sids = $mailbox | Get-MailboxPermission | Where-Object { $_.AccessRights -eq "FullAccess" } | Select-Object -ExpandProperty User | Select-Object -ExpandProperty SecurityIdentifier | Select-Object -ExpandProperty Value

#Get ADObject for the Mailbox
$mailboxDN = $mailbox.DistinguishedName
$adObject = Get-ADUser -Filter { distinguishedName -eq $mailboxDN } -Properties msExchDelegateListLink

#Get all DNs for the SIDs
$DNs = Get-ADUser -Filter * -Properties objectSID,distinguishedName | Where-Object { $sids.Contains($_.objectSID) -or $sids.Contains($_.msExchMasterAccountSid) } | Select-Object -ExpandProperty distinguishedName

#Check if there are unwanted Automap Links
$adObject.msExchDelegateListLink | % {
    if(!($DNs.Contains($_))){
        Write-Host("$($mailbox.Name): Removing $_ from Automapping list")
        $adObject | Set-ADUser -Remove @{ msExchDelegateListLink = "$_" }
    }
}

#Check if there are automap links missing
$DNs | % {
    if(!($adObject.msExchDelegateListLink.Contains($_))){
        Write-Host("$($mailbox.Name): Adding $_ to Automapping list")
        $adObject | Set-ADUser -Add @{ msExchDelegateListLink = "$_" }
    }
}
