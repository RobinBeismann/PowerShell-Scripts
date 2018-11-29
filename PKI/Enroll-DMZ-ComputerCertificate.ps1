#region Static Definitions
$OCSPURL = 'ocsp.contoso.com'         #DNS Subject which will be contained as Subject Alternative Name
$globalTempPath = 'C:\temp\'          #Temp Path on the OCSP and WinRM Jump Hosts

#Define OCSP Responder Servers below
$OCSPs = @{
    'uniqueIdentifier' = @{
        Server = 'servername'
        Username = 'username' #Needs access to the Computer's Certificate Store and Remote Management for WinRM
        Password = ''
    }
}

#Define CAs below
$CAs = @{
    'uniqueIdentifier' = @{
                    #WinRM Jumphost
                    Server = 'servername' # Must be DNS or SPN resolveable
                    Username = 'username' # This user also needs "Enroll" Permissions on the Certificate Template
                    Password = 'password'

                    CAServer = 'caservername'          #The Server which hosts the issuing CA
                    CAName = 'caname'                  #The Common Name of the Issuing CA
                    Template = 'OCSP Response Signing' #The OCSP Signing Certificate Template Name
                 }
}


#endregion

#region Codeblocks
$SetCertificatePermission = {
    
    function Get-OCSPSigningCertificates
    {
      param
      (
        [Object]
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Data to filter')]
        $InputObject
      )
      process
      {
        if ($InputObject.EnhancedKeyUsageList.FriendlyName -contains 'OCSP Signing')
        {
          $InputObject
        }
      }
    }

    Import-Module -Name webadministration

    $OCSPCerts = Get-ChildItem -Path CERT:\LocalMachine\My | Get-OCSPSigningCertificates 
    
    foreach($OCSPCert in $OCSPCerts){
      $rsaFile = $OCSPCert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
	
      $keyPath = 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\'
      $fullPath=$keyPath+$rsaFile


        $InheritanceFlag = [Security.AccessControl.InheritanceFlags]::None 
        $PropagationFlag = [Security.AccessControl.PropagationFlags]::None 
        $objType =[Security.AccessControl.AccessControlType]::Allow
        $colRights = [Security.AccessControl.FileSystemRights]'FullControl'
        $objUser = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList ('NETWORK SERVICE')
        $objACE = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList ($objUser, $colRights, $InheritanceFlag, $PropagationFlag,$objType)

      $acl = Get-Acl -Path $fullPath
        $acl.AddAccessRule($objACE)
        $acl | Set-Acl -Path $fullPath

    }
}
$CreateSigningRequest = {
    param(
        [Parameter(Mandatory=$true)]$settings
    )

    if(!(Test-Path -Path $settings.rmTempPath)){
        New-Item -ItemType Directory -Path $settings.rmTempPath
    }
    if(Test-Path -Path $settings.rmCSRPath){
        Remove-Item -Confirm:$false -Path $settings.rmCSRPath
    }
    if(Test-Path -Path $settings.rmCERPath){
        Remove-Item -Confirm:$false -Path $settings.rmCERPath
    }
    if(Test-Path -Path $settings.rmRequestInfPath){
        Remove-Item -Confirm:$false -Path $settings.rmRequestInfPath
    }

    $settings.inf | Out-File -FilePath $settings.rmRequestInfPath -Confirm:$false -Force

    $parameters = @('-new', $settings.rmRequestInfPath, $settings.rmCSRPath)
    & "$env:windir\system32\certreq.exe" @parameters
}
$SignSigningRequest = {
    param(
          [Parameter(Mandatory=$true)]$settings
    )
            
    $parameters = @('-config', ("`"" + $settings.CAPath + "`""), '-submit', '-attrib', ('CertificateTemplate:' + $settings.Template), $settings.rmCSRPath, $settings.rmCERPath)

    Start-Process -FilePath "$env:windir\system32\certreq.exe" -ArgumentList $parameters

}
$cleanTempFolder = {
    param(
          [Parameter(Mandatory=$true)]$settings
    )

    if(!(Test-Path -Path $settings.rmTempPath)){
        New-Item -ItemType Directory -Path $settings.rmTempPath
    }
    if(Test-Path -Path $settings.rmCSRPath){
        Remove-Item -Confirm:$false -Path $settings.rmCSRPath
    }
    if(Test-Path -Path $settings.rmCERPath){
        Remove-Item -Confirm:$false -Path $settings.rmCERPath
    }

    if(Test-Path -Path $settings.rmRSPPath){
        Remove-Item -Confirm:$false -Path $settings.rmRSPPath
    }
}
$importSignedCertificate = {
    param(
          [Parameter(Mandatory=$true)]$settings
    )
            
    $parameters = @('-accept', $settings.rmCERPath)
    & "$env:windir\system32\certreq.exe" @parameters
}
$cleanExpiredCertificates = {
    $now = Get-Date
    Get-ChildItem -Path Cert:\LocalMachine\My |
    ForEach-Object -Process { if ($PSItem.NotAfter -lt $now ) { $PSItem } } |
    Remove-Item -Confirm:$false
}
#endregion

#region Code
$scriptPath = (Get-Location).Path
$Obj_PSCred = 'System.Management.Automation.PSCredential'

#Create workdir
$workdir = $scriptPath + '\ocspworkdir'
if(Test-Path -Path $workdir){
    Write-Host('Deleting old Workdir')
    Remove-Item -Recurse -Confirm:$false -Path $workdir | Out-Null
}
Write-Host('Creating new workdir')
New-Item -ItemType Directory -Path $workdir | Out-Null

foreach($OCSPServer in $OCSPs.GetEnumerator()){
    $OCSPServer = $OCSPServer.Value

    #Define Request Information, unable to align this with tabs
    $inf = (@'
[Version]
Signature= {0}
 
[NewRequest]
Subject = "CN={1}"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0
 
[RequestAttributes]
SAN="dns={2}"
'@ -f ('$Windows NT$'), $OCSPServer.Server, $OCSPURL)

    #Build credential object
    $secpasswd = ConvertTo-SecureString -String $OCSPServer.Password -AsPlainText -Force
    $OCSPCredentials =  New-Object -TypeName $Obj_PSCred -ArgumentList ($OCSPServer.Username, $secpasswd)

    #Connect to this OCSP Responder Server
    Write-Host('Establishing connection to OCSP Server ' + $OCSPServer.Server)
    $OCSPSession = New-PSSession -ComputerName $OCSPServer.Server -Credential $OCSPCredentials

    if(!$OCSPSession){
        Write-Error -Message ('Could not establish PSRemote Session to OCSP Server, breaking.')
        exit
    }
    Write-Host('Established connection to OCSP Server ' + $OCSPServer.Server)
    

    foreach($CA in $CAs.GetEnumerator()){
        #Build credential object
        $secpasswd = ConvertTo-SecureString -String $CA.Value.Password -AsPlainText -Force
        $CACredentials =  New-Object -TypeName $Obj_PSCred -ArgumentList ($CA.Value.Username, $secpasswd)

        #Build settings object
        $SigningServer = $CA.Value.Server
        $CAName = $CA.Value.CAName
        $CAServer = $CA.Value.CAServer
        $TrimmedCAName = $CAName.Replace(" ","_")
        
        
        $settings = @{
            CSRPath = ($workdir + "\OCSP_$TrimmedCAName.csr")
            CERPath = ($workdir + "\OCSP_$TrimmedCAName.cer")
            Template = ($CA.Value.Template)

            rmTempPath = $globalTempPath
            rmCSRPath = ($globalTempPath + "\OCSP_$TrimmedCAName.csr")
            rmCERPath = ($globalTempPath + "\OCSP_$TrimmedCAName.cer")
            rmRSPPath = ($globalTempPath + "\OCSP_$TrimmedCAName.rsp")
            rmRequestInfPath = ($rmTempPath + "\OCSP_$TrimmedCAName.inf")
            inf = $inf

            CAPath = ("$CAServer\$CAName")
            CAName = $CAName
        }
        
        #Connect to the Signing Jumphost
        $SigningSession = New-PSSession -ComputerName $SigningServer -Credential $CACredentials
        Write-Host('Establishing connection to Signing Server ' + $SigningServer)

        if($SigningSession){
            #Create Signing Request on OCSP Server
            Write-Host("Creating Signing Request for $CAName on " + $OCSPServer.Server)
            Invoke-Command -Session $OCSPSession -ArgumentList $settings -ScriptBlock $CreateSigningRequest

            #Copy CSR from OCSP Server
            Write-Host('Copying CSR from ' + $OCSPServer.Server)
            Copy-Item -FromSession $OCSPSession -Path $settings.rmCSRPath -Destination $settings.CSRPath
        
            #Clean/Create Tempfolder
            Write-Host("Creating tempfolder on $SigningServer")
            Invoke-Command -Session $SigningSession -ArgumentList $settings -ScriptBlock $cleanTempFolder

            #Copy CSR onto destination WinRM Server
            Write-Host("Copying CSR onto $SigningServer")
            Copy-Item -ToSession $SigningSession -Path $settings.CSRPath -Destination $settings.rmCSRPath

            #Sign the CSR File
            Write-Host("Signing $($settings.CSRPath) by " + $settings.CAName)
            Invoke-Command -Session $SigningSession -ArgumentList $settings -ScriptBlock $SignSigningRequest

            #Retrieve the signed certificate
            Write-Host('Copying signed certificate back to ' + $settings.CERPath)
            Copy-Item -FromSession $SigningSession -Path $settings.rmCERPath -Destination $settings.CERPath -Confirm:$false

            #Copy it onto the OCSP Machine
            Write-Host('Copying signed certificate onto ' + $OCSPServer.Server + ' at ' + $settings.rmCERPath)
            Copy-Item -ToSession $OCSPSession -Path $settings.CERPath -Destination $settings.rmCERPath -Confirm:$false

            #Import the signed certifciate
            Write-Host("Importing $($settings.rmCERPath) into LocalMachine Computer Certificates on " + $OCSPServer.Server)
            Invoke-Command -Session $OCSPSession -ArgumentList $settings -ScriptBlock $importSignedCertificate
        
            #Add network service permissions to the certificate
            Write-Host('Adding NETWORK Service Permissions on ' + $OCSPServer.Server)
            Invoke-Command -Session $OCSPSession -ScriptBlock $SetCertificatePermission
            
            #Disconnect from the WinRM Jumphost
            Write-Host("Close Remoting Session to $SigningServer")
            Disconnect-PSSession -Session $SigningSession | Out-Null
        }else{
            Write-Host('Could not establish connection to ' + $SigningServer)
        }

    }
    Write-Host('Removing expired certificates on ' + $OCSPServer.Server)
    Invoke-Command -Session $OCSPSession -ScriptBlock $cleanExpiredCertificates
    
    Write-Host('Close Remoting Session to ' + $OCSPServer.Server)
    Disconnect-PSSession -Session $OCSPSession | Out-Null
}
#endregion
