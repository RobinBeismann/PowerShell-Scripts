<#----------------------------------------------------------------------------------------------------------------------------
February 2017 - Robin Beismann
Creates local admin groups for Windows Servers to centrally manage local admin privileges.
----------------------------------------------------------------------------------------------------------------------------#>

Import-Module -Name ActiveDirectory

## Static Variables
$globalPrefix = 'SG_'
$searchBase = 'OU=Computer,OU=DummyOU,DC=contoso,DC=com'
$domain = 'contoso.com'
$domainNETBIOS = 'NWDE'
$domainBaseContext = 'dc=contoso,dc=com'

#Mail settings

$sendInfoMail = $true
$mailserver = 'smtp.contoso.com'
$recipient = 'administrator@contoso.com'
$sender = 'script@contoso.com'
$subject = 'Local Group <-> Domain Group Mappings'

#DC checks
$numberofTests = 3

## Define Mappings for every Local <-> Domain Group Mapping
$destinationOU = 'OU=Local_Groups,OU=Groups,OU=DummyOU,DC=contoso,DC=com'
$mappings = @{
    RD = @{
            prefix  = 'RD_'
            suffix  = ''            
            localGroup = @{
                            1031 = 'Remotedesktopbenutzer'
                            1033 = 'Remote Desktop Users'
                         }
            destinationOU = $destinationOU
            Description = 'Remote Desktop Users Group'
        }
    LA = @{
            prefix  = 'LA_'
            suffix  = ''
            localGroup = @{
                            1031 = 'Administratoren'
                            1033 = 'Administrators'
                         }
            destinationOU = $destinationOU
            Description = 'Local Administrators Group'
        }
    MU = @{
            prefix  = 'MU_'
            suffix  = ''
            localGroup = @{
                            1031 = 'Hauptbenutzer'
                            1033 = 'Power Users'
                         }
            destinationOU = $destinationOU
            Description = 'Multi Users Group'
        }

}

#######################################################################################################################
#######################################################################################################################
########################################### Do not modify below #######################################################
#######################################################################################################################
#######################################################################################################################

<#----------------------------------------------------------------------------------------------------------------------------
                                                 Functions
----------------------------------------------------------------------------------------------------------------------------#>

function Add-DomainObjectToLocalGroup(){
    param(
        [Parameter(Mandatory=$true)][string]$domain,
        [Parameter(Mandatory=$true)][string]$GroupName,
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][string]$LocalGroup
    )
    $AdminGroup = [ADSI]"WinNT://$computerName/$LocalGroup,group"
    $Group = [ADSI]"WinNT://$domain/$GroupName,group"
    $AdminGroup.Add($Group.Path)
}

function Get-LocalGroupMembers(){
    param(
        [Parameter(Mandatory=$true)][string]$computerName,
        [Parameter(Mandatory=$true)][string]$groupName    
    )
  
    $members = Get-WmiObject -Class win32_groupuser -ComputerName $computerName   
    $members = $members | Where-Object {$_.groupcomponent -like "*$groupName*"}  
  
    $members | ForEach-Object {  
        $_.partcomponent -match '.+Domain\=(.+)\,Name\=(.+)$' > $null 
        $matches[1].trim('"') + '\' + $matches[2].trim('"')  
    }  
}

<#----------------------------------------------------------------------------------------------------------------------------
                                                 Find least busy domain controller
----------------------------------------------------------------------------------------------------------------------------#>
Write-Verbose -Message ('Starting to check which DC got the least response time')
$DCs = (Get-ADDomainController -Filter {Name -like '*' } ).Name | Sort-Object
$leastResponseTime = 2500
$leastResponseDC = ''


foreach ($DC in $DCs) 
{
    if( !(Test-Connection -ComputerName $DC -BufferSize 16 -Count 3 -ErrorAction SilentlyContinue -Quiet)){
        Write-Verbose -Message ($DC + ' is unreachable')
    }else{
        Write-Verbose -Message ($DC + ': tests running.')
        $averageResponse = 0    
        for ($i=1; $i -le $numberofTests; $i++){
            $averageResponse += (Measure-Command -Expression {Get-ADUser -Identity Administrator -Server $DC}).TotalSeconds
        }
        Write-Verbose -Message ($DC + ': tests done.')
        $averageResponse = $averageResponse/$numberofTests

        if($leastResponseTime -gt $averageResponse){
            $leastResponseDC = $DC
            $leastResponseTime = $averageResponse
        }
    }
}
Write-Verbose -Message ("Chose DC: $leastResponseDC with an Average Response Time of $leastResponseTime in $numberofTests Tests")

<#----------------------------------------------------------------------------------------------------------------------------
                                                 Get AD Computers and filter them
----------------------------------------------------------------------------------------------------------------------------#>

