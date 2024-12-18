$global:api_root_url = "https://api.eloomi.com"
$global:api_base_url = "$global:api_root_url/"

function Invoke-EloomiPeopleQuery {
    param (
        [parameter(Mandatory = $true)]
        $Uri,        
        [parameter(Mandatory = $false)]
        $Method = "GET",        
        [parameter(Mandatory = $false)]
        $Body,        
        [parameter(Mandatory = $false)]
        $ForceSSL = $true,        
        [parameter(Mandatory = $false)]
        [ValidateSet('ID','code_name')]
        $OrderBy = $null
    )

    # Check if the URI is already a fully featured URI
    if(
        !([regex]::Match($uri,"(http|https):\/\/.*\/api\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
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

    #region Authentication
    if(
        # Check if we don't have Auth Headers
        !($global:AuthHeaders) -or
        # Check if our Auth Headers are expired
        (
            $global:AuthExpiry -and
            (Get-Date) -gt $global:AuthExpiry
        ) 
    ){
        # Get OAUTH2 Token
        $pair = "$($global:ClientID):$($global:ClientSecret)"
        $Params = @{
            'Uri' = "$global:api_root_url/oauth/token"
            'Method' = 'POST'

            # POST Body
            'Body' = @{
                'grant_type' = 'client_credentials'
            }

            # POST Headers
            'Headers' = @{
                'Authorization' = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair)))"
            }
            'ContentType' = 'application/x-www-form-urlencoded'
        }

        $AuthResponse = Invoke-RestMethod @Params
        $global:AuthHeaders = @{
            'Authorization' = "Bearer $($AuthResponse.access_token)"
            'ClientId'      = $global:ClientID
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/json; charset=utf-8'
        }

        $global:AuthExpiry = (Get-Date).AddSeconds($AuthResponse.expires_in-30)
    }
    #endregion

    # Format headers.
    $HeaderParams = $global:AuthHeaders.Clone()

    # Create an empty array to store the result.
    $QueryResults = [System.Collections.ArrayList]@()

    #region Request
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
            $Params.Body = [System.Text.Encoding]::UTF8.GetBytes( (ConvertTo-Json -InputObject $Body -Depth 100) )
        }

        # Get Result
        try{
            #if($Method.ToLower() -eq "get"){
                $Results = Invoke-WebRequest @Params
            #}
        }catch{
            Write-Error -ErrorAction Stop -Message (ConvertTo-Json -InputObject @{ 
                "ErrorMessage" = "Error at Rest Request: $($_.Exception.Message)";
                "Error" = $_
                "Parameters" = $params
            })
        }
        # Add results to table
        if (
            $Results.Content -and
            ($Converted = ConvertFrom-Json -InputObject $Results.Content)
        ) {
            if($Converted -is [array]){
                $null = $QueryResults.AddRange($Converted)
            }else{
                $null = $QueryResults.Add($Converted)
            }
        }

        # Process next page
        $splitRegex = '.*, <(http.+)>; rel="next".*'
        if(
            ($link = $Results.Headers.Link) -and
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
    #endregion

    # Sort if OrderBy is set and the property is found
    if(
        ($OrderBy) -and
        ($QueryResults.$OrderBy)
    ){
        $QueryResults | Sort-Object -Property $OrderBy
    }else{
        # Return the result.
        $QueryResults
    }
}

# Get Eloomi Users
Invoke-EloomiQuery -Uri '/v3/users'

# Update Eloomi User
Invoke-EloomiQuery -Uri "/v3/users/$($eUser.id)" -Method 'PATCH' -Body @{
    email = "email@contoso.com"
}