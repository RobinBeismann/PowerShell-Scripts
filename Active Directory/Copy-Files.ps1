<#----------------------------------------------------------------------------------------------------------------------------
August 2017 - Robin Beismann
This script was built to copys CRLs from the different sites onto the DMZ Webserver(s)
However it might be used for all kind of files, just adjust the parameters below and 
config.xml may look like:
<Config>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>" filter="*.crl" recursive="true"/>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>" filter="*.crt" recursive="true"/>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>" filter="*.crt"/>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>" recursive="true"/>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>"/>
	
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>" filter="*.txt" recursive="true"/>
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>" filter="*" recursive="true"/>
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>" recursive="true"/>
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>"/>
</Config>

The Parameters "filter" and "recursive" are optional, while "share", "username" and "password" are mandatory.
For Shares without login requirement just speicfy username="" and password=""

CAUTION:
PLEASE MAKE SURE THAT THE SOURCE/DESTINATION MAP LETTERS ARE NOT IN USE BY ANY SHARES OR DRIVES AS THIS WILL CAUSE UNPREDICTABLE RESULTS
AND MIGHT CAUSE DATALOSS!

Please be aware that the force flag is set, so this script WILL overwrite any files at the destination which exist at the source.
The last source in the config will always be the newest the highest priority for a file if it exists at multiple sources.
So if "Disclaimer.docx" exists at source1 and "Disclaimer.docx" also exists at source 3 then the document on source 3 will overwrite 
the copy on the temporary directory and thus will be copied onto the destination.
ALSO: If there's already a "Disclaimer.docx" on one of the destination shares it will be overwritten by the last source - in our example
it will be overwritten by source 3.
----------------------------------------------------------------------------------------------------------------------------#>

$curDir = (Get-Location).Path
$tempDir = $curDir + "\temp"
$sourceMap = "B:"
$destMap = "B:"

#######################################################################################################################
########################################### Do not modify below #######################################################
#######################################################################################################################
if( (Test-Path -Path $sourceMap) -or (Test-Path -Path $destMap) ){
	Write-Host("ERROR: Source or Destination Mapping Letter is already in use! Exiting the script.")
	exit
}

#Define Varaibles
[xml]$config = Get-Content -Path ($curDir + "\config.xml")
$sources = $config.Config.source
$destinations = $config.Config.destination

#Check if Temp Directory exists (unclean script ending)
if(Test-Path($tempDir)){
    Remove-Item -Path $tempDir -Force -Confirm:$false -Recurse
}
#Create temp directory
New-Item -Path $tempDir -ItemType Directory

#Retrieve source files
foreach($source in $sources){
    #Map network drive
    $net = New-Object -ComObject WScript.Network
    $net.MapNetworkDrive($sourceMap, $source.share, $false, $source.username, $source.password)

    #Declare Filter, if there's none set in the config, just copy all files 
    $filter = "*"
    if($source.filter){
    	$filter = $source.filter
    }

    #Check if Recusive Flag is set and copy Items
    if($source.recursive){
	    Get-ChildItem -Path ($sourceMap + "\*") -Include $filter | ForEach-Object {
		Copy-Item -Path $_.FullName -Destination $tempDir -Recurse -Force -Confirm:$false 
	    }
    }else{
	    Get-ChildItem -Path ($sourceMap + "\*") -Include $filter | ForEach-Object {
		Copy-Item -Path $_.FullName -Destination $tempDir -Force -Confirm:$false
	    }    
    }
    
    #Unmap network drive
    $net.RemoveNetworkDrive($sourceMap,$true)
}

#Copy to destination(s)
foreach($destination in $destinations){
    #Map network drive
    $net = New-Object -ComObject WScript.Network
    $net.MapNetworkDrive($destMap, $destination.share, $false, $destination.username, $destination.password)

    #Declare Filter, if there's none set in the config, just copy all files 
    $filter = "*"
    if($destination.filter){
    	$filter = $destination.filter
    }
    
    #Check if Recusive Flag is set and copy Items
    if($destination.recursive){
	    Get-ChildItem -Path ($tempDir + "\*") | ForEach-Object {
		Copy-Item -Path $_.FullName -Destination ($destMap + "\") -Recurse -Force -Confirm:$false
	    }
    }else{
	    Get-ChildItem -Path ($tempDir + "\*") | ForEach-Object {
		Copy-Item -Path $_.FullName -Destination ($destMap + "\") -Force -Confirm:$false
	    }    
    }

    #Unmap network drive
    $net.RemoveNetworkDrive($destMap,$true)
}

#Remove temp directory
Remove-Item -Path $tempDir -Force -Confirm:$false -Recurse
