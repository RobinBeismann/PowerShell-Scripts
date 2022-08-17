$global:api_root_url = "https://git.contoso.com"
$global:api_base_url = "$($global:api_root_url)/api/v4/"
$global:api_admin_token = "gitAdminToken"

function Invoke-GitlabQuery {
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
        !([regex]::Match($uri,"(http|https):\/\/.*\/api\/v4\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
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

    $global:AuthHeaders = @{
        "PRIVATE-TOKEN" = $global:api_admin_token
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
        if(
            ($next = $Results.Headers.'X-Next-Page')            
        ){
            $pageRegex = '^.*((?>\?|\&)page=\d{1,1000})'
            if(
                ($match = [regex]::Match($uri,$pageRegex)) -and
                ($match.Success)
            ){
                # Remove existing pagination parameter
                $uri = $uri.Replace($match.Groups[1].Value,"")
            }

            # Calculate URL Tag
            $tag = "?"
            if($uri.Contains("?")){
                $tag = "&"
            }

            $uri += $tag + "page=$next"
            # If ForceSSL is set, overwrite any next page urls with https
            if($ForceSSL){
                $uri = $uri.Replace("http://","https://")
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

# Get Git Users
Invoke-GitlabQuery -Uri 'users'

# Add Git User Email Address
Invoke-GitlabQuery -Uri "users/$($existingUser.id)/emails" -Method 'POST' -Body @{
                        "email" = $email
                        "skip_confirmation" = $true
                    } 

# Delete Git User Email Address
Invoke-GitlabQuery -Uri "/users/id/emails/id" -Method 'DELETE'