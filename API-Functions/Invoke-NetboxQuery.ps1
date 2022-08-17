$api_base_url = https://netbox.contoso.com/api/
$token = ""

function Invoke-NetboxQuery {
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

    # Format headers.
    $HeaderParams = @{
        'Content-Type'  = "application/json"
        'Authorization' = "Token $global:nbToken"
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
                $Results.PSObject.Properties.Name.Contains("results") -or
                $Results.PSObject.Properties.Name.Contains("count")
            )
        ){
            $null = $QueryResults.Add($Results)
        }

        # Process next page
        if($Results.'next'){
            # If ForceSSL is set, overwrite any next page urls with https
            if($ForceSSL){
                $uri = $Results.'next'.Replace("http://","https://")
            }else{
                $uri = $Results.'next'
            }      
        }else{
            $uri = $null
        }
    # Break out of loop if we got no next page
    } until (!($uri))

    # Return the result.
    $QueryResults
}

# Get Devices
Invoke-NetboxQuery -Uri "dcim/devices/"

# New Cluster
Invoke-NetboxQuery -Uri "virtualization/clusters/" -Method 'POST' -Body @{ 
        name = $scClusterName 
        type = $clusterType
        group = $clusterGroup
        site = $site
}

# Update device cluster ID
Invoke-NetboxQuery -Uri "dcim/devices/$($nbDevice.id)/" -Method 'PATCH' -Body @{ 
    cluster = ($nbCluster.id) 
}