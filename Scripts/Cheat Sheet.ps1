# A random collection of powershell snippets

# Get Disk Usage for fix all disks
Get-WmiObject Win32_volume | Where-Object { $_.Capacity } | ForEach-Object { 
    $FreeSpace = $_.FreeSpace
    $FreeSpaceGB = [math]::Round($FreeSpace / 1024 / 1024 / 1024,1)
    $Capacity = $_.Capacity
    $CapacityGB = [math]::Round($Capacity / 1024 / 1024 / 1024,1)
    #Calculate
    $usage =  $FreeSpace / $Capacity * 100
    #Free
    $free = [math]::Round($usage,2)
    #Round
    $usage = [math]::Round(100 - $usage,2)

    [PSCustomobject]@{
        Name = $_.Name
        "Usage in %" = $usage
        "Free Space in %" = $free
        "Free Space (GB)" = $FreeSpaceGB
        "Capacity (GB)" = $CapacityGB
    } 
} | Out-GridView

# Enable AD Change Notification across sites
# Thanks Qasim Zaidi - saved from the retired technet
Get-ADObject -Filter 'objectcategory -eq "cn=site-link,cn=schema,cn=configuration,dc=yxlondk,dc=dk"' -SearchBase 'cn=configuration,dc=yxlondk,dc=dk' -Properties options | Set-ADObject -Replace @{options=$($_.options -bor 1)} 
