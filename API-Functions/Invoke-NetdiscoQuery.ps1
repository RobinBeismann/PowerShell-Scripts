$nd_api_base_url = "https://netdisco-api.contoso.com/"
if(!($ndCredentials)){
    $ndCredentials = Get-Credential
}

function Invoke-NetdiscoQuery {
    param (
        [parameter(Mandatory = $true)]
        $Uri,        
        [parameter(Mandatory = $false)]
        $Method = "GET",        
        [parameter(Mandatory = $false)]
        $Body,        
        [parameter(Mandatory = $false)]
        $ForceSSL = $true
    )

    begin{

        # Create an empty array to store the result.
        $QueryResults = [System.Collections.ArrayList]@()

        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $Encoding = [System.Text.Encoding]::UTF8
    }
    process{
        # Check if the URI is already a fully featured URI
        if(
            !([regex]::Match($uri,"(http|https):\/\/.*\/api\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
        ){            
            if($Uri.StartsWith("/")){
                $uri = $Uri.Substring(1)
            }
            $Uri = $global:nd_api_base_url + $Uri
        }

        # If ForceSSL is set, overwrite any next page urls with https
        if($ForceSSL){
            $uri = $uri.Replace("http://","https://")
        }

        # Format headers.
        $HeaderParams = @{
            'Content-Type'  = 'application/json'
            'Authorization' = $global:ndToken
            'Accept' = 'application/json'
        }


        # Invoke REST method and fetch data until there are no pages left.
        do {
            # Build Parameters
            $Params = @{
                UseBasicParsing = $true
                Method = $Method
                ContentType = "application/json"
                Uri = $Uri
                Headers = $HeaderParams
                ErrorAction = "Stop"
            }
            if($Body){
                $Params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json))
            }

            # Get Result
            try{
                if(!$global:ndToken){
                    throw("TOKEN_REQUIRED")
                }

                [Microsoft.PowerShell.Commands.WebResponseObject]$RawResult = Invoke-WebRequest @Params
                $EncodedResult = $Encoding.GetString(
                    $RawResult.RawContentStream.ToArray()
                )
                $Results = ConvertFrom-Json -InputObject $EncodedResult
                
            }catch{
                if(
                    ($_.Exception.Message -eq "TOKEN_REQUIRED") -or
                    ($_.Exception.Response.StatusCode -eq 401)
                ){
                    $authParams = @{
                        Method = 'POST'
                        Uri = $global:nd_api_base_url + "login"
                        Headers = @{
                            "accept"="application/json"
                        }
                        Body = @{
                            username=$global:ndCredentials.GetNetworkCredential().username
                            password=$global:ndCredentials.GetNetworkCredential().password
                        }
                    }
                    $response = Invoke-RestMethod @authParams
                    $global:ndToken = $response.api_key

                    try{
                        [Microsoft.PowerShell.Commands.WebResponseObject]$RawResult = Invoke-WebRequest @Params
                        $EncodedResult = $Encoding.GetString(
                            $RawResult.RawContentStream.ToArray()
                        )
                        $Results = ConvertFrom-Json -InputObject $EncodedResult
                    }catch{
                        "Error at Rest Request: $($_.Exception.Message)`n`n Params:`n$($params | ConvertTo-Json)"
                    }
                }else{
                    Write-Error -ErrorAction Stop -Message "Error at Rest Request: $($_.Exception.Message)`n`n Params:`n$($params | ConvertTo-Json)"
                }
            }
            $null = $QueryResults.Add($Results)

            $uri = $null
        # Break out of loop if we got no next page
        } until (!($uri))

    }
    end{
        # Switch Progress Preference back
        $ProgressPreference = $PreviousProgressPreference

        # Return the result.
        $QueryResults
    }
}
