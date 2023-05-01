@description('The name of the resource group to use.')
param resourceGroupName string

@description('The Azure region to store the resources.')
param location string = 'eastus2'

@description('The resource group that the managed identity, for deployment scripts, is located in.')
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
param deploymentScriptIdentityName string

@description('The subscription ID that the log analytics workspace in located in.')
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
param monitoringWorkspaceName string

@description('The name of the role the hostpool is for.')
param hostpoolRoleTag string

@description('The name of the AVD Workspace.')
param workspaceName string

@description('A friendly name that users will see for the AVD Workspace.')
param workspaceFriendlyName string

@description('Whether to create a \'Session Desktop\' hostpool.')
param createDesktopHostpool bool = true

@description('Whether to create a \'RemoteApp\' hostpool.')
param createRemoteAppHostpool bool = false

targetScope = 'subscription'

// Generate the base name for the Application Groups.
// Removes spaces and replaces '-' characters with '_'.
var appGroupBaseName = replace(replace(workspaceName, ' ', ''), '-', '_')

// Create the resource group.
resource resourceGroupItem 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location

  tags: {
    Workload: 'Azure Virtual Desktop'
    Role: hostpoolRoleTag
    'AVD Type': 'Remote access'
  }
}

// Create the hostpools, application groups, and workspace.
module hostPoolResources './_includes/avd/create-hostpools.bicep' = {
  name: 'createHostPoolResources'
  scope: resourceGroupItem

  params: {
    location: location
    deploymentScriptIdentityResourceGroupName: deploymentScriptIdentityResourceGroupName
    deploymentScriptIdentityName: deploymentScriptIdentityName
    workspaceName: workspaceName
    workspaceFriendlyName: workspaceFriendlyName
    appGroupBaseName: appGroupBaseName
    createDesktopHostpool: createDesktopHostpool
    createRemoteAppHostpool: createRemoteAppHostpool
  }
}

// Configure the diagnostic settings for the AVD insights workbook on the created workspace.
module workspaceAddMonitoring './_includes/avd/add-avd-monitoring-workspace.bicep' = {
  name: 'workspaceAddMonitoring'
  scope: resourceGroupItem

  params: {
    workspaceName: hostPoolResources.outputs.workspaceName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
}

// Configure the diagnostic settings for the AVD insights workbook on the created hostpool (Desktop).
module hostpoolDesktopAddMonitoring './_includes/avd/add-avd-monitoring-hostpool.bicep' = if (createDesktopHostpool) {
  name: 'hostpoolDesktopAddMonitoring'
  scope: resourceGroupItem

  params: {
    hostpoolName: hostPoolResources.outputs.hostPoolDesktopName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
}

// Configure the diagnostic settings for the AVD insights workbook on the created hostpool (RemoteApp).
module hostpoolRemoteAppAddMonitoring './_includes/avd/add-avd-monitoring-hostpool.bicep' = if (createRemoteAppHostpool) {
  name: 'hostpoolRemoteAppAddMonitoring'
  scope: resourceGroupItem

  params: {
    hostpoolName: hostPoolResources.outputs.hostPoolRemoteAppName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
}

output resourceGroupId string = resourceGroupItem.id
output hostPoolResourceIds object = hostPoolResources
