using '../create-hostpool.bicep'

param resourceGroupName = ''
param location = ''

param deploymentScriptIdentityResourceGroupName = ''
param deploymentScriptIdentityName = ''

param monitoringWorkspaceSubscriptionId = ''
param monitoringWorkspaceResourceGroupName = ''
param monitoringWorkspaceName = ''

param hostpoolRoleTag = ''

param workspaceEnvironment = ''
param workspaceName = ''
param workspaceFriendlyName = ''

param createDesktopHostpool = true
param createRemoteAppHostpool = true
