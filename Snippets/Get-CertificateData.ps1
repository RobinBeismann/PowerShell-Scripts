function Get-CertificateData($URL){
    $timeoutMilliseconds = 30000

    #Turn off Server Certificate Validation as we only want to gather the expire data regardless of the validity
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    #Create the request
    $req = [Net.HttpWebRequest]::Create($URL)

    #Set the timeout higher
    $req.Timeout = $timeoutMilliseconds

    #Set to POST so we don't have to mess with any redirections
    $req.Method = "POST"

    #Will return an error on 404 pages, does not matter in this case -> just discard
    try{ 
        $req.GetResponse() | Out-Null
    }catch{}

    try{
        #Retrieve Certificate Data
        $expiry = $req.ServicePoint.Certificate.GetExpirationDateString()
        $Subject = $req.ServicePoint.Certificate.Subject
        $Issuer = $req.ServicePoint.Certificate.Issuer

        #Parse the return and format it to Datetime
        $expiryDateTime = [datetime]::ParseExact($expiry, "dd.MM.yyyy HH:mm:ss", $null)
        return @{
            ExpiryDate = $expiryDateTime
            Subject = $Subject
            Issuer = $Issuer
        }
    }catch{
        return $false
    }
}
