<#  
    This Script searches the proper harddisk

    1. Check for SSDs
        Yes:
            Sort all others out
            Jump to Step 3
        No: Jump to Step 3
    2. Check for NVMe
        Yes:
            Sort all others out
            Jump to Step 3
        No: Jump to Step 3
    3. Sort the Disks after Size and chose the smallest one

#>

function Show-TSBlockingMessage(){
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]$Title = "Information",
        [Parameter(Mandatory=$true)]$Message,
        [Parameter(Mandatory=$false)]$Timeout = 0
    )

    #Check if we're running inside a task sequence
    $IsTSEnv = $false
    try{
        New-Object -ComObject 'Microsoft.SMS.TSEnvironment' -ErrorAction 'Stop'
        $IsTSEnv = $true
    }catch{}

    #Check if we have to hide the progress UI as we would spawn in the background otherwise
    if(
        $IsTSEnv -and
        !$script:tsProgressUIClosed -and 
        ($progressUI = New-Object -ComObject Microsoft.SMS.TsProgressUI)
    ){                
        $progressUI = $progressUI.CloseProgressDialog()
        $script:tsProgressUIClosed = $true          
    }

    #Create the message
    $shellObj = New-Object -ComObject wscript.shell
    $shellObj.Popup($message,$timeout,$title,0x0) | Out-Null

}

try{
    $disks = Get-PhysicalDisk
}catch{
    Show-TSBlockingMessage -Title "Boot media out of date" -Message "Powershell Module for Disk Management not included, please update your boot media. This OS Image will install onto disk 0. If you still want to continue, either wait 120 seconds or press OK" -Timeout 120
    exit 0;
}

#Case 1, check if we got SSDs
if($ssds = $disks | Where-Object { $_.MediaType -eq "SSD" }){
    Write-Host("We've got SSDs in this system, sorting all others out.")
    $disks = $ssds
    Write-Host("Available SSDs: $($ssds | ForEach-Object { "`n`tModel: $($_.FriendlyName), Serial $($_.SerialNumber), Size: $($_.Size)" })")
}

if($ssds = $disks | Where-Object { $_.FriendlyName.ToLower().Contains("nvme") -and $_.Manufacturer.ToLower().Contains("nvme") }){
    Write-Host("We've got NVMes in this system, sorting all others out.")
    $disks = $ssds
    Write-Host("Available NVMes: $($ssds | ForEach-Object { "`n`tModel: $($_.FriendlyName), Serial $($_.SerialNumber), Size: $($_.Size)" })")
}

$selectedDisk = $disks | Sort-Object -Property Size | Select-Object -First 1
$selectedDiskNumber = $selectedDisk | Select-Object -ExpandProperty DeviceId

try{
    #Initialize TS Environment Object
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    $tsenv.Value('OSDDiskIndex') = $selectedDiskNumber

    Write-Host -Object "Selecting Disk: $($selectedDisk.FriendlyName), Serial $($selectedDisk.SerialNumber), Size: $($selectedDisk.Size)"
    Show-TSBlockingMessage -Title "Disk Selection" -Message "Selected Disk: $($selectedDisk.FriendlyName), Serial $($selectedDisk.SerialNumber), Size: $($selectedDisk.Size)" -Timeout 30
}catch{
    Write-Error("Error initializing TSEnvironment: $_")
    exit 1;
}
exit 0;
