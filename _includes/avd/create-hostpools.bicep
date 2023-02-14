@description('The datacenter location the resources will reside.')
@minLength(1)
param location string = resourceGroup().location

@description('The resource group that the managed identity, for deployment scripts, is located in.')
@minLength(1)
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
@minLength(1)
param deploymentScriptIdentityName string

@description('The name of the AVD Workspace.')
@minLength(1)
param workspaceName string

@description('A friendly name that users will see for the AVD Workspace.')
@minLength(1)
param workspaceFriendlyName string

@description('The base name to use when the AVD Application Groups are made.')
@minLength(1)
param appGroupBaseName string

@description('Whether to create a \'Session Desktop\' hostpool.')
param createDesktopHostpool bool = true

@description('Whether to create a \'RemoteApp\' hostpool.')
param createRemoteAppHostpool bool = false

resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

var hostpoolContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e307426c-f9b6-4e81-87de-d99efb3c32bc')

resource hostPoolDesktop 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' = if (createDesktopHostpool) {
  name: '${workspaceName} - Desktop'
  location: location

  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'DepthFirst'
    maxSessionLimit: 5
    preferredAppGroupType: 'Desktop'
  }
}

resource hostPoolDesktopManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createDesktopHostpool) {
  scope: hostPoolDesktop
  name: guid(hostpoolContributorRoleId, 'addDesktopManagedIdentityPermission', hostPoolDesktop.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}

resource appGroupDesktop 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = if (createDesktopHostpool) {
  name: '${appGroupBaseName}_Desktop_SessionDesktop'
  location: location

  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPoolDesktop.id
  }
}

resource hostPoolRemoteApp 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' = if (createRemoteAppHostpool) {
  name: '${workspaceName} - RemoteApps'
  location: location

  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'DepthFirst'
    maxSessionLimit: 5
    preferredAppGroupType: 'RailApplications'
  }
}

resource hostPoolRemoteAppManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRemoteAppHostpool) {
  scope: hostPoolRemoteApp
  name: guid(hostpoolContributorRoleId, 'addRemoteAppManagedIdentityPermission', hostPoolRemoteApp.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}


resource appGroupRemoteApp 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = if (createRemoteAppHostpool) {
  name: '${appGroupBaseName}_RemoteApps_Apps'
  location: location

  properties: {
    applicationGroupType: 'RemoteApp'
    hostPoolArmPath: hostPoolRemoteApp.id
  }
}

var appGroups = [
  createDesktopHostpool ? { id: appGroupDesktop.id }: { id: null }
  createRemoteAppHostpool ? {id: appGroupRemoteApp.id } : { id: null }
]

var appGroupReferences = map(filter(appGroups, item => item.id != null), item => item.id)

var hostpools = [
  createDesktopHostpool ? hostPoolDesktop : null
  createRemoteAppHostpool ? hostPoolRemoteApp : null
]

var hostpoolsToDependOn = filter(hostpools, item => item != null)

resource workspaceResource 'Microsoft.DesktopVirtualization/workspaces@2022-09-09' = {
  name: workspaceName
  location: location

  properties: {
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: appGroupReferences
  }

  dependsOn: hostpoolsToDependOn
}

output workspaceId string = workspaceResource.id
output workspaceName string = workspaceResource.name

output hostPoolDesktopId string = createDesktopHostpool ? hostPoolDesktop.id : ''
output hostPoolDesktopName string = createDesktopHostpool ? hostPoolDesktop.name : ''
output hostPoolDesktopAppGroupId string = createDesktopHostpool ? appGroupDesktop.id : ''

output hostPoolRemoteAppId string = createRemoteAppHostpool ? hostPoolRemoteApp.id : ''
output hostPoolRemoteAppName string = createRemoteAppHostpool ? hostPoolRemoteApp.name : ''
output hostPoolRemoteAppAppGroupId string = createRemoteAppHostpool ? appGroupRemoteApp.id : ''
