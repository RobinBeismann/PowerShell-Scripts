function Get-CertificateExpiry($URL){
    $timeoutMilliseconds = 30000
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $req = [Net.HttpWebRequest]::Create($URL)
    $req.Timeout = $timeoutMilliseconds
    
    #Will return an error on 404 pages, does not matter in this case -> just discard
    try{ 
        $req.GetResponse()
    }catch{}

    try{
        $expiry = $req.ServicePoint.Certificate.GetExpirationDateString()
        $expiryDateTime = [datetime]::ParseExact($expiry, "dd.MM.yyyy HH:mm:ss", $null)
        return $expiryDateTime
    }catch{
        return $false
    }
}
