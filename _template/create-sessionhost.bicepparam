using '../create-sessionhost.bicep'

param avdHostType = 'Desktop'

param resourceGroupName = ''

param deploymentScriptIdentityResourceGroupName = ''
param deploymentScriptIdentityName = ''

param vmNamePrefix = ''
param vmSize = 'Standard_D8s_v4'
param vmDiskSize = 256

param vnetResourceGroupName = ''
param vnetName = ''
param vnetSubnetName = ''

param dcrSubscriptionId = ''
param dcrResourceGroupName = ''
param dcrName = ''

param imageGalleryResourceGroupName = ''
param imageGalleryName = ''

param imageName = ''
param imageVersion = ''

param keyVaultResourceGroupName = ''
param keyVaultName = ''

param vmJoinType = 'ActiveDirectory'

param vmJoinerUserName = ''
param vmJoinerKeyVaultPasswordItemName = ''

param localAdminUserName = ''
param localAdminKeyVaultPasswordItemName = ''

param domainName = ''
param domainDesktopOUPath = ''
param domainRemoteAppOUPath = ''

param hostPoolBaseName = ''
