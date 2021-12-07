workflow Start_VMs_Parallel_PSWorkflow
{
######################################################################################
######################################################################################
##  created by:  AustinM   Last Modified 02/01/2021 added another Try/Catch
##
##  modified by: ScChaney 7/20/2020 to use AZ commands
##
##  Purpose:  Start the list of VMs provided in the subscription (Script does not process Classic VMs)
##  
##  Note:  When you create the runbook you MUST select "PowerShell WorkFlow".   The name of the runbook must match
##         the name of the workflow on line 1. The Automation account needs to have a Runas Azure Automation account
##  Note2: Runbook expects unique VM names.  Although if the duplicate VM name is in the $ExludeListResourceGroups
##         then this runbook may still work for you.  In general it is not recommeneded to have identical VM names.
##         This script was designed for ease of use so that customers do not have to list the resource group the VM are in.
## 
##  Update the variables below as desired

$MyVMList = @("xyVM5,xyVM6a")        # Include variable: if you want all VMs use:    $MyVMList=@("*")
$ResourceGroups = @("")              # Include variable: if specified will find all VMs in the rosource group(s) to stop unless excluded
                                     # $ResourceGroups=@("ResourceGroupXYZ,MyNewResourceGroup1")

$ExludeList = @("xyVM7,xyVM8")       # Optional Exclude variable. You can specify VMs that should be excluded so they are not started
$ExludeListResourceGroups= @("")     # Optional Exclude variable. allows you to exclude all VMs in a resource group.  set to @("") if resource groups should be excluded.   Exclude wins over include.
                                     # This is especially usefull if you have VMs with the same name, which is not recommended in the same subscription

$AzureGov = $False                   # if you connect to Azure Government set this to   $True

$SecondsToPause = 1                  # If your VMs has a "StartOrder" tag = 1, 2, 3, or 4 the VMs will be started in that order and pause between tag 1 and tag 2, ...

$Verboseoutput = $True               # Display detailed output as the Powershell runbook runs

$UpdateVM = $False                    # If set to $False VMs are not Started or Stopped.  Just pretends.  To update VM set to $True



$TimeZone = 'Eastern Standard Time'  # You can get a list of TimeZones ID names by using something similar to the following  
                                     #
                                     # [System.TimeZoneInfo]::GetSystemTimeZones() | FT ID, DisplayName
                                     #
                                     #      Id                       DisplayName
                                     #      --                       -----------
                                     #      Pacific Standard Time    (UTC-08:00) Pacific Time (US & Canada)
                                     #      Mountain Standard Time   (UTC-07:00) Mountain Time (US & Canada)
                                     #      Central Standard Time    (UTC-06:00) Central Time (US & Canada)
                                     #      Eastern Standard Time    (UTC-05:00) Eastern Time (US & Canada)
                                     #      SA Western Standard Time (UTC-04:00) Georgetown, La Paz, Manaus, San Juan
                                     #      Romance Standard Time    (UTC+01:00) Brussels, Copenhagen, Madrid, Paris
                                     #      Syria Standard Time      (UTC+02:00) Damascus
                                     #      FLE Standard Time        (UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius
                                     #      Israel Standard Time     (UTC+02:00) Jerusalem
                                     #      Arabian Standard Time    (UTC+04:00) Abu Dhabi, Muscat
                                     #      ...

##  Update the variables above as needed
##  
##  Azure Modules used/required, may require other modules be updated also:
##  
##    Az.Accounts
##    Az.Compute
##    Azure
##    Az.Automation
##
##  You can check your Azure Modules version from the Azure portal under:  Home > Automation Accounts > AutomationAccountXYZ - Modules
##  If your Azure Modules are not up to date you can try clicking "Update Azure modules" to update all Azure modules.   If you 
##  are using Azure Government the best way to update the modules for the specific Automation account is to use the Powershell script 
##  located at:
##     Download Update-AutomationAzureModulesForAccount.ps1 runbook to update your Azure modules
##     https://github.com/Microsoft/AzureAutomation-Account-Modules-Update
##     Copy Raw and Create a runbook with the name:  Update-AutomationAzureModulesForAccount.  If using AzureUSGovernment update the 
##     line below as shown before running the script to update modules so that it is going to the AzureUSGovernment:
##          [string] $AzureEnvironment = 'AzureUSGovernment'
##
##  If you see the following you likely do not have the update Azure modules listed above:   
##     Cannot find the 'Connect-AzAccount' command
##
##  Notes:
##    - You should confirm that this sample runbook is starting the Runbooks as desired.  If you have many VMs it may be necessary
##      to run the runbook from a Hybrid Runbook worker.  Runbooks that run in Azure have limits on the amount of resources
##      that they are allowed to use.  Alternatively you may want to use the marketplace "Start/Stop VMs during off-hours" 
##      solution which does not have the automation limits if you have hundreds of VMs to start and stop in a short duration.
##        Automation Limits:
##        https://docs.microsoft.com/en-us/azure/azure-subscription-service-limits#automation-limits
##    
##    - VMS often start before the script is informed the VM has started.  Same can occur on the portal.  Best confirmation is to 
##      RDP to the system to determine if it is trully running or not.
##

$OnlyConsiderVMsInResourceGroups = @("*")   # Only VMs in the specified resource groups will be considered.   
                                            # this variable generally does not need to be modified unless you have more than 
                                            # 100 VMs or you have the same computer name in multiple resource groups, which is not recommended.  
                                            # $OnlyConsiderVMsInResourceGroups=@("ResourceGroupXYZ,MyNewResourceGroup1")

##
######################################################################################
######################################################################################


#$GLOBAL:DebugPreference = "Continue"   ## default value is SilentlyContinue  -- This line can significantly increase the output.

" -- Runbook started at Universal time: " + (Get-date).ToUniversalTime()
If ($Verboseoutput) {'Runbook Data below:';$psprivatemetadata}  ## Job ID displayed near the top of the runbook because if it does not complete having jobID is helpful in the output 

$Notes=@'
Notes:
- You should confirm that this sample runbook is starting the Runbooks as desired.  If you have many VMs it may be necessary
  to run the runbook from a Hybrid Runbook worker.  Runbooks that run in Azure have limits on the amount of resources
  that they are allowed to use.  Alternatively you may want to use the marketplace "Start/Stop VMs during off-hours" 
  solution which does not have the automation limits if you have hundreds of VMs to start and stop in a short duration.
    Automation Limits:
    https://docs.microsoft.com/en-us/azure/azure-subscription-service-limits#automation-limits

- VMS often start before the script is informed the VM has started.  Same can occur on the portal.  Best confirmation is to 
  RDP to the system to determine if it is trully running or not.
'@

$Conn = Get-AutomationConnection -Name AzureRunAsConnection
"  ApplicationId         : " + $Conn.ApplicationId
"  CertificateThumbprint : " + $Conn.CertificateThumbprint

If ($AzureGov) {$ConnectionInfo = Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint -EnvironmentName AzureUSGovernment}
else {$ConnectionInfo = Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint}
"  TenantId              : " + $ConnectionInfo.Context.Tenant.ID

$AzureContext = Select-AzSubscription -SubscriptionId $Conn.SubscriptionID    ## or select a specific subscription 
"  Environment           : " + $AzureContext.Environment
"  Subscription          : " + $AzureContext.Subscription
"  SubscriptionName      : " + $AzureContext.Subscription.Name
""

If (!($AzureContext)) 
{"";"ERROR:  Something appears to have gone wrong.  Select-AzSubscription appears to be empty."
    "        Confirm Azure RunAs Account is present and not expired:  Home > Automation Accounts > AutomationAccountXYZ - Run As Accounts";
    "        Confirm Azure Modules have been updated:   Home > Automation Accounts > AutomationAccountXYZ - Modules"
    Exit
}


$Notes

######################################################
## Turns a string like the following into an array to make it easier for customer to type in
##
##    "vm1,vm2,vm3"  ==>   @("vm1","vm2","vm3")
##    "vm1 vm2 vm3"  ==>   @("vm1","vm2","vm3")
##
Function ReturnStringArray ($MultiStringxxx)   
{
## convert a string with spaces or commas into separate elements for an array.  remove any empty elements. 
$MultiStringxxx = $MultiStringxxx.Replace(' ',',')
$MultiStringxxx = $MultiStringxxx -replace '([,]{2,})',','  ## makes use of regex to replace repeating commas with a single comma
$MultiStringxxx = $MultiStringxxx.Trim(",")  ## remove any leading or trailing commas 
[array]$MyArray = $MultiStringxxx.Split(",") 
return $MyArray 
}

[array]$MyVMList = ReturnStringArray $MyVMList
[array]$ResourceGroups = ReturnStringArray $ResourceGroups
[array]$ExludeList = ReturnStringArray $ExludeList
[array]$ExludeListResourceGroups = ReturnStringArray $ExludeListResourceGroups
[array]$OnlyConsiderVMsInResourceGroups = ReturnStringArray $OnlyConsiderVMsInResourceGroups

If ($Verboseoutput) {"";"-- Only Consider VMs that are part of $OnlyConsiderVMsInResourceGroups"}

if ($ExludeListResourceGroups) 
  {
  ForEach ($RG in $ExludeListResourceGroups) 
    {  try {$RGexcludeVMs += Get-AzVM -ResourceGroupName  "$RG" -DefaultProfile $AzureContext}
       catch {Start-sleep -seconds 30; "-- Retry AA: Get-AzVM -ResourceGroupName $RG ..."; $RGexcludeVMs += Get-AzVM -ResourceGroupName "$RG" -DefaultProfile $AzureContext}   ## Give Get-AzVM a 2nd chance if it fails
    }
  ForEach ($RGVM in $RGexcludeVMs) { [array]$ExludeList += ($RGVM.Name)  }
  }
$ExludeList = $ExludeList | sort -Unique
If ($Verboseoutput) {"";"-- VM exclude list: $ExludeList"}


if ($resourceGroups) 
  {
  $RGVMs = @()
  If ($Verboseoutput) {""}
  ForEach ($RG in $ResourceGroups) 
    {   If ($Verboseoutput) {"-- checking for VMs in Resource Group: $RG"}  
        try {$RGVMs += Get-AzVM -ResourceGroupName  "$RG" -DefaultProfile $AzureContext}
        catch {Start-sleep -seconds 30; "-- Retry BB: Get-AzVM -ResourceGroupName $RG ..."; $RGVMs += Get-AzVM -ResourceGroupName "$RG" -DefaultProfile $AzureContext}   ## Give Get-AzVM a 2nd chance if it fails
    }
  ForEach ($RGVM in $RGVMs) { [array]$MyVMList += ($RGVM.Name)  }
  }

$MyVMList = $MyVMList | sort -Unique
If ($Verboseoutput) {"";"-- VM include list: $MyVMList (Exclude list wins over include)"}

# Get VM instance view properties. Does not return the standard VM properties however it gets the reource group the VM is in and current status
$VMsWithStatus=@();""
If ('*' -in $OnlyConsiderVMsInResourceGroups -or (!($OnlyConsiderVMsInResourceGroups))) 
  {
  If ($Verboseoutput) {"Running:  Get-AzVM -Status ..."}
  try {$VMsWithStatus = Get-AzVM -Status -DefaultProfile $AzureContext | ?{$_.ResourceGroupName -notin $ExludeListResourceGroups}| select-object ResourceGroupName, Name, PowerState}
  catch {Start-sleep -seconds 30; "-- Retry CC: Get-AzVM -Status ..."; $VMsWithStatus = Get-AzVM -Status -DefaultProfile $AzureContext | ?{$_.ResourceGroupName -notin $ExludeListResourceGroups}| select-object ResourceGroupName, Name, PowerState}   ## Give Get-AzVM a 2nd chance if it fails
  }
Else 
  {
  ForEach ($ConsiderRG in $OnlyConsiderVMsInResourceGroups) 
    {
    If ($Verboseoutput) {"Running:  Get-AzVM -Status -ResourceGroupName $ConsiderRG ..."}
    try {$VMsWithStatus += Get-AzVM -Status -ResourceGroupName $ConsiderRG -DefaultProfile $AzureContext | ?{$_.ResourceGroupName -notin $ExludeListResourceGroups}| select-object ResourceGroupName, Name, PowerState}
    catch {Start-sleep -seconds 30; "-- Retry DD: Get-AzVM -Status -ResourceGroupName $ConsiderRG ..."; $VMsWithStatus += Get-AzVM -Status -ResourceGroupName $ConsiderRG -DefaultProfile $AzureContext | ?{$_.ResourceGroupName -notin $ExludeListResourceGroups}| select-object ResourceGroupName, Name, PowerState}   ## Give Get-AzVM a 2nd chance if it fails
    }
  }

If ($Verboseoutput) 
  {"";"-- VM(s) already running: VMName    ResourceGroup";

  If ('*' -in $MyVMList) 
    {$AlreadyInDesiredState = $VMsWithStatus | ?{$_.PowerState -like "*running*" -and $_.Name -NotIn $ExludeList} 
    }
  else 
    {$AlreadyInDesiredState = $VMsWithStatus | ?{$_.PowerState -like "*running*" -and $_.Name -NotIn $ExludeList -and $_.Name -in $MyVMList} 
    }
    ForEach ($VMStatus in $AlreadyInDesiredState)
    {"   " + $VMStatus.name + "      " + $VMStatus.ResourceGroupName
    }
  }

If ('*' -in $MyVMList) 
  {$VMsToChange = $VMsWithStatus | ?{$_.PowerState -notlike "*running*"} }
else 
  {$VMsToChange = $VMsWithStatus | ?{$_.PowerState -notlike "*running*" -and $_.Name -in $MyVMList} }

$VMsToChange = $VMsToChange | ?{$_.Name -NotIn $ExludeList}

"";"-- VMs found minus exclude list that need to be updated: " + $VMsToChange.Count  # does not display a number if the list only has one machine


# Create an array to store standard VMs properties that are running 
$VMs1 = @(); $VMs2 = @(); $VMs3 = @(); $VMs4 = @(); $VMsLast = @();
ForEach ($VMStatus in $VMsToChange) # Get the VM properties of each VM of interest
  { "   " + $VMStatus.name + "      " + $VMStatus.ResourceGroupName
    $VM = @(Get-AzVM -Name ($VMStatus.name) -ResourceGroupName ($VMStatus.ResourceGroupName) -DefaultProfile $AzureContext)
    If ($VM.tags.StartOrder) 
      {
        If     ($VM.tags.StartOrder -eq "1") {$VMs1 += $VM}
        elseif ($VM.tags.StartOrder -eq "2") {$VMs2 += $VM}
        elseif ($VM.tags.StartOrder -eq "3") {$VMs3 += $VM}
        elseif ($VM.tags.StartOrder -ge "4") {$VMs4 += $VM}
      }
    else 
      {
        $VMsLast += $VM 
      }
  }

""
$DisplayPause=$False
for ($xx = 1; $xx -ile 5; $xx++) 
  { 
    $VMs=@()
    If     ($VMs1 -and $xx -eq 1)    {$VMs = $VMs1;$DisplayPause=$True}
    ElseIf ($VMs2 -and $xx -eq 2)    {$VMs = $VMs2;$DisplayPause=$True}
    ElseIf ($VMs3 -and $xx -eq 3)    {$VMs = $VMs3;$DisplayPause=$True}
    ElseIf ($VMs4 -and $xx -eq 4)    {$VMs = $VMs4;$DisplayPause=$True}
    ElseIf ($VMsLast -and $xx -eq 5) {$VMs = $VMsLast}
    
    if (($VMs) -and $DisplayPause) {"";"== Pausing for $SecondsToPause Before continuing with the next batch of VM(s) to start";""; Start-Sleep -Seconds $SecondsToPause}
    $DisplayPause=$False
    Foreach -parallel -throttlelimit 15 ($VM in $VMs)
     {
         "Running:    Start-AzVM -Name " + $Vm.Name + "    -ResourceGroupName " + $Vm.ResourceGroupName
         If ($UpdateVM) 
           {
           try {$Status = Start-AzVM -Name $Vm.Name -ResourceGroupName $Vm.ResourceGroupName -DefaultProfile $AzureContext}
           catch {Start-sleep -seconds 30; "-- Retry Start-AzVM -Name "+$Vm.Name; $Status = Start-AzVM -Name $Vm.Name -ResourceGroupName $Vm.ResourceGroupName -DefaultProfile $AzureContext}
           $StartTimeUTC = $Status.StartTime.ToUniversalTime().ToString('HH:mm')
           $StartTimeInTz = [System.TimeZoneInfo]::ConvertTimeFromUtc($StartTimeUTC, [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZone)) 
           $EndTimeUTC = $Status.EndTime.ToUniversalTime().ToString('HH:mm')
           $EndTimeInTz = [System.TimeZoneInfo]::ConvertTimeFromUtc($EndTimeUTC, [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZone)) 
           "Finished: " + $Vm.Name + " with " + $Status.Status + "   StartTime: $StartTimeInTz    EndTime: $EndTimeInTz   $TimeZone"
           }
         else 
           {'   $UpdateVM = $false // no action taken'}
      }
  }
" -- Runbook finished at Universal time: " + (Get-date).ToUniversalTime()
}
