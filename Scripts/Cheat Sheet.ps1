#A random collection of powershell snippets

#Get Disk Usage for fix all disks
Get-WmiObject Win32_volume | Where-Object { $_.Capacity } | ForEach-Object { 
    $FreeSpace = $_.FreeSpace
    $Capacity = $_.Capacity
    #Calculate
    $usage =  $FreeSpace / $Capacity * 100
    #Round
    $usage = [math]::Round($usage,2)
    #Free
    $free = [math]::Round(100 - $usage,2)

    [PSCustomobject]@{
        Name = $_.Name
        Usage = $usage
        Free = $free
    } 
} | Out-GridView
