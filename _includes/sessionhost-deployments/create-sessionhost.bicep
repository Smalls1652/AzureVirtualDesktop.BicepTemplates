@description('The datacenter location the resources will reside.')
param vmLocation string = resourceGroup().location

@description('A string to use as a hash for generating a unique string.')
param randomHashString string = newGuid()

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

@description('The OU path in AD to join the VM to.')
param domainOUPath string

@description('The name of the hostpool the session host will be apart of.')
param hostPoolName string

var randomStrLength = int(14 - length(vmNamePrefix))

var vmName = '${vmNamePrefix}-${take(uniqueString(subscription().id, resourceGroup().id, randomHashString), randomStrLength)}'

// Get the Key Vault resource for reading the default admin credentials.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroupName)
}

// Create the VM.
module sessionHostVM '../../_includes/sessionhost-deployments/deploy-vm.bicep' = {
  name: 'deployAVDHost_${vmName}'
  params: {
    vmName: vmName
    vmLocation: vmLocation
    vmSize: vmSize

    imageGalleryResourceGroupName: imageGalleryResourceGroupName
    imageGalleryName: imageGalleryName

    imageName: imageName
    imageVersion: imageVersion

    vmInstallGPUDriver: false
    vmTrustedLaunch: false

    vmDomainName: domainName
    vmDomainOUPath: domainOUPath

    vmDiskSizeGB: vmDiskSize

    vmAdminUserName: localAdminUserName
    vmAdminPwd: keyVault.getSecret(localAdminKeyVaultPasswordItemName)

    vnetName: vnetName
    vnetResourceGroupName: vnetResourceGroupName
    vnetSubnetName: vnetSubnetName

    vmJoinerUserName: vmJoinerUserName
    vmJoinerPwd: keyVault.getSecret(vmJoinerKeyVaultPasswordItemName)
  }
}

// Configure the VM to forward monitoring information to use with the AVD Insights workbook.
module addMonitoring '../../_includes/sessionhost-deployments/add-avd-monitoring.bicep' = {
  name: 'deployAVDHost_${vmName}_addMonitoring'
  params: {
    vmName: vmName
    location: vmLocation

    dcrSubscriptionId: dcrSubscriptionId
    dcrResourceGroupName: dcrResourceGroupName
    dcrName: dcrName
  }
  
  dependsOn: [
    sessionHostVM
  ]
}

// Start the 'Invoke-SessionHostFinalize' deployment script.
// It will wait until the VM is registered to the hostpool, then set it drain mode, and
// restart the VM.
module initFinalizeSessionHost '../../_includes/sessionhost-deployments/finalize-sessionhost.bicep' = {
  name: 'deployAVD_${vmName}_finalizeSessionHost'
  params: {
    vmName: vmName
    hostPoolName: hostPoolName
    vmDomainName: domainName

    deploymentScriptIdentityResourceGroupName: deploymentScriptIdentityResourceGroupName
    deploymentScriptIdentityName: deploymentScriptIdentityName

    location: vmLocation
  }

  dependsOn: [
    sessionHostVM
    addMonitoring
  ]
}

// Start the deployment script(s) for adding the VM to the hostpool.
module addToHostPool '../../_includes/sessionhost-deployments/add-to-hostpool.bicep' = {
  name: 'deployAVD_${vmName}_addToHostPool'
  params: {
    vmName: vmName
    location: vmLocation
    hostPoolName: hostPoolName

    deploymentScriptIdentityResourceGroupName: deploymentScriptIdentityResourceGroupName
    deploymentScriptIdentityName: deploymentScriptIdentityName
  }

  dependsOn: [
    sessionHostVM
    addMonitoring
  ]
}

output vmResourceId string = sessionHostVM.outputs.vm.resourceId
output vmOsDiskResourceId string = sessionHostVM.outputs.vmOsDisk.resourceId
output vmNicResourceId string  = sessionHostVM.outputs.nic.resourceId
