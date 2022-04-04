
# General AD Object Handling
### Get-ADObject()
    Parameter:
	   $ObjectDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the objects DistinguishedName
	
	Returns: An Object of Type "DirectoryEntry" with all Attributes and Properties of an AD Object

### Get-ADObjects()
    Parameter:
        $class
	        Datatype: String
	        Mandatory: True
	        Description: Supply the object class (for example "person")
		
		$domainName
	        Datatype: String
	        Mandatory: True
	        Description: Supply the domain FQDN to search in
		
		$optionalFilter:
	        Datatype: String
	        Mandatory: False
	        Description: Supply an additional LDAP Filter if needed.
	
	Returns: All objects of a given type out of the given domain.

### Get-ADObjectsAcrossTrust()
    Parameter:
        $class
	        Datatype: String
	        Mandatory: True
	        Description: Supply the object class (for example "person")
		
		$optionalFilter:
	        Datatype: String
	        Mandatory: False
	        Description: Supply an additional LDAP Filter if needed.
	
	Returns: All objects of a given type out of all trusted domains.

### Get-ADObjectByNetBIOS()
    Parameter:
        $path
	        Datatype: String
	        Mandatory: True
	        Description: Supply the account Path in NETBIOS Format to search for (e.g. "CONTOSO\johndoe")
		
	Returns: The AD Object of the supplied account name, this works across trusts and works for all users which the running machine is able to resolve.
# Group Handling
## Retrieving Members
### Get-GroupMember()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
	Returns: The group members distinguished names as String Array

### Get-GroupMemberByNetBIOS()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
	Returns: The group members Accountname in Netbios format like "CONTOSO\johndoe" as String Array
	
### Get-GroupMemberAcrossTrust()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
	Returns: The group members distinguished names as String Array and also resolves foreignSecurityPrincipals
## Modifying Members
### Add-GroupMemberBySid()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
        $MemberSid
	        Datatype: String
	        Mandatory: True
	        Description: Supply the security identifier ID of the member to add
	        
	Returns: The output of the ADSI Operation
	
### Remove-GroupMemberBySid()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
        $MemberSid
	        Datatype: String
	        Mandatory: True
	        Description: Supply the security identifier ID of the member to remove
	        
	Returns: The output of the ADSI Operation
	
### Add-GroupMember()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
        $MemberDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the DistinguishedName of the member to add
	        
	Returns: The output of the ADSI Operation
	
### Remove-GroupMember()
    Parameter:
        $GroupDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the groups DistinguishedName
	        
        $MemberDN
	        Datatype: String
	        Mandatory: True
	        Description: Supply the DistinguishedName of the member to remove
	        
	Returns: The output of the ADSI Operation

# General useful functions
### Resolve-Sid()
    Parameter:
        $sid
	        Datatype: String
	        Mandatory: True
	        Description: Supply the SID of the object to resolve
	        
	Returns: Returns the objects Accountname in Netbios format like "DOMAIN\sAMAccountName" as String

### Get-TrustedDomainsByNetBIOS()      
	Returns: Returns all trusted domains of the current domain as hashtable with the NETBIOS Domain Name as index

### Get-ADTrustedObjectsByDN()
	Returns: Returns all users and groups distinguishedNames of all trusted domains of the current domain as String Array, this operation may take some time depending on the connection and speed of the domain controllers.
