@description('The datacenter location the resources will reside.')
param location string = resourceGroup().location

@description('The resource group that the managed identity, for deployment scripts, is located in.')
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
param deploymentScriptIdentityName string

@description('The name of the AVD Workspace.')
param workspaceName string

@description('A friendly name that users will see for the AVD Workspace.')
param workspaceFriendlyName string

@description('The base name to use when the AVD Application Groups are made.')
param appGroupBaseName string

@description('Whether to create a \'Session Desktop\' hostpool.')
param createDesktopHostpool bool = true

@description('Whether to create a \'RemoteApp\' hostpool.')
param createRemoteAppHostpool bool = false

// Get the managed identity that is used for running deployment scripts.
resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

// Get the subscription resource ID for the 'Hostpool Contributor' role.
var hostpoolContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e307426c-f9b6-4e81-87de-d99efb3c32bc')

// Create a hostpool for session desktop use, if specified.
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

// Assign the managaged identity the 'Hostpool Contributor' role to the created hostpool.
resource hostPoolDesktopManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createDesktopHostpool) {
  scope: hostPoolDesktop
  name: guid(hostpoolContributorRoleId, 'addDesktopManagedIdentityPermission', hostPoolDesktop.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}

// Create an application group for the session desktop hostpool.
resource appGroupDesktop 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = if (createDesktopHostpool) {
  name: '${appGroupBaseName}_Desktop_SessionDesktop'
  location: location

  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPoolDesktop.id
  }
}

// Create a hostpool for RemoteApp use, if specified.
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

// Assign the managaged identity the 'Hostpool Contributor' role to the created hostpool.
resource hostPoolRemoteAppManagedIdentityPermission 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createRemoteAppHostpool) {
  scope: hostPoolRemoteApp
  name: guid(hostpoolContributorRoleId, 'addRemoteAppManagedIdentityPermission', hostPoolRemoteApp.id)

  properties: {
    roleDefinitionId: hostpoolContributorRoleId
    principalId: deploymentScriptPrincipal.properties.principalId
  }
}

// Create an application group for the RemoteApp hostpool.
resource appGroupRemoteApp 'Microsoft.DesktopVirtualization/applicationGroups@2022-09-09' = if (createRemoteAppHostpool) {
  name: '${appGroupBaseName}_RemoteApps_Apps'
  location: location

  properties: {
    applicationGroupType: 'RemoteApp'
    hostPoolArmPath: hostPoolRemoteApp.id
  }
}

// Create a variable for storing Ids of the created application groups.
// This is useful for defining whether a application group was created or not.
var appGroups = [
  createDesktopHostpool ? { id: appGroupDesktop.id }: { id: null }
  createRemoteAppHostpool ? {id: appGroupRemoteApp.id } : { id: null }
]

// Filter out any application groups that are null.
var appGroupReferences = map(filter(appGroups, item => item.id != null), item => item.id)

// Create a variable for storing Ids of the created hostpools.
// This is useful for defining whether a hostpool was created or not.
/* 
var hostpools = [
  createDesktopHostpool ? hostPoolDesktop : null
  createRemoteAppHostpool ? hostPoolRemoteApp : null
]
*/

// Filter out any hostpools that are null.
//var hostpoolsToDependOn = filter(hostpools, item => !empty(item))

// Create the workspace and assign the created application groups to it.
resource workspaceResource 'Microsoft.DesktopVirtualization/workspaces@2022-09-09' = {
  name: workspaceName
  location: location

  properties: {
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: appGroupReferences
  }

  dependsOn: [
    hostPoolDesktop
    hostPoolRemoteApp
  ]
}

output workspaceId string = workspaceResource.id
output workspaceName string = workspaceResource.name

output hostPoolDesktopId string = createDesktopHostpool ? hostPoolDesktop.id : ''
output hostPoolDesktopName string = createDesktopHostpool ? hostPoolDesktop.name : ''
output hostPoolDesktopAppGroupId string = createDesktopHostpool ? appGroupDesktop.id : ''

output hostPoolRemoteAppId string = createRemoteAppHostpool ? hostPoolRemoteApp.id : ''
output hostPoolRemoteAppName string = createRemoteAppHostpool ? hostPoolRemoteApp.name : ''
output hostPoolRemoteAppAppGroupId string = createRemoteAppHostpool ? appGroupRemoteApp.id : ''
