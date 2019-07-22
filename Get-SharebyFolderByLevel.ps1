<#
Get the top N level of the floder ,including the file and directories.
copy the file by level , level 1 then  level 2 ...
2019/05/16 add the function 
1.wirte down the log to Driver from job (in Memeory) 
2.Anylyze the Robocopy log to show failed copied file



2019/05/21  issue:Server BSOD 
limit the total current session for robocopy instanse when CPU/Memory/DIsk/Network useage is high
1)do not keep all the log to memory , remove -k parameter for receive job 
2)after copy finish , read the log from the log file instead of reading the global:result variable.-finished on 5/28
Bug: will failed by geting the folder as not permission ,try to catch this and save it to both windows log and log file
3)limit the robocpopy concurrence to 2 instance to avoid system resource busy,test will be on 5/22，can update by $global:ConcurrenceJobs

Optmize the performacne for Find-FailedFile.
Error haddlding, for null in get-childitem on folder level and ..

2019/05/23 Issue:Server BSOD didn't happen again on last try by limit the ConcurrenceJobs to 200 as well as didn't take anylyze the robolog from memmroy
add the /logfile parameter when start the robocopy instead of writeing the log from $results.joboutput.
check the jog which state is faied on function Monitor-job， even all the cmd command should show complete where there is error in the joboutput.- receive the job for details finished on 5/28
Covert-RobocopyLogObjFromJob  need to update if the job.out is not robocopy log, such as somekind of error which can not sent to anylyze-job.

2019/05/28 
Issue 1
if the folder level is less than global:maxlevel ,what will happen to get-sharefolderbylevel and copy-share.
ex if maxlevel is set to 4 , the folder only has 3 level , so it will be add the folder name and level 3 in the get-sharefolderbylevel
for copy-share, it will use /lev:2 which will incloud the folder it self and the file in that folder
so,don't need to modify the script

Issue 2
robocopyinstance id will not log into the mapping.csv -fixed

Issue 3
the anylyze-job will failed or stuck sometimes.
solution: remove Joboutput property from $result instead of reading the log from log file

Issue 4 
failed item will not able to find from the function find-failedfile ,will fix for next test.

Issue 5
this command will be slow if the global:alljobs is too much ,that will impact the currence job for copy-share -need to fixed.
$Runningjob=Get-Runningjob -alljobs $global:alljobs

new Feature:
1 ask user to increase the maxLevel if $global:ShareFlodercollection is less than 50.
2 rewrite the rocopy log source , reading it from the logfile instead of memory 


2019/05/29
Issue 1 anylyze-robocopysummary will rocongnize the robocopy log which is not finished, no summary.-fixed.

2019/06/17
issue 1 Copy foloder will take it parent path after driver name.ex ,when you copy d:\userdata1\user1 to destation ,the destatiaon will have userdata1 folder even you set the root path is d:\userdatae1-- fixed 


2019/06/24
issue 1 powershell will take huge amount of the memroy when runing
try to relase memroy by clear variable
        #release the memory usage for $Runningjob if not null 
        Clear-Variable -Name Runningjob

        #release the memory usage for $job if not null 
        Clear-Variable -Name job

Issue 2 check robocopy log  function need to update as sometime it is not easy for  script to find the fail item in 10 lines- -find all junction point. 
add /np parameter to robocopy "Specifies that the progress of the copying operation (the number of files or directories copied so far) will not be displayed." 
that could fix issued 2 ,need test


2019/06/25 add function Read-UserInput which will have timeout and default for read-host funciton .
the script will not stop for user's input as the count is small than 50 if you do batch copy job

2019/07/10  as get-runningjob take a lot of for get hundreds jobs status.
add the variable $global:BatchJobCount to start the  30 jobs each time which means the script will check the running job after start 30 robocopy instance instead 1 instance.

2019/07/20 fixed the issue for find-failitem.  to list all the error from the log.

#>
$global:ShareFlodercollection=@()
$global:MaxLevel=2
$global:EventLogSource="P23Migration"
$global:alljobs=@()
$global:GetChildItemErrorCollection=@()
$global:FailedJobsCollection=@()
$global:ConcurrenceJobs=200
$path="M:\Test_restore_latest\" 
$global:root="M:\Test_restore_latest"
$global:base="\\10.73.109.70\robotest"
$global:BatchJobCount=30
$global:basefolder=$global:base+$path.Substring($root.Length)
$global:robocopyinstanceID=0
$global:Job_SourceFiles_Mappings=@()
$global:AllFailedFiles=@()
$global:UnableFindLogJobs=@()
$starttime=Get-Date
$LogFolderName=$starttime.tostring("yyyy_MM_dd_HH_mm_ss")
$global:LogFolderPath="c:\temp\P23\"+$LogFolderName+"\"
if (!(Test-Path -Path $global:LogFolderPath))
{
New-Item -Path "c:\temp\P23\" -Name $LogFolderName -ItemType "directory"
}
$saaccount="XXX"
$secpasswd = ConvertTo-SecureString "********" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($saaccount, $secpasswd)




