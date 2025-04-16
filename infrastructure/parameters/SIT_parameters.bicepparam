using '../main.bicep'

// MS Fabric Capacity Settings
param location = 'westeurope'
param administrationMembers = [
  'andreas.kranister@georgfischer.com'
  'muhammed-kasim.ekici@georgfischer.com'
]
param capacities = [
  {
    name: 'gfcsneuwfc002'
    skuName: 'F8' 
  }
]

// ADF Settings
param dataFactories = [
  {
    name: 'gfcsneuwadf001i'
  }
]
param environment = 'SIT'

// VM Settings
param vmName = 'GFCSAZSV0004'
param subnetName = 'GFCS-P-EUW-RG-10093553-DAH-I'
param nicName = 'GFCSAZSV0004_NIC01'
param osDiskName = 'GFCSAZSV0004_DISK01'
param vnetExternalId = '/subscriptions/cf329f3a-318f-45e5-9130-7a2a40d8cb6f/resourceGroups/MCSAz-GFCS-P-EUW-RG-MGMT/providers/Microsoft.Network/virtualNetworks/MCSAz-GFCS-P-EUW-VN-01'
param vmSize = 'Standard_D8as_v4'
param imageReferenceSku = '2022-datacenter-g2'
param storageAccountType = 'Premium_LRS'
param vmAdminUserPassKeyvault = 'vmAdminUserPassKeyvault' 
param vmAdminUserNameKeyvault = 'vmAdminUserNameKeyvault'

// General Settings
param envToDeploy = [
  'DEV'
  'PRD'
]

// Storage Accounts settings
param storageAccountName = 'gfcsneuwsa001i'
param storageSkuName = 'Standard_RAGRS'
param storageKind = 'StorageV2'
param storageAccessTier = 'Hot'
param storageAccountBlobServiceName = 'default'
param storageAccountfileServiceName = 'default'
param storageAccountQueueServiceName = 'default'
param storageAccountTableServiceName = 'default'
param storageAccountBlobServiceContainerName = 'adfstaging'

// ADF Role Assignment to existing KeyVault
param roleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
param keyVaultName = 'GFCSKV0002I'
