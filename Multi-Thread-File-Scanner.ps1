#------------------------------------------------------------
#-----------------------Commandlet Start---------------------
#------------------------------------------------------------
Clear
Clear-Host

#------------------------------------------------------------
#------------------Configuration Parameters------------------
#------------------------------------------------------------

# Start Transcript
#Start-Transcript -Path "C:\Users\als696\Documents\test-scan.csv"
# Define Start location:
# TODO: Implement recursive path entries for BAU Reduction
$startPath = "X:\"

# Define Fim Group to be tested
$fimGroup = "res_"      #Write the Pim group as shown exactly in FIM

# Configure output Synchronized HashTable (WIP, Unused Currently)
$Configuration = [hashtable]::Synchronized(@{})
$Configuration.FilePath = "Y:\Results\Temp\"
$Configuration.CreatedFiles = @()

#Define Number of Threads to use (ENSURE THIS IS CORRECT THERE ARE NO INTERNAL LIMITERS)
$Maxthreads = 35

#------------------------------------------------------------
#--------------Initialize Worker-bee Script Block------------
#------------------------------------------------------------
$GetACLerrors = {
    #Define Script Block Arguements
    param(
    $foldertoAnalyse,
    $fimgroup,   #...IE: written in the form of Z:/folder1/ to find all child perms
    $Configuration
    )

    # Get all children items in the given directory
    $FolderChildren = Get-ChildItem $foldertoAnalyse -ErrorAction SilentlyContinue

    #$foldertoAnlyse | Write-Host

    # Checks if folder ACL's are accessible from current user 
    foreach($childPath in $FolderChildren){ 

        #will succeed if access is granted
        try{
            #------------------------------------------------------------
            #--------------------------Error Checks----------------------
            #------------------------------------------------------------

            # Checks for a missing Win_sys
            $ErrorCheck_winsys = Get-Acl -LiteralPath $childPath.FullName | Where-Object {$_.AccessToString -notlike "*Win_Sys*"} -ErrorAction Stop

            # Checks for missing FIM group
            #$ErrorCheck_fim = Get-Acl -LiteralPath $childPath.FullName | Where-Object {$_.AccessToString -notlike ("*"+$fimGroup+"*")} -ErrorAction Stop

            # Checks if there were errors detected for each case:
            if ($null -ne $ErrorCheck_winsys){
                "Accessible but there is no Win_sys_admins at,"+$childPath.FullName|Write-Host
            }

            #if ($null -ne $ErrorCheck_fim){
                #"Accessible but there is no FIM group found at,"+$childPath.FullName|Write-Host
            #}

        }

        # If There was an issue accessing these ACL's somehow...
        Catch{
            #TODO: Identify issues if possible
            "Can't Access ACL's. Exception '"+$_+"' at path, "+$childPath.FullName| Write-Host
        }
    }

}

#------------------------------------------------------------
#-------------------------Start Script-----------------------
#------------------------------------------------------------

#Print Start Time
$starttime = [datetime]::Now

#Creating RunSpace Pool:
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $Maxthreads, $SessionState, $Host)
$RunspacePool.Open()
$Jobs = New-Object System.Collections.ArrayList

#------------------------------------------------------------
#-------------------Initialize First Job---------------------
#------------------------------------------------------------

# Create Powershell runpool
$PowerShell = [powershell]::Create()
$PowerShell.RunspacePool = $RunspacePool

# Add in the script to the run pool instance created
$PowerShell.AddScript($GetACLerrors).AddArgument($startPath).AddArgument($fimGroup).AddArgument($configuration) | Out-Null

#update the Job Pool for Progress tracking
$JobObj = New-Object -TypeName PSObject -Property @{
	Runspace = $PowerShell.BeginInvoke()
    PowerShell = $PowerShell  
}
$Jobs.Add($JobObj) | Out-Null


#------------------------------------------------------------
#----------------Initialize Recursive Job--------------------
#------------------------------------------------------------

# Initialize Folder Counter (See below for debugging comments to enable).
$foldercounter = 0

# Intitialize Folder Tree
$EnumerationStarttime = [datetime]::Now
"Starting Enumeration of Directories"|Write-Host
$foldertree = (Get-ChildItem $startPath -Directory -Recurse -Force -ErrorAction SilentlyContinue | Select-Object FullName)

#Write time taken to enumerate
$EnumerationEndtime = [datetime]::Now
"Enumeration Time:  "+($EnumerationEndtime - $EnumerationStarttime) | Write-Host | ft
# Start Recursion

forEach($folder in $foldertree){
    #------------------------------------------------------------
    #------------------------Debugging Tools---------------------
    #------------------------------------------------------------

    # Uncomment to report on every folder scanned
    #"Checking folder, "+$folder | Write-Host 

    #Uncomment below to begin counting the number of folders scanned (Uncomment the report below)
    $foldercounter++

    #------------------------------------------------------------
    #----------------------Single Thread Option------------------
    #------------------------------------------------------------

    #TODO: Face lift function for new input (DOES NOT WORK CURRENTLY)
    #$folder.FullName | Get-ACL-Errors
    
    #------------------------------------------------------------
    #----------------------MultiThread option--------------------
    #------------------------------------------------------------
    # Create Powershell runpool
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool

    # Add in the script to the run pool instance created
    $PowerShell.AddScript($GetACLerrors).AddArgument($folder.FullName).AddArgument($fimGroup).AddArgument($configuration)  | Out-Null

    #update the Job Pool for Progress tracking
    $JobObj = New-Object -TypeName PSObject -Property @{
		Runspace = $PowerShell.BeginInvoke()
		PowerShell = $PowerShell  
    }

    $Jobs.Add($JobObj) | Out-Null
}

# Check for running Jobs and wait until all jobs are reported as complete.
while ($Jobs.Runspace.IsCompleted -contains $false) {
"Scan Still in progress..." |Write-Host
Start-Sleep -Seconds 1
}

#------------------------------------------------------------
#------------------------Debugging Tools---------------------
#------------------------------------------------------------

#Reports number of files scanned:
"Folders scanned = "+$folderCounter | Write-Host

#------------------------------------------------------------
#----------------------------Output--------------------------
#------------------------------------------------------------

#Write output time
"Scan Complete..." | Write-Host
$endtime = [datetime]::Now
"Scan Runtime:  "+($endtime - $starttime) | Write-Host | ft
#Stop-Transcript