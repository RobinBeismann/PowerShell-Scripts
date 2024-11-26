$global:api_root_url = "https://api.eloomi.io"
$global:api_key = ''

function Invoke-EloomiInfiniteQuery {
    [CmdletBinding()]
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
        $OrderBy = $null,
        [parameter(Mandatory = $false)]        
        $PageSize = 1000
    )

    # Check if the URI is already a fully featured URI
    $buildUri = {     
        $localUri = $Uri   

        # Remove duplicates slash
        if(
            !([regex]::Match($localUri,"(http|https):\/\/.*\/api\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
        ){            
            if($localUri.StartsWith("/")){
                $localUri = $localUri.Substring(1)
            }
            $localUri = $global:api_base_url + $localUri
        }

        # If ForceSSL is set, overwrite any next page urls with https
        if($ForceSSL){
            $localUri = $localUri.Replace("http://","https://")
        }

    }

    # Format headers.
    $HeaderParams = @{
        'apikey' = $global:api_key
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json; charset=utf-8'
    }


    # Create an empty array to store the result.
    $QueryResults = [System.Collections.ArrayList]@()

    #region Request
    # Invoke REST method and fetch data until there are no pages left.
    $CurrentPage = 1

    do {
        . $buildUri

        $localUriLowerCase = $localUri.ToLower()
        # Add Page Size
        if(
            !($localUriLowerCase.Contains("?page_size=")) -and
            !($localUriLowerCase.Contains("&page_size="))
        ){
            $tag = "?"
            if($localUri.Contains("?")){
                $tag = "&"
            }
            $localUri += $tag + "page_size=$PageSize"
        }

        if(
            !($localUriLowerCase.Contains("?page=")) -and
            !($localUriLowerCase.Contains("&page="))
        ){
            $tag = "?"
            if($localUri.Contains("?")){
                $tag = "&"
            }
            $localUri += $tag + "page=$CurrentPage"
        }

        # Build Parameters
        $Params = @{
            UseBasicParsing = $true
            Method = $Method
            ContentType = "application/json"
            Uri = $localUri
            Headers = $HeaderParams
            ErrorAction = "Stop"
        }

        if($Body){
            $Params.Body = [System.Text.Encoding]::UTF8.GetBytes( (ConvertTo-Json -InputObject $Body -Depth 100) )
        }

        # Get Result
        try{
            Write-Verbose -Message "Calling URI: $localUri"
            $Results = Invoke-WebRequest @Params
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
            if($Converted.data -is [array]){
                $null = $QueryResults.AddRange($Converted.data)
            }else{
                $null = $QueryResults.Add($Converted)
            }
        }

        # Process next page
        if(
            ($Total = $Converted.last_page) -and
            ($CurrentPage -lt $Total)          
        ){
            $CurrentPage++
            if($Results.Headers.'ratelimit-remaining' -eq 0){
                Write-Host("Rate Limit Exceeded, waiting $($Results.Headers.'ratelimit-reset') Seconds until reset..")
                Start-Sleep -Seconds $Results.Headers.'ratelimit-reset'
            }
        }else{
            $localUri = $null
        }
    # Break out of loop if we got no next page
    } until (!($localUri))
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
Invoke-EloomiQuery -Uri 'public/v1/users'