function Get-SharebyFolderByLevel
{
param (
[Parameter(Mandatory=$true,position=0)]
$Path,
[Parameter(Mandatory=$false,position=1)]
$currentlevel
)
    if($currentlevel -eq $null)
    {$CurrentLevel=0}
    else 
    {$CurrentLevel=$currentlevel}

    if ($CurrentLevel -lt $global:MaxLevel -and $CurrentLevel -ge 0)
    {
        try{
            "path is $path"
            $currentfolder=Get-ChildItem $path -ErrorAction Stop -ErrorVariable GetChildItemError
            $CurrentLevel++
                foreach($obj in $currentfolder)
                {
                "obj is {0}" -f  ($obj.fullname)
                $obj|Add-Member -NotePropertyName "FolderLevel" -NotePropertyValue $CurrentLevel
                $obj|Add-Member -NotePropertyName "Extendable" -NotePropertyValue $True
                $global:ShareFlodercollection+=$obj
        
                    if ($obj.gettype() -eq [System.IO.DirectoryInfo])
                        {
                        
                        "subfolder is {0}" -f $obj.FullName
                        "current level is {0} " -f $currentlevel
                        
                        Get-SharebyFolderByLevel -path ($obj.fullname) -currentlevel $CurrentLevel
                        
                        }
        
                }

        }
        Catch
        {
            #Get-ChildItem will failed due to permission, then we can not extend the subfolders. Copy this kind of floder without Level 1 parameter
            "catch error $path"
            $global:GetChildItemErrorCollection+=$GetChildItemError 
            $CurrentLevel=$global:MaxLevel 
            $currentfolder=Get-Item $path
            $FindFolderinGlobalCollction=$global:ShareFlodercollection|where-object {$_.fullname -eq $currentfolder.FullName }
            "catch folder is "
            $FindFolderinGlobalCollction|fl -Property *
            if ($FindFolderinGlobalCollction -ne $null){
                $FindFolderinGlobalCollction.folderlevel=$CurrentLevel
                $FindFolderinGlobalCollction.Extendable=$False
            }
            else {
                $currentfolder|Add-Member -NotePropertyName "FolderLevel" -NotePropertyValue $CurrentLevel
                $currentfolder|Add-Member -NotePropertyName "Extendable" -NotePropertyValue $False
                $global:ShareFlodercollection+=$currentfolder
                
                if ([System.Diagnostics.EventLog]::SourceExists($global:EventLogSource)){
                    #no need to create the source
                }
                else {
                    New-EventLog -LogName Application -Source $global:EventLogSource
                }
                Write-EventLog -LogName "Application" -Source $global:EventLogSource -EventID 1 -EntryType Error -Message "unable to get-childitem for $path." 
            }    
        }       
    }

}

function Monitor-Jobs
{
Param (
[Parameter(Mandatory=$true,position=0)]
$alljobs
)
$jobnotcompleted=$true
    while ($jobnotcompleted){
        foreach( $job in $global:alljobs){
            $job=get-job -id $job.id
            if ($job.state -eq 'Running')
            {
            $now=get-date -Format yyyy/MM/dd-HH:MM:ss
            "Now is {0},job id {1} is still running ,command is {2}" -f ($now,$job.id,$job.Command)
            Start-Sleep -Seconds 10
            Monitor-Jobs -alljobs $global:alljobs
            }
            elseif($job.state -eq 'Failed')
            {
                if($job.id -in  $global:FailedJobsCollection.id){
                    #do nothing as job alread in the collection,and receive-job for error detail.
                    
                }
                else{
                    #and receive-job for error detail.
                    $JobErrorDetail=receive-job $job.id
                    $job|Add-Member -NotePropertyName "JobErrorDetail" -NotePropertyValue $JobErrorDetail
                    $global:FailedJobsCollection+=$job
                }
                
            }
            else {
                #"do nothing as job is successful"
            }


                  
        }
        $jobnotcompleted=$false
    }
    

}

function Get-Runningjob
{
Param (
[Parameter(Mandatory=$true,position=0)]
$alljobs
)
$RunningjobCollection=@()
foreach( $job in $global:alljobs){
    $job=get-job -id $job.id
    if ($job.state -eq 'Running')
    {
        $RunningjobCollection+=$job
    }
    else {
        #do nothing
    }
                  
}
write-host -ForegroundColor green "Concurrenc job count is $($RunningjobCollection.count),Max is $global:ConcurrenceJobs, Batch Job Count is $global:BatchJobCount"
return $RunningjobCollection
}

