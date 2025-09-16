param capacities array
param location string
param administrationMembers array
param dataFactories array
param environment string
param vmName string
param subnetName string
param nicName string
param osDiskName string
param vnetExternalId string
param vmSize string
param imageReferenceSku string
param storageAccountType string
param vmAdminUserPassKeyvault string 
param vmAdminUserNameKeyvault string
param envToDeploy array
param storageAccountName string
param storageSkuName string
param storageKind string
param storageAccessTier string
param storageAccountBlobServiceName string
param storageAccountfileServiceName string
param storageAccountQueueServiceName string
param storageAccountTableServiceName string
param storageAccountBlobServiceContainerName string
param roleDefinitionId string
param keyVaultName string

module msFabric 'modules/msfabric.bicep' = if (contains(envToDeploy, environment)) {
  name: 'deployMsFabric'
  params: {
    location: location
    administrationMembers: administrationMembers 
    capacities: capacities
  }
}

module dataFactory 'modules/adf.bicep' = {
  name: 'deployDataFactory'
  params: {
    dataFactories: dataFactories
    location: location
    roleDefinitionId:roleDefinitionId
    keyVaultName: keyVaultName
  }
}

module windowsVM 'modules/vm.bicep' = if (contains(envToDeploy, environment)) {
  name: 'deployWindowsVM'
  params: {
    location: location
    nicName: nicName
    osDiskName: osDiskName
    subnetName: subnetName
    vnetExternalId: vnetExternalId
    vmName: vmName
    vmSize: vmSize
    imageReferenceSku: imageReferenceSku
    storageAccountType: storageAccountType
    vmAdminUserPasswordValue: vmAdminUserPassKeyvault
    vmAdminUserNameValue: vmAdminUserNameKeyvault
  }
}

module storageAccount 'modules/storages.bicep' = if (contains('SIT', environment)) {
  name: 'deployStorageAccount'
  params: {
    location: location
    storageAccessTier:storageAccessTier 
    storageAccountBlobServiceContainerName: storageAccountBlobServiceContainerName
    storageAccountBlobServiceName: storageAccountBlobServiceName
    storageAccountName: storageAccountName
    storageAccountQueueServiceName: storageAccountQueueServiceName
    storageAccountTableServiceName: storageAccountTableServiceName
    storageAccountfileServiceName: storageAccountfileServiceName
    storageKind: storageKind
    storageSkuName: storageSkuName
  }
}
