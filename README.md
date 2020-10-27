Invoke-VMAccessExtensions
=========================

            



 




This Azure Automation runbook is intended to be executed interactively against a specified cloud service.  It will execute the chosen action (runbook parameters) against all VMs in the specified cloud service.  Target VMs do not need to be
 running but must have the VM Agent installed (typically selected during VM provisioning).   A restart of the target VMs might be required for new settings to apply.


The optional actions are:


1. Admin_Reset.  This will rename the built-in Administrfator account and/or change the password


2. Enable or Disable BGInfo Extension


3. Enable or Disable VM Access Extension. 


4. Fix RDP (Same as Enable VM Access)  Resets local guest firewall and RDP settings.


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
