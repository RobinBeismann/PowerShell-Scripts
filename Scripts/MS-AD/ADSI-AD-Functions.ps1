function Get-ADObject{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply object DN')][string]$ObjectDN
  )
  return ([adsi]"LDAP://$ObjectDN")
}

function Get-ADObjects{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply object class')][string]$class,
    [Parameter(Mandatory=$true,HelpMessage='Supply the domain DNS name')][string]$domainName,
    [string]$optionalFilter
  )
  $domainContext = New-Object -TypeName System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList ('Domain', $domainName)
  $domain = [DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
  $root = $domain.GetDirectoryEntry()
  $ds = [adsisearcher]$root
  $ds.Filter = "(&(objectCategory=$class)$optionalFilter)"

  return $ds.FindAll()
}

function Get-ADObjectsAcrossTrust{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply object class')][string]$class,
    [string]$optionalFilter
  )
  $objects = @()

  $domainNames = @()

  (Get-TrustedDomainsByNetBIOS).GetEnumerator() | ForEach-Object { 
    $domainNames += $_.Value.Properties.name
  }
  $domainNames += $env:USERDNSDOMAIN

  $domainNames | ForEach-Object {
    $domainName = $_
    $domainContext = New-Object -TypeName System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList ('Domain', $domainName)
    $domain = [DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
    $root = $domain.GetDirectoryEntry()
    $ds = [adsisearcher]$root
    $ds.Filter = "(&(objectCategory=$class)(!(msExchMasterAccountSid=*))$optionalfilter)"
    $null = $ds.PropertiesToLoad.Add('name')
    $null = $ds.PropertiesToLoad.Add('displayname')
    $null = $ds.PropertiesToLoad.Add('description')
    $null = $ds.PropertiesToLoad.Add('distinguishedname')
    $null = $ds.PropertiesToLoad.Add('samaccountname')
    $null = $ds.PropertiesToLoad.Add('userprincipalname')
    $null = $ds.PropertiesToLoad.Add('mail')
    $null = $ds.PropertiesToLoad.Add('memberof')
    $null = $ds.PropertiesToLoad.Add('member')
    $null = $ds.PropertiesToLoad.Add('title')
    $null = $ds.PropertiesToLoad.Add('cn')
    $null = $ds.PropertiesToLoad.Add('objectSid')

    $ds.PageSize = 20000

    $ds.FindAll().GetEnumerator() | ForEach-Object {
      $_.Properties.NETBIOSName = $domainName
      $objects += $_
    }
  }
    

  return $objects
}

function Get-GroupMember{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN
  )
  return ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
}

function Get-GroupMemberAcrossTrust{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN
  )
  $pattern = '^CN=(.*?),.*$'

  $members = ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
  $members | ForEach-Object {
    if( $_.Contains('CN=ForeignSecurityPrincipals') ){          
      $result = [regex]::Match($_,$pattern)
               
      Get-ADObjectByNetBIOS -path (Resolve-Sid -sid $result.Groups[1].Value)
    }else{
      $_
    }
  }
}

