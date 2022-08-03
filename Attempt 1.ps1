function Get-ACL-Errors{
    #Define pipeable parameter list
    param(
    [Parameter(ValueFromPipeline=$true)]
    $CurrentPath #IE: in the form of Z:\folder1\
    #$SharePerm
    )
    
    try{
        $ErrorCheck = Get-Acl | Where-Object {$_.AccessToString -notlike "*Win_Sys_Admins*" -or "*phimi"} -ErrorAction Stop
    }
    # If There was an issue accessing these ACL's somehow...
    Catch{
        #Todo - Identify issues
        "Cant access ACL's at, "+(convert-path $currentPath)| Write-Host
    }
    
    # If there is an error, the above will not return null, then print the path of the error
    #TODO: If there is an access error, fix it before subsequent run
    if ($null -ne $ErrorCheck){
        foreach($issue in $ErrorCheck){
            $pathName = convert-path $issue.Path
            try{
                $echooff = Get-ChildItem $pathName -ErrorAction Stop
                #Access is not denied to the share, check what is missing:
                if($issue.AccessToString -like "*Win_Sys*"){
                    "Accessible but there is no Win_Sys_Admin found at,"+$pathName|Write-Host
                }
                else{
                    "Accessible but there is no user perms found at,"+$pathName|Write-Host
                }
            }
            Catch{
                #Access is denied, hence TODO: Build Smarts
                ("Access is denied at,"+$pathName+", The Control groups are: "+$issue.AccessToString)|Write-Host
            }
        }
    }
    
}

# Start Script

Clear
Clear-Host
$starttime = [datetime]::Now
#Please specify atleast the name of the group
# Please specify the name of the path to be scanned.
$startPath = "S:\FakeZ"
#TODO: Implement magic to get $currentpath recursively -> Extension, thread it if required

#TODO: Launch first Job using base job
$firstRun = $startpath+"\*" | Get-ACL-Errors

#TODO: launch Recusively all subsequent Jobs
$oop = Get-ChildItem $startPath"\*" -Recurse -ErrorAction SilentlyContinue| Get-ACL-Errors

$finishtime = [datetime]::Now
