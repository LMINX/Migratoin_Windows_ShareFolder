<#
Get the top N level of the floder ,including the file and directories.

copy the file by level , level 1 then  level 2 ...
#>
$global:ShareFlodercollection=@()
$global:MaxLevel=4
$global:alljobs=@()
$path="H:\00_Tim Mon" 
$root="H:"
$base="\\rnlq03404hv001\RobocopyMultiThread"
$basefolder=$base+$path.Substring($root.Length)
$saaccount="nike\sa.gliu10"
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
    else {$CurrentLevel=$currentlevel}

    if ($CurrentLevel -lt $global:MaxLevel -and $CurrentLevel -ge 0)
    {

    $currentfolder=Get-ChildItem $path  
    $CurrentLevel++
        foreach($obj in $currentfolder)
        {
        $obj|Add-Member -NotePropertyName "FolderLevel" -NotePropertyValue $CurrentLevel
        $global:ShareFlodercollection+=$obj

            if ($obj.gettype() -eq [System.IO.DirectoryInfo])
                {
                
                $obj.FullName
                "current lever is {0} " -f $currentlevel
                
                Get-SharebyFolderByLevel -path ($obj.fullname) -currentlevel $CurrentLevel
                
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
                  
        }
        $jobnotcompleted=$false
    }


}

function  Covert-RobocopyLogObjFromJob{
    param (
        [Parameter(Mandatory=$true,position=0)]
        $RoboCopyJob
    )
    #----robocopy log analyze
$SplitLines="---"
$int=0
$SplitLinesLineNumber=@()
$RoboCopyJob.Joboutput.length
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
$RobocopySummaryStart=$SplitLinesLineNumber[3]+1
$RobocopySummaryEnd=$RoboCopyJob.Joboutput.count-2

$robocopyinstance=[PSCustomObject]@{
Title=$RoboCopyJob.Joboutput[$TitleStart..$TitleEnd]
RobocopyCommand=$RoboCopyJob.Joboutput[$RobocopyCommandStart..$RobocopyCommandEnd]
RobocopyDetail=$RoboCopyJob.Joboutput[$RobocopyDetailStart..$RobocopyDetailEnd]
RobocopySummary=$RoboCopyJob.Joboutput[$RobocopySummaryStart..$RobocopySummaryEnd]
        }

$robocopyinstance

}
function Analyze-RobocoyLog {
    param (
        [Parameter(Mandatory=$true,position=0)]
        $robocopyinstance
    )
    $int=0
    $AnylyzeRobocopyObj=@()
    foreach ($line in $robocopyinstance.RobocopySummary)
    {
        if($int -eq 0 )
        {
            #this is the title for summary
        }
        else 
        {   
            $SubTotal=$line.split(":")
            $SubTotalCatagory=$subtotal[0]
            $SubTotalCatagoryDetail=$subtotal[1]
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
                SubTotalCatagoryDetailTotal=$SubTotalCatagoryDetailByColumn[0]
                SubTotalCatagoryDetailCopied=$SubTotalCatagoryDetailByColumn[1]
                SubTotalCatagoryDetailSkiped=$SubTotalCatagoryDetailByColumn[2]
                SubTotalCatagoryDetailMisMatched=$SubTotalCatagoryDetailByColumn[3]
                SubTotalCatagoryDetailFailed=$SubTotalCatagoryDetailByColumn[4]
                SubTotalCatagoryDetailExtras=$SubTotalCatagoryDetailByColumn[5]
            }
            $AnylyzeRobocopyObj+= $RoboCopyResultByCategory
        }
        $int++
    }
    $AnylyzeRobocopyObj
}



write-host -ForegroundColor "---Get-SharebyFolderByLevel---"
Get-SharebyFolderByLevel -path "H:\00_Tim Mon" 
#$global:ShareFlodercollection.count
#$global:ShareFlodercollection|select fullname,folderlevel
#$basefolder

