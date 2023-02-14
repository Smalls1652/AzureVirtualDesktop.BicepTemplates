@description('The name of the AVD workspace.')
@minLength(1)
param workspaceName string

@description('The subscription ID that the log analytics workspace in located in.')
@minLength(1)
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
@minLength(1)
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
@minLength(1)
param monitoringWorkspaceName string

var settingName = 'WVDInsights'

resource monitoringWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  scope: resourceGroup(monitoringWorkspaceSubscriptionId, monitoringWorkspaceResourceGroupName)
  name: monitoringWorkspaceName
}

resource workspaceResource 'Microsoft.DesktopVirtualization/workspaces@2022-09-09' existing = {
  scope: resourceGroup()
  name: workspaceName
}

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
