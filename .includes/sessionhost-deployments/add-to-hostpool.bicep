@description('The name of the VM.')
param vmName string

@description('The name of the AVD hostpool to add the VM to.')
param hostPoolName string

@description('The resource group that the managed identity, for deployment scripts, is located in.')
param deploymentScriptIdentityResourceGroupName string

@description('The name of the managed identity for running deployment scripts.')
param deploymentScriptIdentityName string

@description('Whether to join the VM to Entra ID.')
param joinToEntraId bool = false

@description('The Azure region.')
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

// Deploy a deployment script to get the registration token info for
// adding new session hosts to the hostpool.
// This should be reusable for 6 hours after execution, so other deployments should use
// the generated token.
resource hostPoolRegInfo 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
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
    azPowerShellVersion: '12.0'

    scriptContent: loadTextContent('./.scripts/Get-HostPoolRegInfo.ps1')
    arguments: '-TenantId \\"${deploymentScriptPrincipal.properties.tenantId}\\" -SubscriptionId \\"${subscription().subscriptionId}\\" -ResourceGroupName \\"${resourceGroup().name}\\" -HostPoolName \\"${hostPool.name}\\"'

    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT6H'
  }
}

// Execute a run command on the VM to add it to the hostpool.
resource addVmToHostpool 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = {
  parent: vmItem
  location: location
  name: 'AddVmToHostpool'
  properties: {

    source: {
      script: loadTextContent('./.scripts/Invoke-AvdAgentInstall.ps1')
    }

    timeoutInSeconds: 1800
    asyncExecution: true

    parameters: [
      {
        name: 'RegistrationToken'
        value: hostPoolRegInfo.properties.outputs.regToken
      }
      {
        name: 'EnrollToEntraId'
        value: joinToEntraId ? 'Yes' : 'No'
      }
      {
        name: 'EnrollToIntune'
        value: joinToEntraId ? 'Yes' : 'No'
      }
    ]
  }

  tags: {
    VirtualMachine: vmName
  }
}

resource addEntraIDLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (joinToEntraId == true) {
  name: 'AADLoginForWindows'
  parent: vmItem

  location: location

  dependsOn: [
    addVmToHostpool
  ]

  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true

    settings: {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    }
  }
}
