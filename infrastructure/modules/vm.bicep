param vmName string
param subnetName string
param nicName string
param location string
param osDiskName string
param vmSize string
param imageReferenceSku string
param storageAccountType string
param vnetExternalId string
@secure()
param vmAdminUserNameValue string
@secure()
param vmAdminUserPasswordValue string

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nicName
  location: location

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnetExternalId}/subnets/${subnetName}'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  // Missing permissions to link to userAssigned identity for Azure Monitoring Agent (MCSAz-GFCS-P-EUW-UAI-AMA-01)  # TODO
    // identity: {
    //   type: 'SystemAssigned, UserAssigned'
    //   userAssignedIdentities: {
    //     '/subscriptions/cf329f3a-318f-45e5-9130-7a2a40d8cb6f/resourceGroups/MCSAz-GFCS-P-EUW-RG-GLOBAL/providers/Microsoft.ManagedIdentity/userAssignedIdentities/MCSAz-GFCS-P-EUW-UAI-AMA-01': {}
    //   }

  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: imageReferenceSku
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: osDiskName
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: storageAccountType
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUserNameValue
      adminPassword: vmAdminUserPasswordValue
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    licenseType: 'Windows_Server'
  }
}
