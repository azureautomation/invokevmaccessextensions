<#
.SYNOPSIS
    This Azure Automation runbook provides a way to leverage the VM Access Extensions to do various tasks without need to install Azure PowerShell. 
    You can use this runbook to rename and/or change the password for the local built-in Administrator account if you no longer know them.

.DESCRIPTION
    The runbook is meant to run interactively by taking inputs for target cloud service (will execute against all VMs in that cloud service) and take 
    runbook parameter for desired action.  The options are

    Admin_Reset (Must also enter admin name and password parameters - password must comply with local security policy to work)
    Enable or Disable BGInfo
    Enable or Disable VMAccess
    Fix RDP Access (fixes guest Windows firewall rules and RDP settings to allow RDP access) 

   You can find more information on configuring Azure so that Azure Automation can manage your
   Azure subscription(s) here: http://aka.ms/Sspv1l

   After configuring Azure and creating the Azure Automation credential asset, you can use that in your parameters,
   
   
#>

workflow Invoke-VMAccess {
    [OutputType( [string] )]
  
    param (
        [parameter(Mandatory=$true)]
        [String]$poSh_Cred_Name,
        
        [parameter(Mandatory=$true)]
        [String]$SubscriptionName,
        
        [parameter(Mandatory=$true)]
        [String]$Cloud_Service_Name,

        [parameter(Mandatory=$false)]
        [String]$Admin_Name,

        [parameter(Mandatory=$false)]
        [String]$Admin_Pwd,

        [parameter(Mandatory=$true)]
        [boolean]$Admin_Reset =$false,

        [parameter(Mandatory=$true)]
        [boolean]$BGinfo_Enable =$false,

        [parameter(Mandatory=$true)]
        [boolean]$BGinfo_Disable =$false,

        [parameter(Mandatory=$true)]
        [boolean]$VMAccess_Fix_RDP =$false,
        
        [parameter(Mandatory=$true)]
        [boolean]$VMAccess_Enable =$false,

        [parameter(Mandatory=$true)]
        [boolean]$VMAccess_Disable =$false

    )

    #vmaccess_enable is synonymous with vmaccess_fix_rdp
    if($VMAccess_Enable){$VMAccess_Fix_RDP = $true}
    # default to enable if both disable and enable are chosen
    if($VMAccess_Disable -and $VMAccess_Fix_RDP ){$VMAccess_Disable = $false}
    if($BGinfo_Disable -and $BGinfo_Enable){$BGinfo_Disable = $false}

    # convert password to secure string
    if($Admin_Pwd) {$password = ConvertTo-SecureString -String $Admin_Pwd -AsPlainText -force}

    # Grab the credential to use to authenticate to Azure. 
    $Cred = Get-AutomationPSCredential -Name $poSh_Cred_Name 
     
    #Connect to Azure
    Add-AzureAccount -Credential $Cred

    # Select the Azure subscription you want to work against
	Select-AzureSubscription -SubscriptionName $SubscriptionName
    
 

   # Get VMs from specified cloud service
   $VMs = Get-AzureVM | where-object -FilterScript {$_.servicename -eq $Cloud_Service_Name} 
   if(! $VMs){write-output "No VMs found in $Cloud_Service_Name";exit}
    
    foreach -parallel ($vmProp in $VMs) {       
    
        
    $rtn = inlinescript {
           $vm = Get-AzureVM | where {$_.name -eq $using:vmProp.name -and $_.servicename -eq $using:vmProp.serviceName} 
       
           if(! $vm.VM.ProvisionGuestAgent){write-output "VMAgent Not Installed on $($vm.name)";return}
           
           function retry-update {
            param ($name, $vm, $servicename)
               
               $update = Update-AzureVM -name $name -vm $vm -ServiceName $ServiceName -ea SilentlyContinue
               if($update.OperationStatus -eq 'Succeeded'){write-output "$name update $($update.operationStatus)";return}
               else
                {
                    do {
                           sleep 30
                           $update = Update-AzureVM -name $name -vm $vm -ServiceName $ServiceName -ea SilentlyContinue
                           $cnt++ 
                     }
                    while($update.OperationStatus -ne 'Succeeded' -or $cnt -lt 5)
                   write-output "$name update $($update.operationStatus)"
                }
           }
           
           if($using:BGInfo_Enable) { $vm | Set-AzureVMBGInfoExtension | out-null ; retry-update -name $vm.name -vm $vm.vm -ServiceName $vm.ServiceName }
           if($using:BGInfo_Disable) { $vm | Get-AzureVMBGInfoExtension | %{Set-AzureVMBGInfoExtension –ReferenceName $_.ReferenceName –Version $_.Version -vm $vm.vm –Disable | out-null  ; retry-update -name $vm.name -vm $vm.vm -ServiceName $vm.ServiceName} }   
           if($using:Admin_Reset) {
             if($using:Admin_Name -and $using:password) { 
              $vm | Set-AzureVMAccessExtension –UserName $using:Admin_Name –Password $using:password | out-null ; retry-update -name $vm.name -vm $vm.vm -ServiceName $vm.ServiceName
              }else{Write-Output "Missing parameters for admin name and/or password"}
            }   
           if($using:VMAccess_fix_RDP) { $vm | Set-AzureVMAccessExtension | out-null ; retry-update -name $vm.name -vm $vm.vm -ServiceName $vm.ServiceName}
           if($using:VMAccess_Disable) { $vm | Get-AzureVMAccessExtension | %{Set-AzureVMAccessExtension –ReferenceName $_.ReferenceName –Version $_.Version -vm $vm.vm –Disable | out-null  ; retry-update -name $vm.name -vm $vm.vm -ServiceName $vm.ServiceName} }      
        }
      
       Write-Output $rtn
   }
      
}