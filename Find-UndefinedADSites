<#----------------------------------------------------------------------------------------------------------------------------
April 2017 - Robin Beismann
Gather all Domain Controllers' netlogon file and search for Clients which don't belong to any AD Site and Subnet
----------------------------------------------------------------------------------------------------------------------------#>

############################################### Adjust the following Variables ###############################################
$DomainControllerFilter = "*"
$PathOnDC = "\Windows\debug\netlogon.log" #Starting from Systemdrive

$LogFileName = "log.html"
$ExportFileName = "report.csv"
$ExportDelimiter = ";"

############################################### Do not modify below ##########################################################
#Custom Print function to enable logging
$log = ""
function Write-CustomLog([string]$text){
    Write-Host($text)
    $global:log += ($text + "<br/>")
}

#Get all Domain Controllers by Filter
$DCs = Get-ADDomainController -Filter { Name -like $DomainControllerFilter }
$noSiteByIP = @{}
$noSiteByHostname = @{}

#Loop through the DCs and start processing the log
foreach($dc in $DCs){
    Write-CustomLog("Gathering Log from " + $dc.Name)

    #Get the file and filter for lines containing "NO_CLIENT_SITE", return them into the array
    $noSite = (Get-Content ("\\$($dc.Name)\C$" + $PathOnDC)).Split('\r') | Where-Object { $_ -like "*NO_CLIENT_SITE*" }

    #Loop through the array
    Write-CustomLog("Processing Log from " + $dc.Name)
    $noSite | ForEach-Object {
        $splitObj = $_.Split(" ")
        #Access the array from behind and point out IP and Hostname
        $hostname = $splitObj[-2]
        $IP = $splitObj[-1]
        
        #Check if the split succesfully
        if(!$IP -or !$hostname){
            #Somehow your file looks different, please debug that or sent me a (censored) copy.
            Write-CustomLog("The following line could not be split successfully: " + $_)
            break;
        }

        #We're gonna use the IP as Index so we have no duplicates, however it may happen that the hostname changed due to DHCP leases or similar
        if($noSiteByIP[$IP] -and ($noSiteByIP[$IP] -ne $hostname) ){
            Write-CustomLog("Hostname for $IP changed from $($noSiteByIP[$IP]) to $hostname")
        }
                
        #We're gonna use the Hostname as Index so we have no duplicates, however it may happen that the IP changed due to DHCP leases or similar
        if($noSiteByHostname[$hostname] -and ($noSiteByHostname[$hostname] -ne $IP) ){
            Write-CustomLog("IP for $hostname changed from $($noSiteByHostname[$hostname]) to $IP")
        }

        #We've logged the changes, time to overwrite those entrys and keep going
        $noSiteByIP[$IP] = $hostname
        $noSiteByHostname[$hostname] = $IP
        
    }
    
}

#Enumerate the Results, sort them by IP Address, stripe out additional fields and export them as Csv without Type Information and the defined delimiter
$noSiteByIP.GetEnumerator() | Sort-Object -Property Name | Select-Object Name, Value | Export-Csv -NoTypeInformation $ExportFileName -Delimiter $ExportDelimiter

#Write the log to the desired log file
$log | Out-File $LogFileName -Force:$true -Confirm:$false
