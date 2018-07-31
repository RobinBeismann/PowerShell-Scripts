function Get-ADObject($ObjectDN){
    return ([adsi]"LDAP://$ObjectDN")
}

function Get-ADObjects($class,$domainName){
    $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domainName)
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
    $root = $domain.GetDirectoryEntry()
    $ds = [adsisearcher]$root
    $ds.Filter = "(&(objectCategory=$class))"

    return $ds.FindAll()
}

function Get-ADObjectsAcrossTrust($class,$optionalFilter){
    $objects = @()

    $domainNames = @()

    (Get-TrustedDomainsByNetBIOS).GetEnumerator() | ForEach-Object { 
        $domainNames += $_.Value.Properties.name
    }
    $domainNames += $env:USERDNSDOMAIN

    $domainNames | ForEach-Object {
        $domainName = $_
        $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domainName)
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
        $root = $domain.GetDirectoryEntry()
        $ds = [adsisearcher]$root
        $ds.Filter = "(&(objectCategory=$class)(!(msExchMasterAccountSid=*))$optionalfilter)"
        $ds.PropertiesToLoad.Add("name") | Out-Null
        $ds.PropertiesToLoad.Add("displayname") | Out-Null
        $ds.PropertiesToLoad.Add("description") | Out-Null
        $ds.PropertiesToLoad.Add("distinguishedname") | Out-Null
        $ds.PropertiesToLoad.Add("samaccountname") | Out-Null
        $ds.PropertiesToLoad.Add("userprincipalname") | Out-Null
        $ds.PropertiesToLoad.Add("mail") | Out-Null
        $ds.PropertiesToLoad.Add("memberof") | Out-Null
        $ds.PropertiesToLoad.Add("member") | Out-Null
        $ds.PropertiesToLoad.Add("title") | Out-Null
        $ds.PropertiesToLoad.Add("cn") | Out-Null
        $ds.PropertiesToLoad.Add("objectSid") | Out-Null

        $ds.PageSize = 20000

        $ds.FindAll().GetEnumerator() | ForEach-Object {
            $_.Properties.NETBIOSName = $domainName
            $objects += $_
        }
    }
    

    return $objects
}

function Get-GroupMember($GroupDN){
    return ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
}

function Get-GroupMemberAcrossTrust($GroupDN){
    $pattern = "^CN=(.*?),.*$"

    $members = ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
    $members | ForEach-Object {
        if( $_.Contains("CN=ForeignSecurityPrincipals") ){          
            $result = [regex]::Match($_,$pattern)
               
            Get-ADObjectByNetBIOS -path (Resolve-Sid -sid $result.Groups[1].Value)
        }else{
            $_
        }
    }
}

function Get-GroupMemberByNetBIOS($GroupDN){
    $pattern = "^CN=(.*?),.*$"

    $members = ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
    $members | ForEach-Object {
        if( $_.Contains("CN=ForeignSecurityPrincipals") ){          
            $result = [regex]::Match($_,$pattern)
            Write-Host(Resolve-Sid -sid $result.Groups[0])    
        }else{
            $obj = (Get-ADObject -ObjectDN $_) | Select-Object -Property SchemaClassName, sAMAccountName
            if($obj.SchemaClassName -ne "group"){
                ($env:USERDOMAIN + "\" + $obj.sAMAccountName[0])
            }else{
                ("+" + $env:USERDOMAIN + "\" + $obj.sAMAccountName[0])
            }
        }
    }
}

function Get-ADObjectByNetBIOS($path){
    $Split = $path.Split("\")
    $Domain = $Split[0]
    $User = $Split[1]


    (Get-TrustedDomainsByNetBIOS).GetEnumerator() | ForEach-Object {
    
        $ds = [adsisearcher]$_.Value
        $ds.Filter = "(&(sAMAccountName=$User)(!(msExchMasterAccountSid=*)))"
        $ds.PropertiesToLoad.Add("name") | Out-Null
        $ds.PropertiesToLoad.Add("displayname") | Out-Null
        $ds.PropertiesToLoad.Add("description") | Out-Null
        $ds.PropertiesToLoad.Add("distinguishedname") | Out-Null
        $ds.PropertiesToLoad.Add("samaccountname") | Out-Null
        $ds.PropertiesToLoad.Add("userprincipalname") | Out-Null
        $ds.PropertiesToLoad.Add("mail") | Out-Null
        $ds.PropertiesToLoad.Add("memberof") | Out-Null
        $ds.PropertiesToLoad.Add("member") | Out-Null
        $ds.PropertiesToLoad.Add("title") | Out-Null
        $ds.PropertiesToLoad.Add("cn") | Out-Null
        $ds.PageSize = 20000

        $ds.FindOne() | ForEach-Object {
            return $_.Properties.distinguishedname
        }
    }
}

function Add-GroupMemberBySid($GroupDN,$MemberSid){
    $sid = $MemberSid | Select-Object
    $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid,0)
    $hexString = ($sid|ForEach-Object ToString X2) -join ''

    $group = [adsi]"LDAP://CN=S-SHA-DFS-Transfer-SEL_Finance-RW,OU=DFS Permission Groups,OU=SHA,OU=Groups,OU=COTN,DC=cotn,DC=group"
    return $group.Add("LDAP://<SID=$hexString>")
}

function Remove-GroupMemberBySid($GroupDN,$MemberSid){
    $sid = $MemberSid | Select-Object
    $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid,0)
    $hexString = ($sid|ForEach-Object ToString X2) -join ''

    $group = [adsi]"LDAP://CN=S-SHA-DFS-Transfer-SEL_Finance-RW,OU=DFS Permission Groups,OU=SHA,OU=Groups,OU=COTN,DC=cotn,DC=group"
    return $group.Remove("LDAP://<SID=$hexString>")
}

function Add-GroupMember($GroupDN,$MemberDN){
    $group = [adsi]"LDAP://$GroupDN"
    $user = [adsi]"LDAP://$MemberDN"
    return $group.Add($User.path)
}

function Remove-GroupMember($GroupDN,$MemberDN){
    $group = [adsi]"LDAP://$GroupDN"
    $user = [adsi]"LDAP://$MemberDN"
    return $group.Remove($User.path)
}

function Resolve-Sid($sid){
    try{
        return (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value
    }catch{
        return $false
    }
}

function Get-TrustedDomainsByNetBIOS(){

    $returnArray = @{}
    
    $searcher=[ADSIsearcher]"(objectclass=trustedDomain)"
    $searcher.searchroot.Path="LDAP://$($env:USERDNSDOMAIN)"
    
    
    $searcher.FindAll() | ForEach-Object {
        $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $_.Properties.name)
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
        $returnArray[($_.Properties.flatname[0])] = $domain.GetDirectoryEntry()
    }
    
    $returnArray[$env:USERDOMAIN] = [ADSI]"LDAP://$($env:USERDNSDOMAIN)"
   
    return $returnArray 
}

function Get-ADTrustedObjectsByDN(){
    $groups = Get-ADObjectsAcrossTrust -class "group"
    $users = Get-ADObjectsAcrossTrust -class "user" -optionalFilter "(mail=*)"

    $table = @{}

    $users | ForEach-Object {
        
        $dn = $_.Properties.distinguishedname[0]

        $table[$dn] = $_ 
    }

    $groups | ForEach-Object {
        
        $dn = $_.Properties.distinguishedname[0]

        $table[$dn] = $_ 
    }

    return $table
}
