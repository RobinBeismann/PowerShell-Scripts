<#----------------------------------------------------------------------------------------------------------------------------
February 2017 - Robin Beismann
Figure out on which DC a user was locked, grap its' eventlog and generate a report with failed logins for that user
----------------------------------------------------------------------------------------------------------------------------#>

############################################### Adjust the following Variables ###############################################
$username = Read-Host("Please enter the sAMAccountName of the locked user")
$daysBackward = 1
$exportFile = "export.csv"
$exportDelimiter = ";"

############################################### Do not modify below ##########################################################
#Check if the user even exists
if($dn = (Get-ADUser -Filter {sAMAccountName -eq $username} ).DistinguishedName){
    #We're using this DN to Query the Replication Metadata
    Write-Host("Using DN: " + $dn)
    
    #Figure out, where this user was locked; Thanks @Brandon Shell for pointing out how to do this on Server 2008
    $context = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain",$env:USERDOMAIN)
    $dc = [System.DirectoryServices.ActiveDirectory.DomainController]::findOne($context)
    $meta = $dc.GetReplicationMetadata($dn)
    $lastLockedDC = $meta.lockouttime.OriginatingServer

    #So there we got our DC
    Write-Host("Figured out that $username was last locked on $lastLockedDC, gathering event log now.")
    
    #Start gathering the DCs Eventlog and search for EventID 4771 (Kerberos Preauthentication failed)
    $events = @()
    Get-EventLog -ComputerName $lastLockedDC -LogName Security -EntryType FailureAudit | Where-Object { $_.EventID -eq "4771" } |
    ForEach-Object {
        #This looks dirty in the first place but is a way better (and faster) then the -After Parameter, as the original parameter doesn't stop after reaching the date but keeps going until it reachs the end of the log.
        $events += $_
        if ($_.TimeGenerated.CompareTo( (Get-Date).AddDays(-$daysBackward) ) -lt 1) { return }
    } 

    Write-Host("Got eventlog, now starting to process it.")

    $failedLogins = @()
    foreach($event in $events){
        if($event.ReplacementStrings[0] -eq $username){
            $IP = $event.ReplacementStrings[6]
            #Strip the pseudo IPv6 Part out of it
            $IP = $IP.Replace("::ffff:","")

            #Do a reverse dns lookup for the hostname
            $hostname = [System.Net.Dns]::GetHostByAddress($IP).HostName
            
            #Build a report object
            $Object = New-Object PSObject                                  
            $Object | Add-Member Noteproperty Time (Get-Date $event.TimeGenerated -Format "s")           
            $Object | Add-Member Noteproperty Username $username                 
            $Object | Add-Member Noteproperty Hostname $hostname                 
            $Object | Add-Member Noteproperty IP $IP
            
            #Add the object to the failed login array
            $failedLogins += $Object 
        }

    }

    #Export it
    $failedLogins | Export-Csv -Path $exportFile -Delimiter $exportDelimiter -NoTypeInformation
    
}else{
    Write-Host("User not found.")
}

