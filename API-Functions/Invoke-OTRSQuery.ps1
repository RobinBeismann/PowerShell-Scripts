<#
##################################################################################################################
    Sorry, not yet in the default Invoke-xyQuery Function format yet.
##################################################################################################################
#>

function Get-OTRSConfigItem(){
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]$ID
    )

    $arr = @{
        UserLogin = $script:username
        Password = $script:password
        
        ConfigItemID = $id        
    }

    $request = $arr | ConvertTo-Json
    $requestResult  = Invoke-RestMethod     -Uri ($requestURL + "GetCI") `
                                            -Method Post `
                                            -Body $request `
                                            -UseBasicParsing `
                                            -ContentType "application/json" 
    return $requestResult.ConfigItem
}

function Get-OTRSConfigItems($FilterByServiceTag,$FilterByName){
    $arr = @{
        UserLogin = $script:username
        Password = $script:password
        ConfigItem = @{
            Class = "Computer"
        }
    }

    if($FilterByServiceTag){
        $arr.ConfigItem.CIXMLData = @{}
        $arr.ConfigItem.CIXMLData.ServiceTag = $FilterByServiceTag
    }
    
    if($FilterByName){
        $arr.ConfigItem.Name = $FilterByName
    }

    $request = $arr | ConvertTo-Json
    $requestResult  = Invoke-RestMethod     -Uri ($requestURL + "SearchCI")`
                                            -Method Post `
                                            -Body $request `
                                            -UseBasicParsing `
                                            -ContentType "application/json" 

    return $requestResult.ConfigItemIDs | ForEach-Object {
        $_ | Get-OTRSConfigItem
    }
}

function New-OTRSConfigItem($Name,$Serial,$MAC,$Manufacturer){
    $arr = @{
        UserLogin = $script:username
        Password = $script:password
        ConfigItem = @{
            Class = "Computer"
            Name = $Name
            DeplState = "Aktiv"
            InciState = "Operational"
            CIXMLData = @{           
                ServiceTag = $serial
                Inbetriebnahme = (Get-Date -Format "yyyy-MM-dd")
                MAC = ($MAC -join " ")
                Typ = ("$Manufacturer")
            }

        }
    }
    
    $request = $arr | ConvertTo-Json
    $requestResult  = Invoke-RestMethod     -Uri ($requestURL + "CreateCI")`
                                            -Method Post `
                                            -Body $request `
                                            -UseBasicParsing `
                                            -ContentType "application/json" 

    return $requestResult
}

function New-OTRSConfigItem($Name,$SerialNumber,$MAC,$Manufacturer){
    $arr = @{
        UserLogin = $script:username
        Password = $script:password
        ConfigItem = @{
            Class = "Computer"
            Name = $Name
            DeplState = "Aktiv"
            InciState = "Operational"
            CIXMLData = @{           
                ServiceTag = $SerialNumber
                Inbetriebnahme = (Get-Date -Format "yyyy-MM-dd")
                MAC = ($MAC -join " ")
                Typ = ("$Manufacturer")
            }

        }
    }
    
    $request = $arr | ConvertTo-Json
    $requestResult  = Invoke-RestMethod     -Uri ($requestURL + "CreateCI")`
                                            -Method Post `
                                            -Body $request `
                                            -UseBasicParsing `
                                            -ContentType "application/json" 

    return $requestResult
}

function Update-OTRSConfigItem($ConfigItemID,$Name,$SerialNumber,$Model,$Date,$Comment,$Owner,$State){
    $arr = @{
        UserLogin = $script:username
        Password = $script:password
        ConfigItemID = $ConfigItemID

        ConfigItem = @{
            Class = "Computer"            
            Name = $Name
            DeplState = $State
            InciState = "Operational"

            CIXMLData = @{           
                ServiceTag = $SerialNumber
                Inbetriebnahme = $date
                Typ = $Model
                note = $Comment
                Owner = $Owner
            }
        }
    }
    
    $request = $arr | ConvertTo-Json
    $requestResult  = Invoke-RestMethod     -Uri ($requestURL + "UpdateCI")`
                                            -Method POST `
                                            -Body $request `
                                            -UseBasicParsing `
                                            -ContentType "application/json" 

    return $requestResult
}

#OTRS Username
$username = "username"

#OTRS Password
$password = "password"

#OTRS URL
$baseURL = "https://otrs-baseurl/otrs"

#OTRS Webservice
$webservice = "REST-Webservice"

#Request SubURL
$requestURL = "$baseURL/nph-genericinterface.pl/Webservice/$webservice/"