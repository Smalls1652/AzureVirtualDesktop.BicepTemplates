param randomHash string = newGuid()

@description('The resource group the VM will be located in.')
@minLength(1)
param resourceGroupName string

@allowed([
  'Desktop'
  'RemoteApp'
])
param avdHostType string = 'Desktop'

@description('The resource group that the managed identity, for deployment scripts, is located in.')
@minLength(1)
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
@minLength(1)
param deploymentScriptIdentityName string

@description('The prefix to use when naming the VM.')
@minLength(1)
@maxLength(9)
param vmNamePrefix string

@description('The VM size to use.')
@minLength(1)
param vmSize string = 'Standard_D8s_v4'

@description('The size (In GB) of the OS disk for the VM.')
param vmDiskSize int = 256

@description('The resource group that the Virtual Network is located in.')
@minLength(1)
param vnetResourceGroupName string

@description('The name of the Virtual Network.')
@minLength(1)
param vnetName string

@description('The name of the subnet to use in the Virtual Network.')
@minLength(1)
param vnetSubnetName string

@description('The subscription ID that the log analytics workspace in located in.')
@minLength(1)
param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId

@description('The resource group that the log analytics workspace is located in.')
@minLength(1)
param monitoringWorkspaceResourceGroupName string

@description('The name of the log analytics workspace.')
@minLength(1)
param monitoringWorkspaceName string

@description('The resource group the image gallery is located in.')
@minLength(1)
param imageGalleryResourceGroupName string

@description('The name of the image gallery.')
@minLength(1)
param imageGalleryName string

@description('The name of the image to use.')
@minLength(1)
param imageName string

@description('The version of the image to use.')
@minLength(1)
param imageVersion string

@description('The name of the resource group the key vault is located in.')
@minLength(1)
param keyVaultResourceGroupName string

@description('The name of the key vault.')
@minLength(1)
param keyVaultName string

@description('The username of the user to use to join the session host to AD.')
@minLength(1)
param vmJoinerUserName string

@description('The name of the secret item for the VM joiner\' password.')
@minLength(1)
#disable-next-line secure-secrets-in-params
param vmJoinerKeyVaultPasswordItemName string

@description('The username to use for the local admin.')
@minLength(1)
param localAdminUserName string

@description('The name of the secret item to use for the local admin\'s password.')
@minLength(1)
#disable-next-line secure-secrets-in-params
param localAdminKeyVaultPasswordItemName string

@description('The AD domain name the VM will be joining to.')
@minLength(1)
param domainName string

@description('The OU path in AD to join the VM to for \'Session Desktop\' hosts.')
@minLength(1)
param domainDesktopOUPath string

@description('The OU path in AD to join the VM to for \'RemoteApp\' hosts.')
@minLength(1)
param domainRemoteAppOUPath string

@description('The name of the hostpool the session host will be apart of.')
@minLength(1)
param hostPoolBaseName string

targetScope = 'subscription'

// Generate a 6 character random string.
var randomString = take(uniqueString(subscription().id, randomHash), 6)

// Get the resource group.
resource resourceGroupItem 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
}

// Deploy the session host.
module deployHost '../_includes/sessionhost-deployments/create-sessionhost.bicep' = {
  name: 'deploySessionHost_${randomString}'
  scope: resourceGroupItem

  params: {
    vmLocation: resourceGroupItem.location
    avdHostType: avdHostType

    deploymentScriptIdentityResourceGroupName: deploymentScriptIdentityResourceGroupName
    deploymentScriptIdentityName: deploymentScriptIdentityName

    vmNamePrefix: vmNamePrefix
    vmSize: vmSize
    vmDiskSize: vmDiskSize

    vnetResourceGroupName: vnetResourceGroupName
    vnetName: vnetName
    vnetSubnetName: vnetSubnetName

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName

    imageGalleryResourceGroupName: imageGalleryResourceGroupName
    imageGalleryName: imageGalleryName

    imageName: imageName
    imageVersion: imageVersion

    keyVaultResourceGroupName: keyVaultResourceGroupName
    keyVaultName: keyVaultName

    vmJoinerUserName: vmJoinerUserName
    vmJoinerKeyVaultPasswordItemName: vmJoinerKeyVaultPasswordItemName

    localAdminUserName: localAdminUserName
    localAdminKeyVaultPasswordItemName: localAdminKeyVaultPasswordItemName

    domainName: domainName
    domainOUPath: avdHostType == 'Desktop' ? domainDesktopOUPath : domainRemoteAppOUPath

    hostPoolName: avdHostType == 'Desktop' ? '${hostPoolBaseName} - Desktop' : '${hostPoolBaseName} - RemoteApps'
  }
}
