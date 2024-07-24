@description('The name of the VM to add monitoring to.')
param vmName string

@description('The Azure region.')
param location string = resourceGroup().location

@description('The subscription ID that the DCR is located in.')
param dcrSubscriptionId string = subscription().subscriptionId

@description('The resource group that the DCR is located in.')
param dcrResourceGroupName string

@description('The name of the DCR.')
param dcrName string

resource dcrResource 'Microsoft.Insights/dataCollectionRules@2023-03-11' existing = {
  name: dcrName
  scope: resourceGroup(dcrSubscriptionId, dcrResourceGroupName)
}

// Get the VM resource.
resource vmItem 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  scope: resourceGroup()
  name: vmName
}

// Add the monitoring agent extension to the VM.
// NOTE: I believe I will need to update this to use the new agent.
resource addMonitoringExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vmItem
  location: location
  name: 'AzureMonitorWindowsAgent'

  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    enableAutomaticUpgrade: true
    autoUpgradeMinorVersion: true
    typeHandlerVersion: '1.0'
    suppressFailures: true
  }

  tags: {
    VirtualMachine: vmName
  }
}

resource vmDataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'avd-monitoring'
  scope: vmItem

  properties: {
    dataCollectionRuleId: dcrResource.id
  }

  dependsOn: [
    addMonitoringExtension
  ]
}
