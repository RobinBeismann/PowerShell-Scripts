function Compare-ArrayList($InputObject,$Reference){
    $removed = $()
    $added = $()

    $added = $InputObject | Where-Object { !($Reference.Contains($_)) }
    $removed = $Reference | Where-Object { !($InputObject.Contains($_)) }
    
    $result = @{
                    Removed = $removed
                    Added = $added
              }

    if(($added.Count -gt 0) -or ($removed.Count -gt 0)){
        return $result
    }else{
        return $false
    }
}
