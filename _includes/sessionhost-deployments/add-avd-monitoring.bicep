@description('The name of the VM to add monitoring to.')
@minLength(1)
param vmName string

@description('The Azure region.')
@minLength(1)
param location string = resourceGroup().location

@description('The subscription ID that the log analytics workspace in located in.')
@minLength(1)
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
@minLength(1)
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
@minLength(1)
param monitoringWorkspaceName string

// Get the AVD monitoring Log Analytics workspace.
resource monitoringWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: resourceGroup(monitoringWorkspaceSubscriptionId, monitoringWorkspaceResourceGroupName)
  name: monitoringWorkspaceName
}

resource vmItem 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  scope: resourceGroup()
  name: vmName
}

resource addMonitoringExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vmItem
  location: location
  name: 'Microsoft.EnterpriseCloud.Monitoring'
  
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    autoUpgradeMinorVersion: true
    typeHandlerVersion: '1.0'
    suppressFailures: true

    settings: {
      workspaceId: monitoringWorkspace.properties.customerId
    }

    protectedSettings: {
      workspaceKey: monitoringWorkspace.listKeys().primarySharedKey
    }
  }

  tags: {
    VirtualMachine: vmName
  }
}
