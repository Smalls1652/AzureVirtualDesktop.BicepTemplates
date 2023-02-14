@description('The name for the storage account.')
@minLength(1)
param storageAccountName string

@description('The datacenter location to use.')
param location string = resourceGroup().location

// Create the storage account
resource fslogixStgAcct 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  properties: {
    largeFileSharesState: 'Enabled'

    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'

    // Set the default file share permissions to 'StorageFileDataSmbShareContributor'.
    azureFilesIdentityBasedAuthentication: {
      defaultSharePermission: 'StorageFileDataSmbShareContributor'
      directoryServiceOptions: 'None'
    }

    encryption: {
      requireInfrastructureEncryption: false
      keySource: 'Microsoft.Storage'

      services: {
        file: {
          enabled: true
          keyType: 'Account'
        }

        blob: {
          enabled: true
          keyType: 'Account'
        }
      }
    }

    accessTier: 'Hot'
  }
}

// Configure the settings for file shares in the storage account.
// This primarily sets the SMB protocol to not accept RC4 Kerberos encryption.
resource fslogixStgAcctFileSvcs 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = {
  parent: fslogixStgAcct
  name: 'default'

  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }

    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        channelEncryption: 'AES-256-GCM'
        authenticationMethods: 'NTLMv2;Kerberos'
        kerberosTicketEncryption: 'AES-256'
      }
    }
  }
}

// Create a file share named 'profiles'.
resource fslogixStgAcctProfilesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  parent: fslogixStgAcctFileSvcs
  name: 'profiles'

  properties: {
    enabledProtocols: 'SMB'
    accessTier: 'Hot'
    shareQuota: 102400
  }
}

output storageAccountResourceId string = fslogixStgAcct.id
