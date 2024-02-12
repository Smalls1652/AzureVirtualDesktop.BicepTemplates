param randomHash string = newGuid()

@description('The resource group the VM will be located in.')
param resourceGroupName string

@allowed([
  'Desktop'
  'RemoteApp'
])
param avdHostType string = 'Desktop'

@description('The resource group that the managed identity, for deployment scripts, is located in.')
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
param deploymentScriptIdentityName string

@description('The prefix to use when naming the VM.')
@maxLength(9)
param vmNamePrefix string

@description('The VM size to use.')
param vmSize string = 'Standard_D8s_v4'

@description('The size (In GB) of the OS disk for the VM.')
param vmDiskSize int = 256

@description('The resource group that the Virtual Network is located in.')
param vnetResourceGroupName string

@description('The name of the Virtual Network.')
param vnetName string

@description('The name of the subnet to use in the Virtual Network.')
param vnetSubnetName string

@description('The subscription ID that the DCR is located in.')
param dcrSubscriptionId string = subscription().subscriptionId

@description('The resource group that the DCR is located in.')
param dcrResourceGroupName string

@description('The name of the DCR.')
param dcrName string

@description('The resource group the image gallery is located in.')
param imageGalleryResourceGroupName string

@description('The name of the image gallery.')
param imageGalleryName string

@description('The name of the image to use.')
param imageName string

@description('The version of the image to use.')
param imageVersion string

@description('The name of the resource group the key vault is located in.')
param keyVaultResourceGroupName string

@description('The name of the key vault.')
param keyVaultName string

@description('The username of the user to use to join the session host to AD.')
param vmJoinerUserName string

@description('The name of the secret item for the VM joiner\' password.')
#disable-next-line secure-secrets-in-params
param vmJoinerKeyVaultPasswordItemName string

@description('The username to use for the local admin.')
param localAdminUserName string

@description('The name of the secret item to use for the local admin\'s password.')
#disable-next-line secure-secrets-in-params
param localAdminKeyVaultPasswordItemName string

@description('The AD domain name the VM will be joining to.')
param domainName string

@description('The OU path in AD to join the VM to for \'Session Desktop\' hosts.')
param domainDesktopOUPath string

@description('The OU path in AD to join the VM to for \'RemoteApp\' hosts.')
param domainRemoteAppOUPath string

@description('The name of the hostpool the session host will be apart of.')
param hostPoolBaseName string

targetScope = 'subscription'

// Generate a 6 character random string.
var randomString = take(uniqueString(subscription().id, randomHash), 6)

// Get the resource group.
resource resourceGroupItem 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: resourceGroupName
}

// Deploy the session host.
module deployHost './_includes/sessionhost-deployments/create-sessionhost.bicep' = {
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

    dcrSubscriptionId: dcrSubscriptionId
    dcrResourceGroupName: dcrResourceGroupName
    dcrName: dcrName

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