function copy-share
{
    param (
        [Parameter(Mandatory=$true,position=0)]
        $share
    )
    if ($share.gettype() -eq [System.IO.DirectoryInfo])
    {
    #ex: source is H:\00_Tim Mon\NKE-WIN-GTW-P17_5240P4017\System Monitor Log.blg
    #$pathrootlength=$share.FullName.IndexOf(":")+1
    $pathrootlength=$global:root.Length
    $suffixslashlength=("\").length
    $source=$share.FullName
    $dest=$global:base+$share.FullName.Substring($pathrootlength,$share.FullName.Length-$pathrootlength)
    "source is {0} and dest is {1}" -f ($source,$dest)
    $level="/lev:2"
    $Logfile="/Log:$global:LogFolderPath"+$global:robocopyinstanceID+".txt"
        if ($lev -lt $global:MaxLevel)
        {
        "coyp floder robocopy {0} {1} /R:1 /W:1  /ZB /TEE /lev:2 /Log:File /NP" -f ($source,$dest,$level)
        #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /CopyALL  $args[2]} -ArgumentList ($source,$dest,$level)  # -AsJob 
        $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /TEE /CopyALL /NP  $args[2] $args[3]} -ArgumentList ($source,$dest,$level,$Logfile)
        $job|Add-Member -NotePropertyName "robocopyinstanceID" -NotePropertyValue $global:robocopyinstanceID
        $global:alljobs+=$job
        #as job will fail ,due to AmbiguousParameterSet
        # contorl the total count of robocopy process 

        }
        elseif ($lev -eq $global:MaxLevel)
        {
        "coyp floder robocopy {0} {1} /R:1 /W:1 /MT:32 /ZB /TEE /CopyALL  /S /E  /Log:File /NP" -f ($source,$dest)
        #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /CopyALL  /S /E} -ArgumentList ($source,$dest,$level)  # -AsJob 
        $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1 /MT:32 /ZB /TEE /CopyALL  /S /E /NP $args[3]} -ArgumentList ($source,$dest,$level,$Logfile)
        $job|Add-Member -NotePropertyName "robocopyinstanceID" -NotePropertyValue $global:robocopyinstanceID
        $global:alljobs+=$job
        #as job will fail ,due to AmbiguousParameterSet
        # contorl the total count of robocopy process
        } 
        else
        {
        #do nothing
        }
    
    }
    elseif (($share.gettype() -eq [System.IO.FileInfo] ) -and ($Lev -eq 1 ))
    {
    #ex: source is H:\00_Tim Mon\NKE-WIN-GTW-P17_5240P4017\System Monitor Log.blg
    #$pathrootlength=$share.FullName.IndexOf(":")+1
    $pathrootlength=$global:root.Length
    $suffixslashlength=("\").length
    $source=$share.FullName.Substring(0,$share.FullName.Length-$share.Name.Length-$suffixslashlength)
    $dest=$global:base+$share.FullName.Substring(2,$share.FullName.Length-$share.Name.Length-$pathrootlength-$suffixslashlength)
    $level="/lev:1"
    $filename=$share.Name
    "coyp file robocopy {0} {1} {2}  /R:1 /W:1 /MIR  /ZB  /NP {3}" -f  ($source,$dest,$filename,$level)
    #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" "$($args[2])" /R:1 /W:1   /ZB   $args[3]  } -ArgumentList ($source,$dest,$filename,$level)   #-asjob 
    $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" "$($args[2])" /R:1 /W:1 /MT:32  /ZB /CopyALL /NP $args[3]  } -ArgumentList ($source,$dest,$filename,$level) 
    $job|Add-Member -NotePropertyName "robocopyinstanceID" -NotePropertyValue $global:robocopyinstanceID
    $global:alljobs+=$job
    }
    else
    {
    #do nothing
    }
    $global:robocopyinstanceID++
    #release the memory usage for $job
    if($job -ne $null){
    Clear-Variable -Name job
    }
    
}
function  Covert-RobocopyLogObjFromJob{
    param (
        [Parameter(Mandatory=$true,position=0)]
        $RoboCopyJob
    )
    #----robocopy log analyze
$SplitLines=$SplitLines="^(-)+$"
$int=0
$SplitLinesLineNumber=@()
#$RoboCopyJob.Joboutput.length
foreach($line in $RoboCopyJob.Joboutput)
{
if ($line -match $SplitLines)
{
$SplitLinesLineNumber+=$int
}
$int++
}

$TitleStart=$SplitLinesLineNumber[0]+1
$TitleEnd=$SplitLinesLineNumber[1]-1
$RobocopyCommandStart=$SplitLinesLineNumber[1]+1
$RobocopyCommandEnd=$SplitLinesLineNumber[2]-1
$RobocopyDetailStart=$SplitLinesLineNumber[2]+1
$RobocopyDetailEnd=$SplitLinesLineNumber[3]-1
#if the robocopylog is not finished ,such as interrupt by usesr, skip to add Robocopy Summary
    if ($SplitLinesLineNumber.count -ge 4){
        $RobocopySummaryStart=$SplitLinesLineNumber[3]+1
        $RobocopySummaryEnd=$RoboCopyJob.Joboutput.count-1
        $robocopyinstance=[PSCustomObject]@{
            Title=$RoboCopyJob.Joboutput[$TitleStart..$TitleEnd]
            RobocopyCommand=$RoboCopyJob.Joboutput[$RobocopyCommandStart..$RobocopyCommandEnd]
            RobocopyDetail=$RoboCopyJob.Joboutput[$RobocopyDetailStart..$RobocopyDetailEnd]
            RobocopySummary=$RoboCopyJob.Joboutput[$RobocopySummaryStart..$RobocopySummaryEnd]
                    }
    }
    else {
        #robocopy log is not completete ,miss the summary part
        $robocopyinstance=[PSCustomObject]@{
            Title=$RoboCopyJob.Joboutput[$TitleStart..$TitleEnd]
            RobocopyCommand=$RoboCopyJob.Joboutput[$RobocopyCommandStart..$RobocopyCommandEnd]
            RobocopyDetail=$RoboCopyJob.Joboutput[$RobocopyDetailStart..$RobocopyDetailEnd]
            RobocopySummary="robocopy log is not completete ,miss the summary part"
                    }
    }




$robocopyinstance

}
function Analyze-RobocoyLog {
    param (
        [Parameter(Mandatory=$true,position=0)]
        $robocopyinstance
    )

    $start=0
    $AnylyzeRobocopyObj=@()
    $robocopycommandLength=$robocopyinstance.robocopycommand.count
    foreach ($robocopycommandline in $robocopyinstance.robocopycommand)
    {
    if(($start -in (0,2,5,7) ) -or ($start -eq $robocopycommandLength-1))
        {
            #this is the title for summary
            #($start -in (0,4,6) ) is for robocopy 2012
        }
    else
        {
        #write-host -ForegroundColor green  "log is $robocopycommandline and line is $start"    
        $FirstColonIndex=$robocopycommandline.indexof(":")
        $SubTotalCatagory=($robocopycommandline.substring(0,$FirstColonIndex-1)).trim()
        $SubTotalCatagoryDetail=($robocopycommandline.substring($FirstColonIndex+1)).trimstart()
            if( $SubTotalCatagory -like "Started")
            {
               
                $SubTotalCatagory=$SubTotalCatagory
                try{
                    $SubTotalCatagoryDetail=[datetime]$SubTotalCatagoryDetail 
                }
                catch{
                    #in Chinese OS , the date format is weekday month day which can not covert to datetime  which format should be weekday  day month
                    $ArraySubTotalCatagoryDetail=$SubTotalCatagoryDetail.split(" +")
                    $temp=$ArraySubTotalCatagoryDetail[1]
                    $ArraySubTotalCatagoryDetail[1]=$ArraySubTotalCatagoryDetail[2]
                    $ArraySubTotalCatagoryDetail[2]=$temp
                    $temp=$null
                    $temp=$ArraySubTotalCatagoryDetail[3]
                    $ArraySubTotalCatagoryDetail[3]=$ArraySubTotalCatagoryDetail[4]
                    $ArraySubTotalCatagoryDetail[4]=$temp
                    $NewArraySubTotalCatagoryDetail=$ArraySubTotalCatagoryDetail[1..($ArraySubTotalCatagoryDetail.length-1)]
                    $SubTotalCatagoryDetail=$ArraySubTotalCatagoryDetail -join " "
                    $SubTotalCatagoryDetail=[datetime]$SubTotalCatagoryDetail 
                    
                }

            }

        $RoboCopyCommandByCategory=[PSCustomObject]@{
                SubTotalCatagory = $SubTotalCatagory
                SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetail
                }
        $AnylyzeRobocopyObj+= $RoboCopyCommandByCategory
        }
                        
    $start++
    }
    

    $int=0
    foreach ($line in $robocopyinstance.RobocopySummary)
    {
        if($robocopyinstance.RobocopySummary -eq "robocopy log is not completete ,miss the summary part")
        {
            $RoboCopyResultByCategory=[PSCustomObject]@{
                SubTotalCatagory = "NA"
                SubTotalCatagoryDetailTotal="NA"
                SubTotalCatagoryDetailCopied="NA"
                SubTotalCatagoryDetailSkiped="NA"
                SubTotalCatagoryDetailMisMatched="NA"
                SubTotalCatagoryDetailFailed="NA"
                SubTotalCatagoryDetailExtras="NA"
            }
            $AnylyzeRobocopyObj+= $RoboCopyResultByCategory
            break
        }
        else {
            if(($int -eq 1) -or ($line -match '^\s*$'))
            {
                #this is the title for summary and first line is empty
            }           
            else
            {   
                #write-host "summary line is $line"  
                $FirstColonIndex=$line.indexof(":")
                #SubTotal=$line.substring(0,$FirstColonIndex-1)
                $SubTotalCatagory=($line.substring(0,$FirstColonIndex-1)).trim()
                
                if( $SubTotalCatagory -like "Ended")
                {
                    $SubTotalCatagoryDetail=($line.substring($FirstColonIndex+1)).trimstart()
                    try{
                        $SubTotalCatagoryDetail=[datetime]$SubTotalCatagoryDetail 
                    }
                    catch{
                        #in Chinese OS , the date format is weekday month day which can not covert to datetime  which format should be weekday  day month
                        $ArraySubTotalCatagoryDetail=$SubTotalCatagoryDetail.split(" +")
                        $temp=$ArraySubTotalCatagoryDetail[1]
                        $ArraySubTotalCatagoryDetail[1]=$ArraySubTotalCatagoryDetail[2]
                        $ArraySubTotalCatagoryDetail[2]=$temp
                        $temp=$null
                        $temp=$ArraySubTotalCatagoryDetail[3]
                        $ArraySubTotalCatagoryDetail[3]=$ArraySubTotalCatagoryDetail[4]
                        $ArraySubTotalCatagoryDetail[4]=$temp
                        $NewArraySubTotalCatagoryDetail=$ArraySubTotalCatagoryDetail[1..($ArraySubTotalCatagoryDetail.length-1)]
                        $SubTotalCatagoryDetail=$ArraySubTotalCatagoryDetail -join " "
                        $SubTotalCatagoryDetail=[datetime]$SubTotalCatagoryDetail 
                        
                    }
                    $RoboCopyResultByCategory=[PSCustomObject]@{
                        SubTotalCatagory = $SubTotalCatagory
                        SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetail
                    }
                }
                elseif ( $SubTotalCatagory -like "Speed")
                {
                #skip Speed summary line,such as
                #Speed :             2396302 Bytes/sec.
                #Speed :             137.117 MegaBytes/min.
                continue
                }
                elseif( $SubTotalCatagory -like "Times")
                {
                    $SubTotalCatagoryDetail=($line.substring($FirstColonIndex+1)).trimstart()
                    $SubTotalCatagoryDetail=$SubTotalCatagoryDetail -replace ('\s+', ' ')
                    $SubTotalCatagoryDetailByColumn = $SubTotalCatagoryDetail.Split(' ')
                    $SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetailByColumn[0]
                    $SubTotalCatagoryDetailCopied=$SubTotalCatagoryDetailByColumn[1]
                    $SubTotalCatagoryDetailFailed=$SubTotalCatagoryDetailByColumn[2]
                    $SubTotalCatagoryDetailExtras=$SubTotalCatagoryDetailByColumn[3]
                    $RoboCopyResultByCategory=[PSCustomObject]@{
                        SubTotalCatagory = $SubTotalCatagory
                        SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetailTotal
                        SubTotalCatagoryDetailCopied=$SubTotalCatagoryDetailCopied
                        SubTotalCatagoryDetailFailed=$SubTotalCatagoryDetailFailed
                        SubTotalCatagoryDetailExtras=$SubTotalCatagoryDetailExtras
                    }
                }
                else{
                    $SubTotalCatagoryDetail=$line.split(":")[1].trimstart()
                    #replace the space infront of the unit, sucha as 3.91 t 12.5 m
                    if($SubTotalCatagoryDetail -match '\d\s\w')
                    {
                        $matches=([regex]'\d\s\w').Matches($SubTotalCatagoryDetail)
                        foreach ($m in $matches)
                        {
                        $m_RemoveSpaceInMiddle=$m.value -replace (' ','')
                        $SubTotalCatagoryDetail=$SubTotalCatagoryDetail -replace ($m.value,$m_RemoveSpaceInMiddle)
                        }
                    }
                    #replace multe white space to one for further spilt string by space
                    $SubTotalCatagoryDetail=$SubTotalCatagoryDetail -replace ('\s+', ' ')
                    $SubTotalCatagoryDetailByColumn = $SubTotalCatagoryDetail.Split(' ')
                    $SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetailByColumn[0]
                    $SubTotalCatagoryDetailCopied=$SubTotalCatagoryDetailByColumn[1]
                    $SubTotalCatagoryDetailSkiped=$SubTotalCatagoryDetailByColumn[2]
                    $SubTotalCatagoryDetailMisMatched=$SubTotalCatagoryDetailByColumn[3]
                    $SubTotalCatagoryDetailFailed=$SubTotalCatagoryDetailByColumn[4]
                    $SubTotalCatagoryDetailExtras=$SubTotalCatagoryDetailByColumn[5]
        
                    $RoboCopyResultByCategory=[PSCustomObject]@{
                        SubTotalCatagory = $SubTotalCatagory
                        SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetailTotal
                        SubTotalCatagoryDetailCopied=$SubTotalCatagoryDetailCopied
                        SubTotalCatagoryDetailSkiped=$SubTotalCatagoryDetailSkiped
                        SubTotalCatagoryDetailMisMatched=$SubTotalCatagoryDetailMisMatched
                        SubTotalCatagoryDetailFailed=$SubTotalCatagoryDetailFailed
                        SubTotalCatagoryDetailExtras=$SubTotalCatagoryDetailExtras
                    }
                }
                $AnylyzeRobocopyObj+= $RoboCopyResultByCategory
            } 
        }
        $int++
    }
    $AnylyzeRobocopyObj
}
function Find-FailedFile {
    param (
        [Parameter(Mandatory=$true,position=0)]
        $robocopyinstance
    )
   $RobocopyDetail=$robocopyinstance.RobocopyDetail
   #$matches=([regex]'ERROR: ').Matches($robocopyinstance.RobocopyDetail)
   $FailFiles=@()
   $i=0
   foreach ($line in $RobocopyDetail)
   {
       if ($line -match 'ERROR: ')
       {
            write-host "Error line is $line"
            $endline=$i
            if($i -eq 0)
            {$j=$i
            }
            else
            {$j=$i-1
            }

            #write-host "endline is $i "
                for($j;($j -ge ($i-10) -and $j -ge 0);$j--)
                {
                    
                    if(($RobocopyDetail[$j] -match 'ERROR (\d)+ '))
                        {
                        $StartLine=$j
                        #"start line is $j"
                        $FailFileEntryLine=$RobocopyDetail[$StartLine..$endline]
                       # write-host "FailFileEntryLine is $FailFileEntryLine"
                       # write-host "jjjj is $RobocopyDetail[$j]"
                       # Read-Host -Prompt "check for jjjj"
                        break
                        }
                    elseif(($StartLine -eq $null) -and ($j -ge ($i-10)))
                    {
                    $FailFileEntryLine=$null
                    }
                    else
                    {
                    #keep search the netxt
                    }
                }
                
                if ($FailFileEntryLine -ne $null)
                {
                $FailFileEntryLine=$RobocopyDetail[$StartLine..$endline]
                $FailFileEntryIndex=0
                    foreach ($line in $FailFileEntryLine)
                    {
                        #2019/05/14 21:58:42 ERROR 31 (0x0000001F) 
                        if ($line -match 'ERROR (\d)+')
                        {        
                        $FilePathmatches=([regex]'\\(((?![<>:"/\\|?*]).)+((?<![ .])\\)?)*.*').matches($line)
                        $FilePath= $FilePathmatches[0].value
                        #05/15 keep find error reason
                            $FailFileEntry=[PSCustomObject]@{
                            FilePath=$filepath
                            FileDeail=$line
                            FileError=$FailFileEntryLine[$FailFileEntryIndex+1]
                            }
                        
                            #write-host "fail is $FailFileEntry"
                        }
                        $FailFileEntryIndex++
                    }
                  }
                  else
                  {
                     $FailFileEntry=[PSCustomObject]@{
                     FilePath="unable to find error entry in 10 lines,please manually check the log"
                     }
                  }
            $FailFiles+=$FailFileEntry
         }
         elseif (($FailFiles -eq $null) -and ($i -eq $RobocopyDetail.count-1))
         {
             $FailFileEntry=[PSCustomObject]@{
             FilePath="unable to find error,please manually check the log"
             }
         $FailFiles+=$FailFileEntry
         }  
         else
         {
         #keep search for the next line
         }
   $i++
   } 
   return $FailFiles
}

