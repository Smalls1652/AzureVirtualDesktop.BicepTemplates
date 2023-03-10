@description('The name for the VM.')
@minLength(1)
param vmName string

@description('The name of the hostpool the session host will be apart of.')
@minLength(1)
param hostPoolName string

@description('The AD domain name the VM will be joining to.')
@minLength(1)
param vmDomainName string

@description('The resource group that the managed identity, for deployment scripts, is located in.')
@minLength(1)
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
@minLength(1)
param deploymentScriptIdentityName string

@description('The datacenter location the resources will reside.')
@minLength(1)
param location string = resourceGroup().location

// Get the managed identity to use for running the deployment script.
resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

// Get the VM resource.
resource vmItem 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  scope: resourceGroup()
  name: vmName
}

// Get the hostpool.
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' existing = {
  scope: resourceGroup()
  name: hostPoolName
}

// Start the 'Invoke-SessionHostFinalize' deployment script.
resource finalizeSessionHost 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: location
  name: 'FinalizeSessionHost-${vmName}'

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptPrincipal.id}': {}
    }
  }

  properties: {
    azPowerShellVersion: '7.5'

    scriptContent: loadTextContent('./_scripts/Invoke-SessionHostFinalize.ps1')
    arguments: '-VmResourceId \\"${vmItem.id}\\" -HostPoolName \\"${hostPool.name}\\" -DomainName \\"${vmDomainName}\\"'

    timeout: 'PT2H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
