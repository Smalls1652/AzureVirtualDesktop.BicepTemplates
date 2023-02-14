@minLength(1)
@description('The datacenter location the resources will reside.')
param vmLocation string = resourceGroup().location

@minLength(1)
@description('A string to use as a hash for generating a unique string.')
param randomHashString string = newGuid()

@allowed([
  'Desktop'
  'RemoteApp'
])
param avdHostType string = 'Desktop'

param deploymentScriptIdentityResourceGroupName string
param deploymentScriptIdentityName string

// --- Define all changeable variables ---

// The prefix for the VM name.
param vmNamePrefix string

// The size of the VM and the VM's OS disk size (In GB).
param vmSize string = 'Standard_D8s_v4'
param vmDiskSize int = 256

// The resource group where the vNet is located, what the vNet is named, and the subnet name to use.
param vnetResourceGroupName string
param vnetName string
param vnetSubnetName string

param monitoringWorkspaceSubscriptionId string = subscription().subscriptionId
param monitoringWorkspaceResourceGroupName string
param monitoringWorkspaceName string

param imageGalleryResourceGroup string
param imageGalleryName string

// The name of the image and the version to use.
param imageName string
param imageVersion string

param keyVaultResourceGroup string
param keyVaultName string

param vmJoinerUserName string
#disable-next-line secure-secrets-in-params
param vmJoinerKeyVaultPasswordItemName string

param localAdminUserName string
#disable-next-line secure-secrets-in-params
param localAdminKeyVaultPasswordItemName string

// The OU path in AD to join to the computer to.
param domainName string
param domainOUPath string

// The name of the hostpool the session host will be apart of.
param hostPoolName string

// ---------- !!! Warning !!! ------------
// Do not change anything past this point.
// ---------------------------------------

var randomStrLength = int(14 - length(vmNamePrefix))

var vmName = '${vmNamePrefix}-${take(uniqueString(subscription().id, resourceGroup().id, randomHashString), randomStrLength)}'

// Get the Key Vault resource for reading the default admin credentials.
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}


module sessionHostVM '../../_includes/sessionhost-deployments/deploy-vm.bicep' = {
  name: 'deployAVDHost_${vmName}'
  params: {
    vmName: vmName
    vmLocation: vmLocation
    vmSize: vmSize

    imageGalleryResourceGroup: imageGalleryResourceGroup
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
    vnetRscGroup: vnetResourceGroupName
    vnetSubnetName: vnetSubnetName

    vmJoinerUserName: vmJoinerUserName
    vmJoinerPwd: keyVault.getSecret(vmJoinerKeyVaultPasswordItemName)
  }
}

module addMonitoring '../../_includes/sessionhost-deployments/add-avd-monitoring.bicep' = {
  name: 'deployAVDHost_${vmName}_addMonitoring'
  params: {
    vmName: vmName
    location: vmLocation

    monitoringWorkspaceSubscriptionId: monitoringWorkspaceSubscriptionId
    monitoringWorkspaceResourceGroupName: monitoringWorkspaceResourceGroupName
    monitoringWorkspaceName: monitoringWorkspaceName
  }
  
  dependsOn: [
    sessionHostVM
  ]
}

module initFinalizeSessionHost '../../_includes/sessionhost-deployments/finalize-sessionhost.bicep' = {
  name: 'deployAVD_${vmName}_finalizeSessionHost'
  params: {
    vmName: vmName
    hostPoolName: hostPoolName
    vmDomainName: domainName

    deploymentScriptIdentityResourceGroupName: deploymentScriptIdentityResourceGroupName
    deploymentScriptIdentityName: deploymentScriptIdentityName

    svcLocation: vmLocation
  }

  dependsOn: [
    sessionHostVM
    addMonitoring
  ]
}

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