function Anylyze-RobocopySummary
{
    param (
        [Parameter(Mandatory=$true,position=0)]
        $RoboCopyJob
        
    )
    $LogPath="$global:LogFolderPath"+"$($RoboCopyJob.robocopyinstanceID)"+".txt"
    write-host  "Logpath is  $LogPath"
    if (Test-path $LogPath )
    {
        $RobocopyLogFile=get-content -Path $LogPath
        $RoboCopyJob|Add-Member -NotePropertyName Joboutput -NotePropertyValue $RobocopyLogFile 
        if($RoboCopyJob.psobject.Properties.match("LogReachable").count)
        {
            $RoboCopyJob.LogReachable=$True
        }
        else{
            $RoboCopyJob|Add-Member -NotePropertyName LogReachable -NotePropertyValue $True
        }
        
        $RoboCopyInstance=Covert-RobocopyLogObjFromJob -RoboCopyJob $RoboCopyJob
    #write down the log in to file before anylyze

    $AnylyzeRobocopyObj=Analyze-RobocoyLog -robocopyinstance $RoboCopyInstance
    write-host "AnylyzeRobocopyObj is $($AnylyzeRobocopyObj)"
    $AnylyzeRobocopyObj
    if($AnylyzeRobocopyObj[5].SubTotalCatagory -eq "NA" )
    {
        #robocooy log is not complete ,skip 
        $AnylyzeRobocopySummay=[PSCustomObject]@{
            SourceFolder=$AnylyzeRobocopyObj[1].SubTotalCatagoryDetailTotal
            CopyStartTime=$AnylyzeRobocopyObj[0].SubTotalCatagoryDetailTotal
            SourceFile=$AnylyzeRobocopyObj[3].SubTotalCatagoryDetailTotal
            CopyEndTime="NA"
            CopyStatus="NotFinished"
            jobid=$robocopyjob.jobid
            }
            write-host -ForegroundColor Magenta"robocopy :  NotFinished”
            $AnylyzeRobocopySummay|ft
    }
    else {
            if(  $AnylyzeRobocopyObj[6].SubTotalCatagoryDetailFailed -ne 0 )
            {
                $AnylyzeRobocopySummay=[PSCustomObject]@{
                SourceFolder=$AnylyzeRobocopyObj[1].SubTotalCatagoryDetailTotal
                CopyStartTime=$AnylyzeRobocopyObj[0].SubTotalCatagoryDetailTotal
                SourceFile=$AnylyzeRobocopyObj[3].SubTotalCatagoryDetailTotal
                CopyEndTime=$AnylyzeRobocopyObj[9].SubTotalCatagoryDetailTotal
                CopyStatus="Failed"
                jobid=$robocopyjob.jobid
                }
                write-host -ForegroundColor red "robocopy ： Failed Detail is ”
                $AnylyzeRobocopySummay|Ft

                #find failed filse fuction,need testing. 
                $JobFailedFiles=Find-FailedFile -robocopyinstance $RoboCopyInstance 
                write-host -ForegroundColor red "robocopy ： Failed Files is ”
                $JobFailedFiles
                $FailefileSummary=[pscustomobject]@{
                AnylyzeRobocopySummay=$AnylyzeRobocopySummay
                JobFailedFiles=$JobFailedFiles
                }
                $global:AllFailedFiles+=$FailefileSummary

            }
            else 
            {
                $AnylyzeRobocopySummay=[PSCustomObject]@{
                SourceFolder=$AnylyzeRobocopyObj[1].SubTotalCatagoryDetailTotal
                CopyStartTime=$AnylyzeRobocopyObj[0].SubTotalCatagoryDetailTotal
                SourceFile=$AnylyzeRobocopyObj[3].SubTotalCatagoryDetailTotal
                CopyEndTime=$AnylyzeRobocopyObj[9].SubTotalCatagoryDetailTotal
                CopyStatus="OK"
                jobid=$robocopyjob.jobid
                }
                write-host -ForegroundColor Green "robocopy :  Successed”
                $AnylyzeRobocopySummay|ft
            }
            
            if($AnylyzeRobocopySummay.SourceFile -eq "*.*")
            {
            #$path="$global:LogFolderPath"+"job_"+($robocopyjob.jobid)+".txt"
                $Job_SourceFiles_Mapping=[pscustomobject]@{
                jobid=$robocopyjob.jobid
                SourceFolder=($AnylyzeRobocopySummay.SourceFolder)
                SourceFiles="allFiles"
                robocopyinstanceID=$robocopyjob.robocopyinstanceID
                }
            
            }
            else
            {
            #$path="$global:LogFolderPath"+"job_"+($robocopyjob.jobid)+".txt"
                $Job_SourceFiles_Mapping=[pscustomobject]@{
                jobid=$robocopyjob.jobid
                SourceFolder=($AnylyzeRobocopySummay.SourceFolder)
                SourceFiles=$AnylyzeRobocopySummay.SourceFile
                robocopyinstanceID=$robocopyjob.robocopyinstanceID
                }

            }
            #write the log to logfolder from $robocopyjob.Joboutput cancelled as it was taken by robocopy command.
            #$robocopyjob.Joboutput >$path
            $global:Job_SourceFiles_Mappings+=$Job_SourceFiles_Mapping
        }
    }
    else {
        write-host -ForegroundColor yellow "robocopy ： Failed to Anylyze due to Logfile not available ”
        write-host "$RoboCopyJob is "
        $RoboCopyJob
        if($RoboCopyJob.psobject.Properties.match("LogReachable").count)
        {
            $RoboCopyJob.LogReachable=$False
        }
        else{
            $RoboCopyJob|Add-Member -NotePropertyName LogReachable -NotePropertyValue $False
        }
        $global:UnableFindLogJobs+=$RoboCopyJob
    }
}
    

