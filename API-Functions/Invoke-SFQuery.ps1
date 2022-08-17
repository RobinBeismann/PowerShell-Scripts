$SFUsername = "username"
$SFPassword = "password"
$SFCompanyId = "CONTOSO"
$SFUrl = "https://api2.successfactors.eu"

function Invoke-SFAPIQuery {

    param (
        [parameter(Mandatory = $true)]
        $Uri,
        [parameter(Mandatory = $false)]
        $Method = 'GET',
        [parameter(Mandatory = $false)]
        $Body
    )

    if($Uri.Contains("?")){
        $Uri += '&$format=JSON'
    }else{
        $Uri += '?$format=JSON'
    }

    # Create an empty array to store the result.
    $QueryResults = @()
            
    # Invoke REST method and fetch data until there are no pages left.
    do {
        $params = @{
            Headers = $global:headers
            Uri     = $Uri
            UseBasicParsing = $true
            Method = $Method
            ContentType = "application/json"
        }
        if($Body -and $Body -is [hashtable]){
            $params.Body = ConvertTo-Json -Depth 100 -InputObject $Body
        }

        $Results = Invoke-RestMethod @params
        if($Results.d.results){
            $QueryResults += $Results.d.results
        }else{
            $Results.d
        }
        $uri = $Results.d.__next
    } until (!($uri))

    # Return the result.
    $QueryResults

}

# Get SF Entries
Invoke-SFAPIQuery -Uri "$global:SFUrl/odata/v2/EmpEmployment"

# Update SF Entry
Invoke-SFAPIQuery -Uri "$global:SFUrl/odata/v2/upsert?purgeType=incremental&suppressUpdateOfIdenticalData=true" -Method 'POST' -Body @{
    "__metadata" = $Employee.__metadata
    "username" = "john.doe"
}