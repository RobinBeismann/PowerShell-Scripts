<#
CSV Example Content:
PrintServerOld;QueueNameOld;PrintServerNew;QueueNameNew
oldprintserver.contoso.com;Old Print Queue Name;newprintserver.contoso.com;New Print Queue Name

#>

#region Variables
$csvPath = "<path to CSV>"

#endregion
Write-Host("[$(Get-Date)] Importing CSV `"$csvPath`"..")
$printers = Import-Csv -Delimiter ";" -Path $csvPath
Write-Host("[$(Get-Date)] Finished importing CSV `"$csvPath`".")

Write-Host("[$(Get-Date)] Building name variations..")
$variations = @{}
$printers.GetEnumerator() | ForEach-Object {
    $oldHostnameSplit = $_.PrintServerOld.Split(".")[0]
    $variations["\\" + $oldHostnameSplit.ToLower() + "\" + $_.QueueNameOld.ToLower()] = $_
    $variations["\\" + $_.PrintServerOld.ToLower() + "\" + $_.QueueNameOld.ToLower()] = $_
}  
Write-Host("[$(Get-Date)] Finished building name variations.")

#Get existing network printers
Write-Host("[$(Get-Date)] Retrieving printers from WMI..")
$printers = Get-CimInstance -ClassName "Win32_Printer"
Write-Host("[$(Get-Date)] Finished retrieving printers from WMI.")
[array]$CurrentPrinters = @()

Write-Host("[$(Get-Date)] Mapping retrieved printers to new printers..")
$printers | Foreach-Object {
    if(
        $_.SystemName -and
        $_.ShareName -and
        ($systemName = $_.SystemName.ToLower()) -and
        ($shareName = $_.ShareName.ToLower()) -and
        ($combinedName = "$($systemName)\$shareName") -and
        ($variations.$combinedName)
    ){
        $CurrentPrinters += @{
            CombinedName = $combinedName
            PrinterMapping = $variations.$combinedName
            PrinterObject = $_
        }
    }
}
Write-Host("[$(Get-Date)] Finished mapping retrieved printers to new printers.")

if($CurrentPrinters.Count -gt 0){
    Write-Host("[$(Get-Date)] Processing printers..")
    $CurrentPrinters.GetEnumerator() | ForEach-Object {
        $PrinterMapping = $_.PrinterMapping
        $combinedName = $_.CombinedName
        $ProgressPreference = 'SilentlyContinue'

        if(Test-NetConnection -ComputerName $PrinterMapping.PrintServerNew -ErrorAction SilentlyContinue ){
            $newPrinterPath = "\\$($PrinterMapping.PrintServerNew)\$($PrinterMapping.QueueNameNew)"
            $newPrinterPathNonFQDN = "\\$($PrinterMapping.PrintServerNew.Split(".")[0])\$($PrinterMapping.QueueNameNew)"
            $newPrinterPathLowercase = "\\$($PrinterMapping.PrintServerNew)\$($PrinterMapping.QueueNameNew)"
            $newPrinterPathNonFQDNLowerCase = "\\$($PrinterMapping.PrintServerNew.Split(".")[0])\$($PrinterMapping.QueueNameNew)"
            $oldPrinterPath = "\\$($PrinterMapping.PrintServerOld)\$($PrinterMapping.QueueNameOld)"
            $oldPrinterPathNonFQDN = "\\$($PrinterMapping.PrintServerOld.Split(".")[0])\$($PrinterMapping.QueueNameOld)"
            $oldPrinterPathLowercase = "\\$($PrinterMapping.PrintServerOld)\$($PrinterMapping.QueueNameOld)"
            $oldPrinterPathNonFQDNLowerCase = "\\$($PrinterMapping.PrintServerOld.Split(".")[0])\$($PrinterMapping.QueueNameOld)"

            try{
                if(
                    ($existingMapping = Get-Printer | Where-Object {
                        ($_.Name.ToLower() -eq $newPrinterPathLowercase) -or
                        ($_.Name.ToLower() -eq $newPrinterPathNonFQDNLowerCase)
                    }) -and
                    ($existingWMIMapping = $printers | Where-Object {
                        ($_.Name.ToLower() -eq $newPrinterPathLowercase) -or
                        ($_.Name.ToLower() -eq $newPrinterPathNonFQDNLowerCase)
                    })
                ){  
                    Write-Host("[$(Get-Date)] Unmapping `"$newPrinterPath`"")
                    $existingMapping | Remove-Printer 
                }


                Write-Host("[$(Get-Date)] Mapping `"\\$($PrinterMapping.PrintServerOld)\$($PrinterMapping.QueueNameOld)`" to `"$newPrinterPath`"")
                Add-Printer -ConnectionName $newPrinterPath -ErrorAction Stop
                
                if(
                    $_.PrinterObject.Default -or
                    $existingWMIMapping.Default
                ){
                    Write-Host("[$(Get-Date)] Printer `"$($PrinterMapping.QueueNameNew)`" is supposed to be default Printer, setting now..")
                    $existingWMIMapping = Get-CimInstance -ClassName "Win32_Printer" | Where-Object {
                        ($_.Name.ToLower() -eq $newPrinterPathLowercase) -or
                        ($_.Name.ToLower() -eq $newPrinterPathNonFQDNLowerCase)
                    }
                    $null = $existingWMIMapping | Invoke-CimMethod -MethodName "SetDefaultPrinter"
                }
                
                if($oldPrinter = Get-Printer | Where-Object {
                        ($_.Name.ToLower() -eq $oldPrinterPathLowercase) -or
                        ($_.Name.ToLower() -eq $oldPrinterPathNonFQDNLowerCase)
                    }
                ){
                    Write-Host("[$(Get-Date)] Unmapping `"$oldPrinterPath`"")
                    $oldPrinter | Remove-Printer
                }
            }catch{
                Write-Host("[$(Get-Date)] Failed remapping `"$($PrinterMapping.PrintServerOld)\$($PrinterMapping.QueueNameOld)`" to `"$newPrinterPath`"! Error: $_")
            }
        }
    }
    Write-Host("[$(Get-Date)] Finished processing printers.")
}else{
    Write-Host("[$(Get-Date)] No printers to process.")
}