function Read-UserInput
{
    param(
    [parameter(mandatory=$False)]
    $timeout=3,
    [parameter(mandatory=$False)]
    $WaitMilliseconds=100,
    [parameter(mandatory=$True)]
    $message
    
    )
#add-type -AssemblyName System.Windows.Forms
$defaultValue="Q"
$int=0
Write-host -nonewline "$($message):"
$arrayUserinput=@()
$count=$timeout*1000/$WaitMilliseconds
$EnterCountNumber=0
do{
             start-sleep -Milliseconds $WaitMilliseconds
             <#write "int is $int ,count it $count"
             if($int -ge $count)
             {
             #Write-host -NoNewline $default
             return $default
             }
             else #>
             if($host.ui.RawUi.KeyAvailable)
             {
             $userinput = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp")
             #$userinput.virtualkeycode
             #13 means  press enter
                 if($userinput.virtualkeycode -eq '13' )
                 {
                     if( $EnterCountNumber -ge 1)
                     {
                     #"userinput is $userinput"
                     $allUserInput=[system.String]::Join("", $arrayUserInput)
                     #Write-host -NoNewline "$allUserInput"
                     return $allUserInput
                     }
                 $EnterCountNumber++                
                 }
                 else
                 {
                 $arrayUserInput+=$userinput.character
                    
                 }
             }
             $int++

}
while($int -le $count)

if($allUserInput -eq $null)
{
Write-host -NoNewline $default
return $defaultValue
}

}





    




