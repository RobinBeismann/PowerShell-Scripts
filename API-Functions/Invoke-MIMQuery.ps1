$api_base_url = "https://lithnet-restservice.contoso.com/v2/"

function Invoke-MIMQuery {
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

    # Check if the URI is already a fully featured URI
    if(
        !([regex]::Match($uri,"(http|https):\/\/.*\/v2\/",[Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
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

    # Create an empty array to store the result.
    $QueryResults = [System.Collections.ArrayList]@()

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
            UseDefaultCredentials = $true
        }
        if($Body){
            $Params.Body = ($Body | ConvertTo-Json)
        }

        # Get Result
        try{
            #if($Method.ToLower() -eq "get"){
                $Results = Invoke-RestMethod @Params
            #}
        }catch{
            Write-Error -ErrorAction Stop -Message "Error at Rest Request: $($_.Exception.Message)`n`n Params:`n$($params | ConvertTo-Json)"
        }
        # Add results to table
        if (
            $Results.results
        ) {
            $null = $QueryResults.AddRange($Results.results)
        # Add single result to table
        }elseif(
            $Results -and
            !(
                $Results.PSObject.Properties.Name.Contains("Results") -or
                $Results.PSObject.Properties.Name.Contains("TotalCount")
            )
        ){
            $null = $QueryResults.Add($Results)
        }

        # Process next page
        if($Results.'NextPage'){
            # If ForceSSL is set, overwrite any next page urls with https
            if($ForceSSL){
                $uri = $Results.'NextPage'.Replace("http://","https://")
            }else{
                $uri = $Results.'NextPage'
            }      
        }else{
            $uri = $null
        }
    # Break out of loop if we got no next page
    } until (!($uri))

    # Return the result.
    $QueryResults
}

# Get Set Members
$SetName = "All Users"
Invoke-MIMQuery -Uri "resources/?filter=/Person[ObjectID=/Set[DisplayName='$SetName']/ComputedMember]" -Verbose