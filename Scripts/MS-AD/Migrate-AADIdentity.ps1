#Thanks to Praveen Kumar Ethiraj for this function (http://gallery.technet.microsoft.com/office/Covert-DirSyncMS-Online-5f3563b1/description)
function Convert-GUIDtoImmutableID{
    param([string]$valuetoconvert)

    function isGUID ($data) {
        try {
            $guid = [GUID]$data
            return 1
        } catch {
            #$notguid = 1
            return 0
        }
    }
    function isBase64 ($data) {
        try {
            $decodedII = [system.convert]::frombase64string($data)
            return 1
        } catch {
            return 0
        }
    }
    function displayhelp  {
        write-host "Please Supply the value you want converted"
        write-host "Examples:"
        write-host "To convert a GUID to an Immutable ID: GUID2ImmutableID.ps1 '748b2d72-706b-42f8-8b25-82fd8733860f'"
        write-host "To convert an ImmutableID to a GUID: GUID2ImmutableID.ps1 'ci2LdGtw+EKLJYL9hzOGDw=='"
        }

    if ($valuetoconvert -eq $NULL) {
        DisplayHelp
        return
    }
    if (isGUID($valuetoconvert))
    {
        $guid = [GUID]$valuetoconvert
        $bytearray = $guid.tobytearray()
        $immutableID = [system.convert]::ToBase64String($bytearray)
        return $immutableID
    } elseif (isBase64($valuetoconvert)){
        $decodedII = [system.convert]::frombase64string($valuetoconvert)
        if (isGUID($decodedII)) {
            $decode = [GUID]$decodedii
            $decode
        } else {
            Write-Host "Value provided not in GUID or ImmutableID format."
            DisplayHelp
        }
    } else {
        Write-Host "Value provided not in GUID or ImmutableID format."
        DisplayHelp
    }
}

#Thanks to whoever wrote this snippet, I've picked it up in the technet, however the original author wasn't mentioned
function Test-Port($hostname, $port){
    # This works no matter in which form we get $host - hostname or ip address
    try {
        $ip = [System.Net.Dns]::GetHostAddresses($hostname) | 
            select-object IPAddressToString -expandproperty  IPAddressToString
        if($ip.GetType().Name -eq "Object[]")
        {
            #If we have several ip's for that address, let's take first one
            $ip = $ip[0]
        }
    } catch {
        Write-Host "Possibly $hostname is wrong hostname or IP"
        return
    }
    $t = New-Object Net.Sockets.TcpClient
    # We use Try\Catch to remove exception info from console if we can't connect
    try
    {
        $t.Connect($ip,$port)
    } catch {}

    if($t.Connected)
    {
        $t.Close()
        return $true
    }
    else
    {
        return $false                              
    }
}

#Finds a eligeable DC for ActiveDirectory Webservices
function Get-ActiveDirectoryWebservices($domainDNSName){

    [System.Collections.ArrayList]$eligeableDCs = @()

    try{
        #Resolve the Domains DNS Root name
        Resolve-DnsName -Name $domainDNSName | Where-Object {
            #Test all DCs for Active Directory webservices
            if(!$ADWSDC -and ($result = (Test-Port -hostname $_.IPAddress -port 9389) )){
               Write-Verbose("Get-ActiveDirectoryWebservices: DC $($_.IPAddress) responded to ADWS for Domain $domainDNSName")
               #Ping all of them and add them to the eligeable DC Array
               if($ping = (Test-Connection -Count 1 -ComputerName $_.IPAddress | Select-Object -ExpandProperty ResponseTime)){
                    Write-Verbose("Get-ActiveDirectoryWebservices: DC $($_.IPAddress) responded to PING ($ping ms) for Domain $domainDNSName")
                    $DC = New-Object -TypeName PSobject
                    $DC | Add-Member -Name Address -MemberType NoteProperty -Value $_.IPAddress
                    $DC | Add-Member -Name Ping -MemberType NoteProperty -Value $ping
                                
                    Write-Verbose("Get-ActiveDirectoryWebservices: DC $($_.IPAddress) added to array.")
                    $eligeableDCs.Add($DC)                
               }
            }
        } | Out-Null
    }catch{
        Write-Verbose("Get-ActiveDirectoryWebservices: Error on ADWS DC Detection: $_")
    }

    #Check if all values are valid and return the address of the fastest DC for this domain
    if(
        $eligeableDCs -and
        ($sortedDCs = $eligeableDCs | Sort-Object -Property Ping) -and
        ($finalDC = $sortedDCs | Select-Object -First 1)
    ){
        Write-Verbose("Get-ActiveDirectoryWebservices: Returning DC $($finalDC.Address) for Domain $domainDNSName")
        return $finalDC.Address
    }else{
        return $false
    }
}