write-host -ForegroundColor Cyan "---Get-SharebyFolderByLevel---"
Get-SharebyFolderByLevel -path $path
if ($global:ShareFlodercollection.count -le 50 )
{   
    $userinput=$null
    $regex=('[0-9]{1,2}')
    $regex2=('[q|Q]')
    while($true)
    {
        if($userinput -eq $null)
        {
         
            $userinput = Read-UserInput -message   "current folder level is $global:MaxLevel , swith it to a big number will reduce the copy time. recommendiation is $($global:MaxLevel+1) or Press Q to skip the reseting the folder level" 
        }
        else {
            if($userinput -match $regex2)
            {
                write-host "current folder level is still  $global:MaxLevel"
                break 
            }
            elseif ($userinput -match $regex)
            {
                if($userinput -le $global:MaxLevel ){
                    $userinput = Read-UserInput -message  "the new folder level is $userinput smaller than current folder level is $global:MaxLevel , swith it to a big number will reduce the copy time. recommendiation is $($global:MaxLevel+1)"
                }
                else {
                    $global:MaxLevel=$userinput
                    write-host "current folder level changed to  $global:MaxLevel"
                    #Reset the $global:ShareFlodercollection by increased  the MaxLevel
                    $global:ShareFlodercollection=@()
                    Get-SharebyFolderByLevel -path $path
                    break                   
                }
            }
            else {
                $userinput = Read-UserInput -message  "input is not valid ,please input the number between 1-99"
            } 
        }
    }
 
}
else {
    #do nothing
}



