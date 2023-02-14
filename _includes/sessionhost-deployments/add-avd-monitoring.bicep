param vmName string
param location string = resourceGroup().location

param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId
param monitoringWorkspaceResourceGroupName string
param monitoringWorkspaceName string

// Get the AVD monitoring Log Analytics workspace.
resource monitoringWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  scope: resourceGroup(monitoringWorkspaceSubscriptionId, monitoringWorkspaceResourceGroupName)
  name: monitoringWorkspaceName
}

resource vmItem 'Microsoft.Compute/virtualMachines@2021-07-01' existing = {
  scope: resourceGroup()
  name: vmName
}

resource addMonitoringExtension 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
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
