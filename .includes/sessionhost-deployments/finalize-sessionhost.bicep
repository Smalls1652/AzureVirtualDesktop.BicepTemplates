@description('The name for the VM.')
param vmName string

@description('The name of the hostpool the session host will be apart of.')
param hostPoolName string

@description('The AD domain name the VM will be joining to.')
param vmDomainName string

@description('The resource group that the managed identity, for deployment scripts, is located in.')
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
param deploymentScriptIdentityName string

@description('The datacenter location the resources will reside.')
param location string = resourceGroup().location

// Get the managed identity to use for running the deployment script.
resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

// Get the VM resource.
resource vmItem 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  scope: resourceGroup()
  name: vmName
}

// Get the hostpool.
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' existing = {
  scope: resourceGroup()
  name: hostPoolName
}

// Start the 'Invoke-SessionHostFinalize' deployment script.
resource finalizeSessionHost 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
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
    azPowerShellVersion: '12.0'

    scriptContent: loadTextContent('./.scripts/Invoke-SessionHostFinalize.ps1')
    arguments: '-TenantId \\"${deploymentScriptPrincipal.properties.tenantId}\\" -SubscriptionId \\"${subscription().subscriptionId}\\" -VmResourceId \\"${vmItem.id}\\" -HostPoolName \\"${hostPool.name}\\" -DomainName \\"${vmDomainName}\\"'

    timeout: 'PT2H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
