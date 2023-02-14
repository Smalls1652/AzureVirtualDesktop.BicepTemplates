@description('The name of the VM.')
param vmName string

@description('The name of the AVD hostpool to add the VM to.')
@minLength(1)
param hostPoolName string

@description('The resource group that the managed identity, for deployment scripts, is located in.')
@minLength(1)
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
@minLength(1)
param deploymentScriptIdentityName string

@description('The Azure region.')
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

// Deploy a deployment script to get the registration token info for
// adding new session hosts to the hostpool.
// This should be reusable for 6 hours after execution, so other deployments should use
// the generated token.
resource hostPoolRegInfo 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: location
  name: 'Get-HostPoolRegInfo-${uniqueString(resourceGroup().id)}'

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptPrincipal.id}': {}
    }
  }

  properties: {
    azPowerShellVersion: '7.5'
    
    scriptContent: loadTextContent('./_scripts/Get-HostPoolRegInfo.ps1')
    arguments: '-ResourceGroupName \\"${resourceGroup().name}\\" -HostPoolName \\"${hostPool.name}\\"'

    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT6H'
  }
}

// Execute a run command on the VM to add it to the hostpool.
resource addVmToHostpool 'Microsoft.Compute/virtualMachines/runCommands@2022-11-01' = {
  parent: vmItem
  location: location
  name: 'AddVmToHostpool'
  properties: {

    source: {
      script: loadTextContent('./_scripts/Invoke-AvdAgentInstall.ps1')
    }

    timeoutInSeconds: 1800
    asyncExecution: true

    parameters: [
      {
        name: 'RegistrationToken'
        value: hostPoolRegInfo.properties.outputs.regToken
      }
    ]
  }

  tags: {
    VirtualMachine: vmName
  }
}
