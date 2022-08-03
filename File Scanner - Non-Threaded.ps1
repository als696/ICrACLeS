function Get-ACL-Errors{
    #Define pipeable parameter list
    param(
    [Parameter(ValueFromPipeline=$true)]
    $foldertoAnalyse   #...IE: written in the form of Z:/folder1/ to find all child perms
    )
    #$fimGroup = "*res_*"
    $FolderChildren = Get-ChildItem $foldertoAnalyse -ErrorAction SilentlyContinue

    # Checks if folder ACL's are accessible from current user 
    foreach($childPath in $FolderChildren){   
        #$childpath.fullname | Write-Host
        #will succeed if access is granted
        try{
            # Checks for a missing Win_sys
            $ErrorCheck_winsys = Get-Acl $childPath.FullName | Where-Object {$_.AccessToString -notlike "*Win_Sys*"} -ErrorAction Stop #-xor $_.AccessToString -notlike $fimGroup
            # Checks for missing FIM group
            #$ErrorCheck_fim = Get-Acl $childPath.FullName | Where-Object {$_.AccessToString -notlike $fimGroup} -ErrorAction Stop #-xor $_.AccessToString -notlike $fimGroup
            # Statements to print/act on errors
            if ($null -ne $ErrorCheck_winsys){
                "Accessible but there is no Win_sys_admins at,"+$childPath.FullName|Write-Host
            }
            #if ($null -ne $ErrorCheck_fim){
            #    "Accessible but there is no FIM group found at,"+$childPath.FullName|Write-Host
            #}
        }
        # If There was an issue accessing these ACL's somehow...
        Catch{
            #Todo - Identify issues
            "Cant access ACL's at, "+$childPath.FullName| Write-Host
        }
    }

}



Clear
Clear-Host
#Print Start Time
[datetime]::Now | Write-Host

# Please specify the name of the path to be scanned.
$startPath = "S:"

#Set up First job - just the top level folder
$firstFolder = $startPath | Get-ACL-Errors 

#Set up recursive Job - Everything else underneath
#$foldercounter = 0

$folderpathway = Get-ChildItem $startPath -directory -recurse -ErrorAction SilentlyContinue
forEach($folder in $folderpathway){
    #Debug tools:
    #$foldercounter++
    #Checking folder, "+$folder.FullName | Write-Host 

    $folder.FullName | Get-ACL-Errors
}
#Reports number of files scanned:
#$folderCounter | Write-Host

#Write output time
[datetime]::Now | Write-Host
