$Vms = Get-AzVM

foreach ($Vm in $Vms) 

{

#Write-Output $Vm.Name

#Write-Output $Vm.ResourceGroupName 

#Write-Output $Vm.Location

#$Vm.StorageProfile.OsDisk.OsType.ToString()


#Put in your workspaceId & workspaceKey in these variables

$workspaceId = "Workspace ID"

$workspaceKey = "Workspace Key"

 

$PublicSettings = @{"workspaceId" = $workspaceId;"stopOnMultipleConnections" = $false}

$ProtectedSettings = @{"workspaceKey" = $workspaceKey}

 

If ($Vm.StorageProfile.OsDisk.OsType.ToString() -eq "Windows")

  {

  Write-Output  "$($Vm.Name) - WINDOWS Detected Onboarding Windows Agent"

  Set-AzVMExtension -ExtensionName "MicrosoftMonitoringAgent" -ResourceGroupName $Vm.ResourceGroupName -VMName $Vm.Name -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "MicrosoftMonitoringAgent" -TypeHandlerVersion 1.0 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $Vm.Location
  }

If ($Vm.StorageProfile.OsDisk.OsType.ToString() -eq "Linux")

  {

  Write-Output  "$($Vm.Name) -  LINUX Detected Onboarding Linux Agent"

  Set-AzVMExtension -ExtensionName "OmsAgentForLinux" -ResourceGroupName $Vm.ResourceGroupName -VMName $Vm.Name -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "OmsAgentForLinux" -TypeHandlerVersion 1.0 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $Vm.Location

  }

}