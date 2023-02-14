@description('The name of the AVD hostpool.')
@minLength(1)
param hostpoolName string

@description('The subscription ID that the log analytics workspace in located in.')
@minLength(1)
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
@minLength(1)
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
@minLength(1)
param monitoringWorkspaceName string

// The setting name to use for the diagnostic setting.
var settingName = 'WVDInsights'

// Get the Log Analytics workspace.
resource monitoringWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: resourceGroup(monitoringWorkspaceSubscriptionId, monitoringWorkspaceResourceGroupName)
  name: monitoringWorkspaceName
}

// Get the AVD hostpool.
resource hostpoolResource 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' existing = {
  scope: resourceGroup()
  name: hostpoolName
}

// Add the necessary diagnostic settings for AVD Insights to the AVD hostpool.
resource addHostpoolMonitoring 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: hostpoolResource
  name: settingName
  properties: {
    workspaceId: monitoringWorkspaceResource.id
    logs: [
      {
        category: 'Checkpoint'
        enabled: true
      }
      {
        category: 'Error'
        enabled: true
      }
      {
        category: 'Management'
        enabled: true
      }
      {
        category: 'Connection'
        enabled: true
      }
      {
        category: 'HostRegistration'
        enabled: true
      }
      {
        category: 'AgentHealthStatus'
        enabled: true
      }
    ]
  }
}
