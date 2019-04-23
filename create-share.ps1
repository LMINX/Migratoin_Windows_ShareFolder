function get-sharefolder {
      <#
  .SYNOPSIS
  Get the all share folder infomation from 1 server
  .DESCRIPTION
  Get all the share folder from the source server and classify them by share type锛?public share folder,user home share(shared name with $),ohter and summary their size or 
  the number of subfolders, last access time.
  gwmi -class win32_share to query all the share (including default share ,such as c$ ,admin$,share folder which type is 0, share priter which type is 1)
  .EXAMPLE
  get-sharefolder -computer shareserver

  .PARAMETER computername
  The computer name to query. Just one.

  #>
    [CmdletBinding()]
    param (
          [Parameter(Mandatory=$true,position=0)]
          $Computername
    )
    try {
        $servershare=get-WmiObject -class Win32_Share -computer $Computername -ErrorAction Stop
        #get each share folder summary in parallel
        $servershare
    }
    catch {
        $errorcode=$_.Exception.Message+'`n'+$error[-1].InvocationInfo.positionmessage
        "unable to get server share from $computername with errocode"+'`n'+$errorcode
    }
    finally {
        
    }
    }



$s=get-sharefolder -Computername seoul-svr-01
$sharefoldes=$s|where {$_.type -eq  0}
$sharefoldes.count

$share=[wmiclass]"win32_share"
foreach($s in $sharefoldes)
{
$share.Create($s.path,$s.Name,0)
}