Write-Verbose -Message ('Starting to get computers and check if they are online')
$computers = Get-ADComputer -SearchBase $searchBase -Filter * -Properties * |
Sort-Object -Property { $_.Name } | #Sort by Name Ascending
Where-Object {
    if(
        ($_.OperatingSystem -and $_.OperatingSystem.StartsWith('Windows')) -and #Checking if the host is even running Windows
        !($_.CanonicalName.StartsWith("$domain/Domain Controllers")) #Check if the host is a Controller @ALL: Is there a better way to check this language independent?
    ){ 
            Write-Verbose -Message ("Testing $($_.Name) ..")
            Test-Connection -Count 1 -ComputerName $_.Name -ErrorAction SilentlyContinue #Check if the host in online before running any querys
    }
} 


<#----------------------------------------------------------------------------------------------------------------------------
                                                 Add AD Groups and put them into the associated local groups
----------------------------------------------------------------------------------------------------------------------------#>

$addedADGroups = @()
$addedGroupMemberships = @()
$updatedOUs = $false

foreach($computer in $computers){
    foreach($group in $mappings.GetEnumerator()){
        Write-Verbose -Message ("Running Mapping Profile: $($group.Name) for " + $computer.Name)
        
        $map = $group.Value
        $groupName = $globalPrefix + $map.prefix + $computer.Name + $map.suffix

       if(!(Get-ADGroup -Filter {Name -eq $groupName} -ErrorAction SilentlyContinue)){
            Write-Verbose -Message ("Creating Group: $groupName")
            New-ADGroup -Server $leastResponseDC -GroupScope Universal -DisplayName $groupName -Name $groupName -Description ($map.Descriptions + ' on ' + $computer.Name) -Path $map.DestinationOU
            $addedADGroups += $groupName
            $updatedOUs = $true #We have to update our AD on all other DCs so the computers will be able to look it up when they add it to the local group
        }else{
            Write-Verbose -Message ("Not creating Group: $groupName")
        }
    }
}

if($updatedOUs){
    Write-Verbose -Message ('Telling Repadmin to sync the AD to the other DCs and waiting 10 Seconds for the sync to finish.')
    & "$env:windir\system32\repadmin.exe" /syncall $leastResponseDC $domainBaseContext /d /e /q
    Start-Sleep -Seconds 10
}

foreach($computer in $computers){
    [int]$systemLanguage = (Get-WmiObject -ComputerName $computer.Name -Class Win32_OperatingSystem).OSLanguage
    foreach($group in $mappings.GetEnumerator()){
        Write-Verbose -Message ("Running Local Group Mapping Profile: $($group.Name) for " + $computer.Name)
        
        $map = $group.Value
        $groupName = $globalPrefix + $map.prefix + $computer.Name + $map.suffix

        if((Get-LocalGroupMembers -computerName $computer.Name -groupName $map.localGroup[$systemLanguage]) -notcontains ($domainNETBIOS + '\' + $groupName) ){
            Write-Verbose -Message ("Adding Group: $groupName to $($map.localGroup[$systemLanguage]) on " + $computer.Name)
            Add-DomainObjectToLocalGroup -domain $domain -GroupName $groupName -ComputerName $computer.Name -LocalGroup $map.localGroup[$systemLanguage]
            $addedGroupMemberships += "$groupName to $($map.localGroup[$systemLanguage]) on " + $computer.Name 
        }else{
            Write-Verbose -Message ("Not adding Group: $groupName to $($map.localGroup[$systemLanguage]) on " + $computer.Name)
        }
    }
}

if( $sendInfoMail -and (($addedADGroups.Count + $addedGroupMemberships.Count) -gt 0)){
    Write-Verbose -Message ('Changes made -> sending mail')
    $mail = "<--- Local Groups Mapping Script on $($env:COMPUTERNAME)---><br/><br/>
    Chose DC: $leastResponseDC with an Average Response Time of $leastResponseTime in $numberofTests Tests<br/><br/>"
    if($addedADGroups.Length -gt 0){
        $mail += 'Added following AD Groups:<br/>'
        foreach($group in $addedADGroups){
            $mail += '<tab indent=20>' + $group + '<br/>'
        }
        $mail += '<br/><br/>'
    }

    if($addedGroupMemberships.Length -gt 0){
        $mail += 'Added following local Group Memberships:<br/>'
        foreach($group in $addedGroupMemberships){
            $mail += '<tab indent=20>' + $group + '<br/>'
        }
        $mail += '<br/><br/>'
    }

    Write-Verbose -Message ('Mail data collection completed, sending mail now..')
    Send-MailMessage -to $recipient -from $sender -subject $subject -body $mail -smtpServer $mailserver -BodyAsHtml
}
