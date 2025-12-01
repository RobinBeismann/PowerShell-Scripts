$api_base_url = "$GrafanaURL/api/"

function Invoke-GrafanaQuery {
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
        $ApiBaseUrl = $global:api_base_url
    )

    begin {

        # Create an empty array to store the result.
        $QueryResults = [System.Collections.ArrayList]@()

        $PreviousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $Encoding = [System.Text.Encoding]::UTF8
    }
    process {
        # Check if the URI is already a fully featured URI
        if (
            !([regex]::Match($uri, "(http|https):\/\/.*\/api\/", [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant').Success)
        ) {            
            if ($Uri.StartsWith("/")) {
                $uri = $Uri.Substring(1)
            }
            $Uri = $ApiBaseUrl + $Uri
        }

        # If ForceSSL is set, overwrite any next page urls with https
        if ($ForceSSL) {
            $uri = $uri.Replace("http://", "https://")
        }

        # Format headers.
        $HeaderParams = @{
            'Content-Type'  = "application/json"
            'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $GrafanaAPIUsername, $GrafanaAPIPassword))))"
        }


        # Invoke REST method and fetch data until there are no pages left.
        do {
            # Build Parameters
            $Params = @{
                UseBasicParsing = $true
                Method          = $Method
                ContentType     = "application/json"
                Uri             = $Uri
                Headers         = $HeaderParams
                ErrorAction     = "Stop"
            }
            if ($Body) {
                $Params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json))
            }

            # Get Result
            try {
                [Microsoft.PowerShell.Commands.WebResponseObject]$RawResult = Invoke-WebRequest @Params
                $EncodedResult = $Encoding.GetString(
                    $RawResult.RawContentStream.ToArray()
                )
                $Results = ConvertFrom-Json -InputObject $EncodedResult
            }
            catch {
                $Params.Body = $Body | ConvertTo-Json
                $ErrorDetails = @{
                    Parameters = $Params
                    ExactError = $_.ErrorDetails
                } | ConvertTo-Json

                Write-Error -ErrorAction Stop -Message "Error at Rest Request: $($_.Exception.Message)`n`n Error Details:`n$($ErrorDetails)"
            }
            # Add results to table
            $keyField = $null
            if (
                ($Results.PSObject.Properties | Where-Object { $_.Name -in "perPage" }) -and
                ($keyField = $Results.PSObject.Properties | Where-Object { $_.Name -notin "perPage", "page", "totalCount" } | Select-Object -First 1 -ExpandProperty 'Name')
            ) {
                $null = $QueryResults.AddRange($Results.$keyField)
                # Add single result to table
            }
            else {
                $null = $QueryResults.Add($Results)
            }

            # Process next page
            $uri = $null # Reset URI as Grafana has no standard pagination as of no
        } until (!($uri))

    }
    end {
        # Switch Progress Preference back
        $ProgressPreference = $PreviousProgressPreference

        # Return the result.
        $QueryResults
    }
}