#$global:ShareFlodercollection.count
#$global:ShareFlodercollection|select fullname,folderlevel
#$basefolder

write-host -ForegroundColor Cyan "---CopyFolderByLevel---"
#robocopy $path $basefolder   /E /S  /create /mir
$Currentitem=1
for ($Lev=1;$lev -le $global:MaxLevel;$lev++)
{
    foreach ($share in ($global:ShareFlodercollection|where {$_.folderlevel -eq $lev}))
    {
        #limit the concurrence of the robocopy job
        Write-Host -ForegroundColor yellow "total copy itme is $($global:ShareFlodercollection.count) ,now is copying item $Currentitem"
        if($Currentitem % ($global:BatchJobCount) -eq 0){
            $Runningjob=Get-Runningjob -alljobs $global:alljobs
            $Runningjobcount=$Runningjob.count
            if($Runningjobcount -le $global:ConcurrenceJobs)
            {
                copy-share -share $share
            }
            else {
                while($True){
                    $Runningjob=Get-Runningjob -alljobs $global:alljobs
                    $Runningjobcount=$Runningjob.count
                    if($Runningjobcount -lt $global:ConcurrenceJobs)
                    {
                        break
                    }
                    Start-Sleep 10
                    
                }
                copy-share -share $share    
            }
        }
        else
        {
            copy-share -share $share
        }

        $Currentitem++
        #release the memory usage for $Runningjob
       if($Runningjob -ne $null)
        {Clear-Variable  Runningjob}
    }
}

