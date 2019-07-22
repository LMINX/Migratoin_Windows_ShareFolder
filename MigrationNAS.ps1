<##
Data:2019.03.08
Version:0.1
Author:George Liu
Description: use this script to migrate the share folder from windows server to netapp storage server
Details:
1.get the real server that holding the share file server role in the cluster.
2.gather and summay all share folder in that primary node.
3.process the folder path to list all the share folder that in the subfolder
##>


function get-sharefolder {
  <#
  .SYNOPSIS
  Get the all share folder infomation from the cluster or cluster
  .DESCRIPTION
  Get all the share folder from the source server or clusetr and classify them by share type:public share folder,user home share(shared name with $),ohters and summary their in size 
  the number of subfolders, last access time and so on
  gwmi -class win32_share to query all the share (including default share ,such as c$ ,admin$,share folder which type is 0, share priter which type is 1)
  .EXAMPLE
  get-sharefolder -computer shareserver
  get-sharefolder -shareserverrole shareserverrolename -cluster clutername
  .PARAMETER 
  computername
  The computer name to query. Just one.
  cluster
  fileshare cluster name
  shareserverrole
  cluster rolename for the share server
  #>
    [CmdletBinding(DefaultParameterSetName='Server')]
    param (
          [Parameter(Mandatory=$true,position=0,ParameterSetName='Server')]
          $Computername,

          [Parameter(Mandatory=$true,ParameterSetName='Cluster')]
          $shareserverrole,

          [Parameter(Mandatory=$true,ParameterSetName='Cluster')]
          $cluster         
    )
    try {
        if ($Computername)
        {
        $servershare=get-WmiObject -class Win32_Share -computer $Computername -ErrorAction Stop
        #get each share folder summary in parallel
        $servershare
        }
        elseif ($cluster)
        {      
        #$clusterRoleName="NKE-WIN-NAS-P23"
        #$clusterName="NKE-WIN-CTL-P10"
        $primaryNode=Get-ClusterGroup -Name $shareserverrole -Cluster $cluster
        $realserver=$primaryNode.OwnerNode.Name
        $servershare=invoke-command  -ComputerName $realserver -scriptblock {Get-SmbShare -ScopeName $args[0] } -ArgumentList $shareserverrole
        $servershare
        }
    }
    catch {
        $errorcode=$_.Exception.Message+'`n'+$error[-1].InvocationInfo.positionmessage
        "unable to get server share from $computername $shareserverrole with errocode"+'`n'+$errorcode
    }
    finally {
        
    }
    }