function Get-GroupMemberByNetBIOS{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN
  )
  $pattern = '^CN=(.*?),.*$'

  $members = ([adsi]"LDAP://$GroupDN") | Select-Object -ExpandProperty member
  $members | ForEach-Object {
    if( $_.Contains('CN=ForeignSecurityPrincipals') ){          
      $result = [regex]::Match($_,$pattern)
      Write-Host(Resolve-Sid -sid $result.Groups[0])    
    }else{
      $obj = (Get-ADObject -ObjectDN $_) | Select-Object -Property SchemaClassName, sAMAccountName
      if($obj.SchemaClassName -ne 'group'){
        ($env:USERDOMAIN + '\' + $obj.sAMAccountName[0])
      }else{
        ('+' + $env:USERDOMAIN + '\' + $obj.sAMAccountName[0])
      }
    }
  }
}

function Get-ADObjectByNetBIOS{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the AD Objects NetBIOS Path')][string]$path
  )
  $Split = $path.Split('\')
  $Domain = $Split[0]
  $User = $Split[1]

  (Get-TrustedDomainsByNetBIOS).GetEnumerator() | ForEach-Object {    
    $ds = [adsisearcher]$_.Value
    $ds.Filter = "(&(sAMAccountName=$User))"
    $null = $ds.PropertiesToLoad.Add('name')
    $null = $ds.PropertiesToLoad.Add('displayname')
    $null = $ds.PropertiesToLoad.Add('description')
    $null = $ds.PropertiesToLoad.Add('distinguishedname')
    $null = $ds.PropertiesToLoad.Add('samaccountname')
    $null = $ds.PropertiesToLoad.Add('userprincipalname')
    $null = $ds.PropertiesToLoad.Add('mail')
    $null = $ds.PropertiesToLoad.Add('memberof')
    $null = $ds.PropertiesToLoad.Add('member')
    $null = $ds.PropertiesToLoad.Add('title')
    $null = $ds.PropertiesToLoad.Add('cn')
    $ds.PageSize = 20000

    $ds.FindOne() | ForEach-Object {
      return $_.Properties.distinguishedname
    }
  }
}

function Add-GroupMemberBySid{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN,
    [Parameter(Mandatory=$true,HelpMessage='Supply the SID of the object to add')][object]$MemberSid
  )
  $sid = $MemberSid | Select-Object
  $hexString = ($sid | ForEach-Object { $_.ToString('X2') }) -join ''

  $group = [adsi]"LDAP://$GroupDN"
  return $group.Add("LDAP://<SID=$hexString>")
}

function Remove-GroupMemberBySid{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN,

    [Parameter(Mandatory=$true,HelpMessage='Supply the SID of the object to remove')][object]$MemberSid
  )
  $sid = $MemberSid | Select-Object
  $hexString = ($sid | ForEach-Object { $_.ToString('X2') }) -join ''

  $group = [adsi]"LDAP://$GroupDN"
  return $group.Remove("LDAP://<SID=$hexString>")
}

function Add-GroupMember{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN,
    [Parameter(Mandatory=$true,HelpMessage='Supply the DN of the object to add')][string]$MemberDN
  )
  $group = [adsi]"LDAP://$GroupDN"
  $user = [adsi]"LDAP://$MemberDN"
  return $group.Add($User.path)
}

function Remove-GroupMember{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the groups distinguishedName')][string]$GroupDN,
    [Parameter(Mandatory=$true,HelpMessage='Supply the DN of the object to remove')][string]$MemberDN
  )
  $group = [adsi]"LDAP://$GroupDN"
  $user = [adsi]"LDAP://$MemberDN"
  return $group.Remove($User.path)
}

function Resolve-Sid{    
  param
  (
    [Parameter(Mandatory=$true,HelpMessage='Supply the SID of the object to resolve')][string]$sid
  )
  try{
    return (New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList ($sid)).Translate([Security.Principal.NTAccount]).Value
  }catch{
    return $false
  }
}

function Get-TrustedDomainsByNetBIOS(){

  $returnArray = @{}
    
  $searcher=[ADSIsearcher]'(objectclass=trustedDomain)'
  $searcher.searchroot.Path="LDAP://$($env:USERDNSDOMAIN)"
        
  $searcher.FindAll() | ForEach-Object {
    $domainContext = New-Object -TypeName System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList ('Domain', $_.Properties.name)
    $domain = [DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)
    $returnArray[($_.Properties.flatname[0])] = $domain.GetDirectoryEntry()
  }
    
  $returnArray[$env:USERDOMAIN] = [ADSI]"LDAP://$($env:USERDNSDOMAIN)"
   
  return $returnArray 
}

function Get-ADTrustedObjectsByDN(){
  $groups = Get-ADObjectsAcrossTrust -class 'group'
  $users = Get-ADObjectsAcrossTrust -class 'user' 

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
