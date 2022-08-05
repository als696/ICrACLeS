#------------------------------------------------------------
#-----------------------Commandlet Start---------------------
#------------------------------------------------------------
Clear
Clear-Host

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
    $errorList = @()
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
            #if ($null -ne $ErrorCheck_winsys){
            #    $errorList += ("Accessible but there is no Win_sys_admins at,"+$childPath.FullName)
            #}

            #if ($null -ne $ErrorCheck_fim){
                #$errorList += ("Accessible but there is no FIM group found at,"+$childPath.FullName)
            #}

        }

        # If There was an issue accessing these ACL's somehow...
        Catch{
            #TODO: Identify issues if possible
            $errorList += ("Can't Access ACL's. Exception '"+$_+"' at path, "+$childPath.FullName)
        }
    }

    # Find Free CSV and write to it:
    :loop Foreach($outPath in $Configuration.CreatedFiles){
        Try{
            Add-Content -Path $outPath -Value $errorList -ErrorAction Stop | Out-Null
            #success!
            break loop
        }
        catch{$null}
    }

}

#------------------------------------------------------------
#-----------------------Collect CSV List---------------------
#------------------------------------------------------------
$SharestoScan = Get-Content "$PSScriptRoot\Input\Shares.csv"
foreach($sharename in $SharestoScan){

    #------------------------------------------------------------
    #------------------Configuration Parameters------------------
    #------------------------------------------------------------

    # Define Start location:
    # TODO: Implement recursive path entries for BAU Reduction
    $startPath = $sharename+"\"

    "Starting "+$startPath+" scan" | Write-Host

    $resultName = $sharename.split("\")
    $resultname = $resultName[-1]

    #Define a path to save the results for each drive
    $ResultPath = "$PSScriptRoot\Results\"+$resultName+".csv"

    # Define Fim Group to be tested
    $fimGroup = "res_"      #Write the Pim group as shown exactly in FIM

    # Define Number of Threads to use (ENSURE THIS IS CORRECT THERE ARE NO INTERNAL LIMITERS)
    $Maxthreads = 35

    # Create an empty Temp csv for each availible thread to print to.
    $threadList = @()

    for($i = 100; $i -lt $Maxthreads+100; $i++)
    {
        $threadList += "$i"
    }
    foreach($csvname in $threadList){
        Set-Content -Path "$PSScriptRoot\Temp\$csvname.csv" -Value $null
    }

    # save a record of each created csv for use in a sync. Hashtable
    $csvnamelist = Get-ChildItem -Path "$PSScriptRoot\Temp\" -file | Sort-Object -Property fullName

    # Configure output Synchronized HashTable with a CSV list
    $Configuration = [hashtable]::Synchronized(@{})
    $Configuration.CreatedFiles = $csvnamelist.fullname

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

    $initialJobs = $jobs.Runspace.IsCompleted | Where-Object {$_ -contains $false}
    # Check for running Jobs and wait until all jobs are reported as complete.
    while ($Jobs.Runspace.IsCompleted -contains $false) {
        $jobsremaining = $jobs.Runspace.IsCompleted | Where-Object {$_ -contains $false}
        "Scan Still in progress..."+[math]::Round((($initialJobs.count-$jobsremaining.count)/$initialJobs.count)*100)+"% Complete. with "+$jobsremaining.count+ " remaining"|Write-Host
        Start-Sleep -Seconds 1
    }
    "Wrapping up..." |Write-Host

    $check = 0
    while($check -eq 0){
        $check = 1
        foreach($Path in $Configuration.CreatedFiles = $csvnamelist.fullname){
            Try{
                Get-Content -Path $Path | Out-Null
            }
            Catch{
                $check = 0
            }
        }
    }

    #------------------------------------------------------------
    #------------------------Debugging Tools---------------------
    #------------------------------------------------------------

    #Reports number of files scanned:
    "Folders scanned = "+$folderCounter | Write-Host

    #------------------------------------------------------------
    #----------------------------Output--------------------------
    #------------------------------------------------------------

    #Coalate results from All CSV's
    $results = @()
    $enum_errors = @()

    foreach($Path in $Configuration.CreatedFiles = $csvnamelist.fullname){
        Try{
            $results += Get-Content -Path $Path
        }
        Catch{
            $enum_errors += $Path
        }
    }

    $results | Set-Content $ResultPath


    #Write output time
    "Scan Complete..." | Write-Host
    $endtime = [datetime]::Now
    "Scan Runtime:  "+($endtime - $starttime) | Write-Host | ft
    #Stop-Transcript
    }