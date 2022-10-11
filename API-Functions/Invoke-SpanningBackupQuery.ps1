$global:api_base_url = "https://o365-api-eu.spanningbackup.com/external/"
$ClientID = "admin user"
$ClientSecret = "admin api token"

function Invoke-SpanningBackupQuery {
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
        $OrderBy = $null,
        [parameter(Mandatory = $false)]
        [int]$PageSize = 1000
    )

    # Check if the URI is already a fully featured URI
    if(
        !([regex]::Match($uri,"(http|https):\/\/.*\/external\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
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
        !($global:AuthHeaders)
    ){
        # Get OAUTH2 Token
        $pair = "$($ClientID):$($ClientSecret)"

        $global:AuthHeaders = @{
            'Authorization' = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair)))"
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
        }
    }
    #endregion
    
    # Calculate URL Tag
    if(
        !($Uri.ToLower().Contains("?size=")) -and
        !($Uri.ToLower().Contains("&size="))
    ){
        $tag = "?"
        if($uri.Contains("?")){
            $tag = "&"
        }
        $uri += $tag + "size=$PageSize"
    }

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
            $Params.Body = ($Body | ConvertTo-Json)
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
            $keys = ($Converted | Get-Member -MemberType 'NoteProperty').Name
            $mainProperty = $keys  | Where-Object { $_ -ne "nextLink" }
            $realResults = $Converted.$mainProperty
            if($realResults -is [array]){
                $null = $QueryResults.AddRange($realResults)
            }else{
                $null = $QueryResults.Add($realResults)
            }
        }

        # Process next page
        if(
            $keys -and
            ($next = $Converted.nextLink)  
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

Invoke-SpanningBackupQuery -Method 'GET' -Uri "users" -Verbose