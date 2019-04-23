
$DriverLetters=("D","E","F","G","H","I","J","K")
$starttime=Get-Date
foreach ($letter in $DriverLetters)
{
$source="\\seoul-svr-01\$($letter)$"
$destation="$($letter):"
robocopy $source $destation /copyall /MT:8 /W:0 /R:0 /MIR /E /ZB /TEE /LOG+:"C:\CopyDataByPartiton.txt"
}
$endtime=Get-Date
Write-Host "final sync take $(($endtime-$starttime).totalseconds) seconds to finish"

