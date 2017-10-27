<#----------------------------------------------------------------------------------------------------------------------------
August 2017 - Robin Beismann
This script was built to copys CRLs from the different sites onto the DMZ Webserver(s)
config.xml may look like:
<Config>
	<source share="<to be filled>" username="<to be filled>" password="<to be filled>"/>
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>"/>
	<destination share="<to be filled>" username="<to be filled>" password="<to be filled>"/>
</Config>
----------------------------------------------------------------------------------------------------------------------------#>

$curDir = (Get-Location).Path
$tempDir = $curDir + "\temp"
$sourceMap = "i:"
$destMap = "u:"
$filter = "*.crl"

#######################################################################################################################
########################################### Do not modify below #######################################################
#######################################################################################################################

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

    #Copy Items
    Get-ChildItem -Path ($sourceMap + "\*") -Include $filter | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $tempDir -Force -Confirm:$false
    }

    #Unmap network drive
    $net.RemoveNetworkDrive($sourceMap,$true)
}

#Copy to destination(s)
foreach($destination in $destinations){
    #Map network drive
    $net = New-Object -ComObject WScript.Network
    $net.MapNetworkDrive($destMap, $destination.share, $false, $destination.username, $destination.password)

    #Copy Items
    Get-ChildItem -Path ($tempDir + "\*") | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination ($destMap + "\") -Force -Confirm:$false
    }

    #Unmap network drive
    $net.RemoveNetworkDrive($destMap,$true)
}

#Remove temp directory
Remove-Item -Path $tempDir -Force -Confirm:$false -Recurse
