param location string = 'eastus2'

param deploymentScriptIdentityResourceGroupName string
param deploymentScriptIdentityName string

param workspaceName string
param workspaceFriendlyName string
param appGroupBaseName string

param createDesktopHostpool bool = true
param createRemoteAppHostpool bool = true

resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

var hostpoolContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e307426c-f9b6-4e81-87de-d99efb3c32bc')

resource hostPoolDesktop 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' = if (createDesktopHostpool) {
  name: '${workspaceName} - Desktop'
  location: location

  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'DepthFirst'
    maxSessionLimit: 5
    preferredAppGroupType: 'Desktop'
  }
}

resource hostPoolDesktopManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (createDesktopHostpool) {
  scope: hostPoolDesktop
  name: guid(hostpoolContributorRoleId, 'addDesktopManagedIdentityPermission', hostPoolDesktop.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}

resource appGroupDesktop 'Microsoft.DesktopVirtualization/applicationGroups@2021-07-12' = if (createDesktopHostpool) {
  name: '${appGroupBaseName}_Desktop_SessionDesktop'
  location: location

  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPoolDesktop.id
  }
}

resource hostPoolRemoteApp 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' = if (createRemoteAppHostpool) {
  name: '${workspaceName} - RemoteApps'
  location: location

  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'DepthFirst'
    maxSessionLimit: 5
    preferredAppGroupType: 'RailApplications'
  }
}

resource hostPoolRemoteAppManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (createRemoteAppHostpool) {
  scope: hostPoolRemoteApp
  name: guid(hostpoolContributorRoleId, 'addRemoteAppManagedIdentityPermission', hostPoolRemoteApp.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}


resource appGroupRemoteApp 'Microsoft.DesktopVirtualization/applicationGroups@2021-07-12' = if (createRemoteAppHostpool) {
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

resource workspaceResource 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' = {
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
