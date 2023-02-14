@description('The name for the VM.')
@minLength(1)
param vmName string

@description('The datacenter location the resources will reside.')
@minLength(1)
param vmLocation string = resourceGroup().location

@description('The VM size to use.')
@minLength(1)
param vmSize string = 'Standard_D8s_v4'

@description('The size (In GB) of the OS disk for the VM.')
param vmDiskSizeGB int = 256

@description('Whether to enable \'Trusted Launch\' for the VM.')
param vmTrustedLaunch bool = true

@description('Whether to install GPU drivers for the VM.')
param vmInstallGPUDriver bool = false

@description('The resource group the image gallery is located in.')
@minLength(1)
param imageGalleryResourceGroupName string

@description('The name of the image gallery.')
@minLength(1)
param imageGalleryName string

@description('The name of the image to use.')
@minLength(1)
param imageName string

@description('The version of the image to use.')
@minLength(1)
param imageVersion string

@description('The username to use for the local admin.')
@minLength(1)
@secure()
param vmAdminUserName string

@description('The password to use for the local admin.')
@minLength(1)
@secure()
param vmAdminPwd string

@description('The resource group that the Virtual Network is located in.')
@minLength(1)
param vnetResourceGroupName string

@description('The name of the Virtual Network.')
@minLength(1)
param vnetName string

@description('The name of the subnet to use in the Virtual Network.')
@minLength(1)
param vnetSubnetName string

@description('The username of the user to use to join the session host to AD.')
@minLength(1)
param vmJoinerUserName string

@description('The password of the user joining the session host to AD.')
@minLength(1)
@secure()
param vmJoinerPwd string

@description('The AD domain name the VM will be joining to.')
@minLength(1)
param vmDomainName string

@description('The OU path in AD to join the VM to.')
@minLength(1)
param vmDomainOUPath string

// Get the image gallery.
resource imgGallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: imageGalleryName
  scope: resourceGroup(imageGalleryResourceGroupName)
}

// Get the image.
resource imgGalleryImgDef 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  parent: imgGallery
  name: imageName
}

// Get the specified version of the image.
resource imgGalleryImgVersion 'Microsoft.Compute/galleries/images/versions@2022-03-03' existing = {
  parent: imgGalleryImgDef
  name: imageVersion
}

// Get the virtual network.
resource vnetObj 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName
  scope: resourceGroup(subscription().subscriptionId, vnetResourceGroupName)
}

// Get the subnet in the virtual network.
resource vnetSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnetObj
  name: vnetSubnetName
}

// Create the NIC for the VM.
// Set the NIC to utilize the subnet from the virtual network.
resource vmNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${vmName}_nic'
  location: vmLocation

  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig-primary'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          primary: true
          subnet: {
            id: vnetSubnet.id
          }
        }
      }
    ]
  }

  dependsOn: [
    vnetSubnet
  ]

  tags: {
    VirtualMachine: vmName
  }
}

// Deploy the Windows VM.
resource windowsVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: vmLocation
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }

    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUserName
      adminPassword: vmAdminPwd
      windowsConfiguration: {
        provisionVMAgent: true
      }
    }

    
    securityProfile: vmTrustedLaunch == true ? {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    } : null

    licenseType: 'Windows_Client'

    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        osType: 'Windows'

        name: '${vmName}_OSDisk'
        diskSizeGB: vmDiskSizeGB
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }

      imageReference: {
        id: imgGalleryImgVersion.id
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }

    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }

  tags: {
    VirtualMachine: vmName
    ImageName: imgGalleryImgDef.name
    ImageVersion: imgGalleryImgVersion.name
  }
}

// Join to the domain.
resource joinToDomain 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: 'joinDomain'
  location: vmLocation

  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'

    settings: {
      name: vmDomainName
      ouPath: vmDomainOUPath
      user: vmJoinerUserName
      restart: true
      options: '3'
    }

    protectedSettings: {
      password: vmJoinerPwd
    }
  }
  parent: windowsVm
  tags: {
    VirtualMachine: vmName
  }
}

// Install the GPU driver, if specified.
resource installGpuDriver 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = if (vmInstallGPUDriver == true) {
  name: 'gpuExtension'
  parent: windowsVm
  location: vmLocation
  dependsOn: [
    joinToDomain
  ]

  properties: {
    publisher: 'Microsoft.HpcCompute'
    type: 'NvidiaGpuDriverWindows'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}

output nic object = {
  resourceId: vmNic.id
  name: vmNic.name
}

output vm object = {
  resourceId: windowsVm.id
  name: windowsVm.name
}

output vmOsDisk object = {
  resourceId: windowsVm.properties.storageProfile.osDisk.managedDisk.id
  name: windowsVm.properties.storageProfile.osDisk.name
}
