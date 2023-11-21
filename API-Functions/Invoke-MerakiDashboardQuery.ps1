$api_base_url = "https://api.meraki.com/api/v1/"
$mdToken = "token"

function Invoke-MerakiDashboardQuery {
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
            !([regex]::Match($uri,"(http|https):\/\/.*\/api\/v1\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
        ){            
            if($Uri.StartsWith("/")){
                $uri = $Uri.Substring(1)
            }
            $Uri = $global:api_base_url + $Uri
        }

        # If ForceSSL is set, overwrite any next page urls with https
        if($ForceSSL){
            $uri = $uri.Replace("http://","https://")
        }

        # Format headers.
        $HeaderParams = @{
            'Content-Type'  = "application/json"
            'Authorization' = "Bearer $global:mdToken"
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
                [Microsoft.PowerShell.Commands.WebResponseObject]$RawResult = Invoke-WebRequest @Params
                $EncodedResult = $Encoding.GetString(
                    $RawResult.RawContentStream.ToArray()
                )
                $Results = ConvertFrom-Json -InputObject $EncodedResult
            }catch{
                Write-Error -ErrorAction Stop -Message "Error at Rest Request: $($_.Exception.Message)`n`n Params:`n$($params | ConvertTo-Json)"
            }
            # Add results to table
            $null = $QueryResults.Add($Results)
                        
            # Process next page
            $splitRegex = '.*, <(http.+)>; rel=next.*'
            if(
                ($link = $RawResult.Headers.Link) -and
                ($match = [regex]::Match($link,$splitRegex)) -and
                ($match.Success) -and
                ($next = $match.Groups[1].Value)            
            ){
                # If ForceSSL is set, overwrite any next page urls with https
                if($ForceSSL){
                    $uri = $next.Replace("http://","https://")
                }else{
                    $uri = $next
                }      
            }else{
                $uri = $null
            }
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

$organization = Invoke-MerakiDashboardQuery -Uri "organizations"
$networks = Invoke-MerakiDashboardQuery -Uri "organizations/$($organization.id)/networks"
$devices = Invoke-MerakiDashboardQuery -Uri "organizations/$($organization.id)/devices/availabilities"
