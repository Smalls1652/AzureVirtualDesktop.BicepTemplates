@description('The name of the resource group to use.')
@minLength(1)
param resourceGroupName string

@description('The Azure region to store the resources.')
@minLength(1)
param location string = 'eastus2'

@description('The resource group that the managed identity, for deployment scripts, is located in.')
@minLength(1)
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
@minLength(1)
param deploymentScriptIdentityName string

@description('The subscription ID that the log analytics workspace in located in.')
@minLength(1)
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
@minLength(1)
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
@minLength(1)
param monitoringWorkspaceName string

@description('The name of the role the hostpool is for.')
@minLength(1)
param hostpoolRoleTag string

@description('The name of the AVD Workspace.')
@minLength(1)
param workspaceName string

@description('A friendly name that users will see for the AVD Workspace.')
@minLength(1)
param workspaceFriendlyName string

@description('Whether to create a \'Session Desktop\' hostpool.')
param createDesktopHostpool bool = true

@description('Whether to create a \'RemoteApp\' hostpool.')
param createRemoteAppHostpool bool = false

targetScope = 'subscription'

var appGroupBaseName = replace(replace(workspaceName, ' ', ''), '-', '_')

resource resourceGroupItem 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location

  tags: {
    Workload: 'Azure Virtual Desktop'
    Role: hostpoolRoleTag
    'AVD Type': 'Remote access'
  }
}

module hostPoolResources '../_includes/avd/create-hostpools.bicep' = {
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

module workspaceAddMonitoring '../_includes/avd/add-avd-monitoring-workspace.bicep' = {
  name: 'workspaceAddMonitoring'
  scope: resourceGroupItem

  params: {
    workspaceName: hostPoolResources.outputs.workspaceName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
}

module hostpoolDesktopAddMonitoring '../_includes/avd/add-avd-monitoring-hostpool.bicep' = if (createDesktopHostpool) {
  name: 'hostpoolDesktopAddMonitoring'
  scope: resourceGroupItem

  params: {
    hostpoolName: hostPoolResources.outputs.hostPoolDesktopName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
}

module hostpoolRemoteAppAddMonitoring '../_includes/avd/add-avd-monitoring-hostpool.bicep' = if (createRemoteAppHostpool) {
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