write-host -ForegroundColor Cyan "---Monitor the Job once all Robocopy is not running--"
Monitor-Jobs -alljobs $global:alljobs

$endtime=Get-Date
"total copytime is $(($endtime-$starttime).totalseconds) seconds"
write-host -ForegroundColor Cyan "---receive all Robocopy job--"
$results=@()
foreach ($j in $global:alljobs)
{
$result=[PSCustomObject]@{
Jobid = $j.Id
robocopyinstanceID=$j.robocopyinstanceID
#Joboutput=receive-job -Job $j -keep
#Joboutput=receive-job -Job $j
        }
$results+= $result
#receive all job to recycle the memroy 
receive-job -Job $j >$null
}






write-host -ForegroundColor Cyan "---Anylyze Each Job output---"
#Anylyze Each Job output
#$jobstatus=get-content "C:\work\script\Migrate-ShareFolder\robocopylogSample.txt"
#$job1=[PSCustomObject]@{
#    Name = "job1"
#    Joboutput=$jobstatus
#}
#$results+=$job1

foreach ($RoboCopyJob in $results)
{ 
    Anylyze-RobocopySummary -RoboCopyJob  $RoboCopyJob 
}

write-host -ForegroundColor Cyan "---Summary---"

#write down the relation betwen job and source file(s)
$global:Job_SourceFiles_Mappings|export-csv -Path ($global:LogFolderPath+"Job_SourceFiles_Mappings.csv")
$endtime=Get-Date
"total runtime(including Anylyze log) is $(($endtime-$starttime).totalseconds) seconds"

$TotalCountofFiledFiles=0
foreach ($obj in $global:AllFailedFiles)
{
$JobFailedFilesCount=$obj.jobfailedFiles.filepath.count
$TotalCountofFiledFiles+=$JobFailedFilesCount
}
"All Failed Files count is $TotalCountofFiledFiles. Details  are  " 
$global:AllFailedFilesDetail=$global:AllFailedFiles|select -ExpandProperty  JobFailedFiles

$global:AllFailedFilesDetailLogPath="$global:LogFolderPath"+"robocopyAllFailedCopiedFilesDetail.txt"
$global:AllFailedFilesDetail >$global:AllFailedFilesDetailLogPath

$GetChildItemErrorCollectionLogPath="$global:LogFolderPath"+"GetChildItemErrorCollection.txt"
$global:GetChildItemErrorCollection >$GetChildItemErrorCollectionLogPat

$FailedJobsCollectionCollectionLogPath="$global:LogFolderPath"+"FailedJobsCollection.txt"
$global:FailedJobsCollection >$FailedJobsCollectionCollectionLogPath

$UnableFindLogJobsLogPath="$global:LogFolderPath"+"UnableFindLogJobs.txt"
$global:UnableFindLogJobs >$UnableFindLogJobsLogPath

"==========================================================="
"AllFailedCopiedFilesDetail  are:"
$global:AllFailedFilesDetail 
"==========================================================="
"GetChildItemErrorCollection  are:"
$global:GetChildItemErrorCollection
"==========================================================="
"FailedJobsCollection  are:"
$global:FailedJobsCollection
"==========================================================="
"UnableFindLogJobs  are:"
$global:UnableFindLogJobs