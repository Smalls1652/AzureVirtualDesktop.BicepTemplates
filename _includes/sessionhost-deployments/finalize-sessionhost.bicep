param vmName string
param hostPoolName string
param vmDomainName string
param deploymentScriptIdentityResourceGroupName string
param deploymentScriptIdentityName string
param location string = resourceGroup().location

resource deploymentScriptPrincipal 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup(deploymentScriptIdentityResourceGroupName)
  name: deploymentScriptIdentityName
}

resource vmItem 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  scope: resourceGroup()
  name: vmName
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-09-09' existing = {
  scope: resourceGroup()
  name: hostPoolName
}

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
