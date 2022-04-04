<#----------------------------------------------------------------------------------------------------------------------------
August 2017
This script creates dummy users for MAC based Microsoft NPS Radius authentication by using MAC Addresses out of a specific
AD User Attribut containing MAC Addresses seperated by semicolas

Remember to create a fine grained password policy applied to the WLAN-Users as the password will be equal to the username.

CAUTION: THIS WILL DELETE ALL USERS OUT OF A SPECIFIC ORGANIZATIONAL UNIT IF THEY MATCH THE SCHEMA!
----------------------------------------------------------------------------------------------------------------------------#>

#Define base OU for the dummy users
$baseOU = "OU=test,OU=Testuser,<stripped>"

#This is the DN of the group to which the fine grained password policy is applied
$WLANUsersGroup = "CN=WLAN-Users,OU=test,OU=Testuser,<stripped>"

#Name of the domain users default group (depends on AD setup language)
$domainUsersGroup = "Domain Users"

#If this is set to false we're actually gonna start creating and deleting users
$dryRun = $true

#######################################################################################################################
########################################### Do not modify below #######################################################
#######################################################################################################################

#Get closest DC
$dc = (Get-ADDomainController -NextClosestSite -Discover).Name

#Initialize MAC Table
$MACTable = @{}

#Get current Dummy Users
$currentDummyUsers = Get-ADUser -SearchBase $baseOU -Filter *

#Determinate Group ID of WLAN Group, this group is used for the Fine Grained Password Policy
$group = Get-ADGroup $WLANUsersGroup
$groupSid = $group.SID
[int]$primaryGroupID  = $groupSid.Value.Substring($groupSid.Value.LastIndexOf("-")+1)

#Grab users with fitting MAC Address Attributes
Get-ADUser -Filter { personalPager -ne $false } -Properties * | ForEach-Object {

    $mac = $_.personalPager #Define MAC
    $dn = $_.distinguishedName #Define DN
    $sAMAccountName = $_.sAMAccountName #Define sAMAccountName

    if($mac.Length -ge 12){
        $mac = $mac.ToLower()
        $mac = $mac.Replace(" ",";")   #Fix space delimiter
        $mac = $mac.Replace(",",";")   #Fix "," Delimiter
        $mac = $mac.Replace(":","")    #Strip MAC Down
        $mac = $mac.Replace(";;",";")  #Replace Double Semicola
        $mac = $mac.Replace("-","")    #Strip MAC further Down

        #Remove finishing semicola
        if($mac.Substring(($mac.Length)-1) -eq ";"){
            $mac = $mac.Substring( 0,($mac.Length)-1)
        }
        
        $mac.Split(";") | ForEach-Object {
            if($_.Length -ne 12){
                Write-Host ("Found unparseable MAC Address: $dn = $mac")
            }else{
                $MACTable[$_] = $sAMAccountName
            }
        }
    }
}

#Cleanup old
foreach($user in $currentDummyUsers){

    #Check if our built MAC Table contains those addresses
    if(!$MACTable[($user.sAMAccountName)]){ 

       if( ($user.DistinguishedName).EndsWith($baseOU) -and ($user.SamAccountName.Length -eq 12) ){
            Write-Host("Removing AD User: " + $user.SamAccountName) 
            
            #Check for dry run flag
            if(!$dryRun){
                Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false
            }
        }

    }

}

#Create new devices
foreach($mac in $MACTable.GetEnumerator()){
    $macAddress = $mac.Name
    if( !(Get-ADUser -Filter {sAMAccountName -eq $macAddress} -Server $dc)){
        Write-Host("Creating $macAddress")

        #Check for dry run flag
        if(!$dryRun){
            #Encode Password
            $password = ConvertTo-SecureString -AsPlainText $macAddress -Force 

            #Create AD User
            New-ADUser -SamAccountName $macAddress -DisplayName $_.Value -name $macAddress -Path $baseOU -Enabled $false -Server $dc
        
            #Get AD User
            $user = Get-ADUser -Filter {sAMAccountName -eq $macAddress} -Server $dc -SearchBase $baseOU
        
            #Add to WLAN Group so Password Policys match
            Add-ADGroupMember -Identity $group -Members $user
        
            #Change his primary group
            $user | Set-ADUser -Replace @{PrimaryGroupID = $primaryGroupID }
        
            #Remove him from Domain Users so he looses most of his privilegues
            Remove-ADGroupMember -Identity $domainUsersGroup -Members $user -Confirm:$false
        
            #Set his Password
            $user | Set-ADAccountPassword -NewPassword $password
        
            #Finally enable the account
            $user | Enable-ADAccount
        }
    }    
}
