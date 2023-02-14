// Define parameters
param vmName string
param vmLocation string = resourceGroup().location
param vmSize string = 'Standard_D8s_v4'
param vmDiskSizeGB int = 128
param vmTrustedLaunch bool = true
param vmInstallGPUDriver bool = false

param imageGalleryResourceGroup string
param imageGalleryName string
param imageName string
param imageVersion string

@secure()
param vmAdminUserName string
@secure()
param vmAdminPwd string

param vnetName string
param vnetRscGroup string
param vnetSubnetName string

param vmJoinerUserName string
@secure()
param vmJoinerPwd string

param vmDomainName string
param vmDomainOUPath string

// Get the image gallery.
resource imgGallery 'Microsoft.Compute/galleries@2021-07-01' existing = {
  name: imageGalleryName
  scope: resourceGroup(imageGalleryResourceGroup)
}

resource imgGalleryImgDef 'Microsoft.Compute/galleries/images@2021-07-01' existing = {
  parent: imgGallery
  name: imageName
}

resource imgGalleryImgVersion 'Microsoft.Compute/galleries/images/versions@2021-07-01' existing = {
  parent: imgGalleryImgDef
  name: imageVersion
}

// Get the virtual network.
resource vnetObj 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: vnetName
  scope: resourceGroup(subscription().subscriptionId, vnetRscGroup)
}

// Get the subnet in the virtual network.
resource vnetSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  parent: vnetObj
  name: vnetSubnetName
}

// Create the NIC for the VM.
// Set the NIC to utilize the subnet from the virtual network.
resource vmNic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
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
resource windowsVm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
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
resource joinToDomain 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
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

resource installGpuDriver 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if (vmInstallGPUDriver == true) {
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
