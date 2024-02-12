@description('The name of the AVD workspace.')
param workspaceName string

@description('The subscription ID that the log analytics workspace in located in.')
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
param monitoringWorkspaceName string

var settingName = 'WVDInsights'

// Get the log analytics workspace.
resource monitoringWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(monitoringWorkspaceSubscriptionId, monitoringWorkspaceResourceGroupName)
  name: monitoringWorkspaceName
}

// Get the AVD workspace.
resource workspaceResource 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' existing = {
  scope: resourceGroup()
  name: workspaceName
}

// Add the necessary diagnostic settings for AVD Insights to the AVD workspace.
resource addWorkspaceMonitoring 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: workspaceResource
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
        category: 'Feed'
        enabled: true
      }
    ]
  }
}