#Moves the AAD Identity
function Move-AADIdentity(){

    param(
            [string]$sourceUPN,
            [string]$sourceDomain,
            [string]$destUPN,
            [string]$destDomain,
            [string]$destADOU,
            [string]$AADConnectServer
          )
          
    $sourceDC = Get-ActiveDirectoryWebservices -domainDNSName $sourceDomain
    $destDC = Get-ActiveDirectoryWebservices -domainDNSName $destDomain

    if(!$sourceDC){
        Write-Verbose("Move-AADIdentity: Could not find Source DC for $sourceDomain")
        break;        
    }

    if(!$destDC){
        Write-Verbose("Move-AADIdentity: Could not find Dest DC for $destDomain")
        break;        
    }

    if($AADUser = Get-MsolUser -UserPrincipalName $sourceUPN -ErrorAction SilentlyContinue){
        Write-Verbose("Move-AADIdentity: Found AAD User with UPN $sourceUPN")
    
        if(!($destADUser = Get-ADUser -Filter { userPrincipalName -eq $destUPN } -Server $destDC)){
            Write-Verbose("Move-AADIdentity: Could not find dest AD User for $destUPN on $destDC")
            break;
        }else{
            Write-Verbose("Move-AADIdentity: Setting Destination AD Users mS-DS-ConsistencyGUID to its ObjectGUID")
            $destADUser | Set-ADObject -Replace @{'mS-DS-ConsistencyGuid'=$destADUser.ObjectGUID} 
        }

        if(!($sourceADUser = Get-ADUser -Filter { userPrincipalName -eq $sourceUPN } -Server $sourceDC)){
            Write-Verbose("Move-AADIdentity: Could not find source AD User for $sourceUPN on $sourceDC")
            break;
        }

        if($baseDomain = Get-MsolCompanyInformation | Select-Object -ExpandProperty InitialDomain){
            if($sourceUPNSuffix = $sourceUPN.Split("@")[1]){
                Write-Verbose("Move-AADIdentity: UPN Suffix for $sourceUPN is $sourceUPNSuffix")
                $tempUPN = $sourceUPN.Replace($sourceUPNSuffix,$baseDomain)
                Write-Verbose("Move-AADIdentity: Temporary UPN will be $tempUPN")
                if(!(Get-MsolUser -UserPrincipalName $tempUPN -ErrorAction SilentlyContinue) -and !(Get-MsolUser -ReturnDeletedUsers -UserPrincipalName $tempUPN -ErrorAction SilentlyContinue)){
                    if($usersContainer = Get-ADDomain -Server $sourceDC | Select-Object -ExpandProperty 'UsersContainer'){
                        #Try to move source user
                        $moved = $false
                        $restored = $false
                        $UPNChange = $false
                        $anchorChanged = $false

						#Move source user out of AAD synched OU
                        try{
                            $sourceADUser | Move-ADObject -Server $sourceDC -TargetPath $usersContainer -ErrorAction Stop
                            $moved = $true
                        }catch{
                            Write-Verbose("Move-AADIdentity: Could not move Source AD User into $usersContainer")
                        }

                        if($moved){
							#Start AAD Delta Sync
                            try{
                                Invoke-Command -ComputerName $AADConnectServer -ScriptBlock {
                                    Start-ADSyncSyncCycle -PolicyType Delta
                                } -ErrorAction Stop
                            }catch{
                                Write-Verbose("Move-AADIdentity: Could not force start AAD Sync, this might delay the process until the next scheduled sync runs")
                            }
							
							#Wait for the source user to appear in AAD Recycle Bin
                            while(!(Get-MsolUser -UserPrincipalName $sourceUPN -ReturnDeletedUsers -ErrorAction SilentlyContinue)){
                                Write-Verbose("Move-AADIdentity: Waiting for $sourceUPN to appear in AAD Recycle Bin")
                                Start-Sleep -Seconds 1
                            }
                            Write-Verbose("Move-AADIdentity: Found Azure AD Identity $sourceUPN in AD Recycle Bin.")
                            Write-Verbose("Move-AADIdentity: Now sleeping 60 seconds and allow azure to replicate")
                            Start-Sleep -Seconds 60

							#Restore AAD User
                            try{
                                Get-MsolUser -ReturnDeletedUsers -UserPrincipalName $sourceUPN | Restore-MsolUser -ErrorAction Stop
                                $restored = $true
                            }catch{
                                Write-Verbose("Move-AADIdentity: Error: Could not restore AAD User with UPN $sourceUPN, please review manually!")
                            }
							
							#Set temporary UPN so we can clear the immutableID
                            if($restored){
                                Write-Verbose("Move-AADIdentity: Changing UPN from $sourceUPN to $tempUPN")
                                Set-MsolUserPrincipalName -UserPrincipalName $sourceUPN -NewUserPrincipalName $tempUPN
                                try{
                                    Write-Verbose("Move-AADIdentity: Sleeping 10 Seconds then changing immutableID to $value")
                                    $value = Convert-GUIDtoImmutableID -valuetoconvert $destADUser.ObjectGUID
                                    Get-MsolUser -UserPrincipalName $tempUPN | Set-MsolUser -ImmutableId $value -ErrorAction Stop
                                    $anchorChanged = $true
                                }catch{
                                    Write-Verbose("Move-AADIdentity: Error: Unable to change immutableid for AAD User $tempUPN to $value, please correct manually!")
                                }
								
								#Set ImmutableID to the new users immutableID
                                if($anchorChanged){
                                    try{
                                        Write-Verbose("Move-AADIdentity: Changing UPN $tempUPN to $destUPN")
                                        Set-MsolUserPrincipalName -UserPrincipalName $tempUPN -NewUserPrincipalName $destUPN -ErrorAction Stop
                                        $UPNChange = $true
                                    }catch{
                                        Write-Verbose("Move-AADIdentity: Error: UPN changing failed, changing back to $sourceUPN")
                                        Set-MsolUserPrincipalName -UserPrincipalName $tempUPN -NewUserPrincipalName $sourceUPN
                                    }
                                }
                            }

							#Start another AAD Delta Sync
                            if($UPNChange){
                                try{
                                    $destADUser | Move-ADObject -Server $destDC -TargetPath $destADOU -ErrorAction Stop
                                    try{
                                        Invoke-Command -ComputerName $AADConnectServer -ScriptBlock {
                                            Start-ADSyncSyncCycle -PolicyType Delta
                                        } -ErrorAction Stop
                                    }catch{
                                        Write-Verbose("Move-AADIdentity: Could not force start AAD Sync, this might delay the process until the next scheduled sync runs")
                                    }
                                }catch{
                                    Write-Verbose("Move-AADIdentity: Error: Failed to move $destUPN to $destADOU on $destDC")
                                }
                            }
                        }
                    }else{
                        Write-Verbose("Move-AADIdentity: Error: Could not find user container on $sourceDC")
                    }
                }else{
                    Write-Verbose("Move-AADIdentity: Error: Temp UPN is already is use!")
                }
            }        
        }else{
            Write-Verbose("Move-AADIdentity: Could not retrieve initial domain (.onmicrosoft.com)")
        }


    }else{
        Write-Verbose("Move-AADIdentity: Couldn't find AAD User with UPN $sourceUPN")
    }
}


$VerbosePreference="Continue"

