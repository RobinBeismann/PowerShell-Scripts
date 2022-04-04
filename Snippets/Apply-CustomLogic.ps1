function Apply-CustomLogic($condition,$V1,$V2){
    $condition = $condition.ToLower()

    switch($condition){
        "like" {
            $string = '$V1 -like "*$V2*"'
        }

        "is" {
            $string = '$V1 -eq $V2'
        }

        "isnot" {
            $string = '$V1 -ne $V2'
        }

        "startswith" {
            $string = '$V1.StartsWith($V2)'
        }

        "notstartswith" {
            $string = '!($V1.StartsWith($V2))'
        }

        "endswith" {
            $string = '$V1.EndsWith($V2)'
        }

        "notendswith" {
            $string = '!($V1.EndsWith($V2))'
        }
    }

    if(     
            $string -and 
            ($sb = [scriptblock]::Create($string)) -and
            ($result = $sb.Invoke())
     ){
        Write-Verbose("Using Logic `"$condition`" on `"$V1`" versus `"$V2`", Result is: `"$result`"<br/>")
        return $result
    }else{
        Write-Verbose("Error, executing failed.")
        return $false
    }
}