write-host -ForegroundColor "---CopyFolderByLevel---"
#robocopy $path $basefolder   /E /S  /create /mir
$starttime=Get-Date
for ($Lev=1;$lev -le $global:MaxLevel;$lev++)
{

    foreach ($share in ($global:ShareFlodercollection|where {$_.folderlevel -eq $lev}))
    {

    if ($share.gettype() -eq [System.IO.DirectoryInfo])
    {
    #ex: source is H:\00_Tim Mon\NKE-WIN-GTW-P17_5240P4017\System Monitor Log.blg
    $pathrootlength=$share.FullName.IndexOf(":")+1
    $suffixslashlength=("\").length
    $source=$share.FullName
    $dest=$base+$share.FullName.Substring($pathrootlength,$share.FullName.Length-$pathrootlength)
    "source is {0} and dest is {1}" -f ($source,$dest)
    $level="/lev:2"
    if ($lev -lt $global:MaxLevel)
    {
    "coyp floder robocopy {0} {1} /R:1 /W:1 /MIR  /ZB {2}" -f ($source,$dest,$level)
    #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /CopyALL  $args[2]} -ArgumentList ($source,$dest,$level)  # -AsJob 
    $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /CopyALL  $args[2]} -ArgumentList ($source,$dest,$level)
    $global:alljobs+=$job
    #as job will fail ,due to AmbiguousParameterSet
    # contorl the total count of robocopy process 

    }
    elseif ($lev -eq $global:MaxLevel)
    {
    "coyp floder robocopy {0} {1} /R:1 /W:1 /MIR  /ZB" -f ($source,$dest)
    #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1  /ZB /CopyALL  /S /E} -ArgumentList ($source,$dest,$level)  # -AsJob 
    $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" /R:1 /W:1 /MT:32 /ZB /CopyALL  /S /E} -ArgumentList ($source,$dest,$level)
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
    $pathrootlength=$share.FullName.IndexOf(":")+1
    $suffixslashlength=("\").length
    $source=$share.FullName.Substring(0,$share.FullName.Length-$share.Name.Length-$suffixslashlength)
    $dest=$base+$share.FullName.Substring(2,$share.FullName.Length-$share.Name.Length-$pathrootlength-$suffixslashlength)
    $level="/lev:1"
    $filename=$share.Name
    "coyp file robocopy {0} {1} {2}  /R:1 /W:1 /MIR  /ZB  {3}" -f  ($source,$dest,$filename,$level)
    #Invoke-Command -ComputerName  NKE-WIN-GTW-P17 -Credential $mycreds -ScriptBlock {robocopy "$($args[0])" "$($args[1])" "$($args[2])" /R:1 /W:1   /ZB   $args[3]  } -ArgumentList ($source,$dest,$filename,$level)   #-asjob 
    $job=start-job -ScriptBlock {robocopy "$($args[0])" "$($args[1])" "$($args[2])" /R:1 /W:1 /MT:32  /ZB /CopyALL   $args[3]  } -ArgumentList ($source,$dest,$filename,$level) 
    $global:alljobs+=$job
    }
    else
    {
    
    }
    }


}


write-host -ForegroundColor "---Monitor the Job once all Robocopy is not running--"
Monitor-Jobs -alljobs $global:alljobs

$endtime=Get-Date
"total copytime is $(($endtime-$starttime).totalseconds) seconds"
write-host -ForegroundColor "---receive all Robocopy job--"
$results=@()
foreach ($j in $global:alljobs)
{
$result=[PSCustomObject]@{
Jobid = $j.Id
Joboutput=receive-job -Job $j -keep
        }
$results+= $result
}


write-host -ForegroundColor "---Anylyze Each Job output---"
#Anylyze Each Job output
$jobstatus=get-content "C:\work\script\Migrate-ShareFolder\robocopylogSample.txt"
$job1=[PSCustomObject]@{
    Name = "job1"
    Joboutput=$jobstatus
}
$results+=$job1
foreach ($RoboCopyJob in $results)
{
    $RobojobInstance=Covert-RobocopyLogObjFromJob -RoboCopyJob $RoboCopyJob
    $AnylyzeRobocopyObj=Analyze-RobocoyLog -robocopyinstance $RobojobInstance
    if(  $AnylyzeRobocopyObj[1].SubTotalCatagoryDetailFailed -ne 0 )
    {
        write-host -ForegroundColor red "robocopy ： Failed Detail is”
        $RobojobInstance.RobocopyCommand
        $RobojobInstance.RobocopySummary
        $RobojobInstance.RobocopyDetail

    }
    else {
        write-host -ForegroundColor Green "robocopy :  Successed”
        $RobojobInstance.RobocopyCommand
    }
}

$endtime=Get-Date
"total runtime(including Anylyze log) is $(($endtime-$starttime).totalseconds) seconds"