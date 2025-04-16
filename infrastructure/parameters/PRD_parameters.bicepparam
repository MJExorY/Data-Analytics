using '../main.bicep'

// MS Fabric Capacity Settings
param location = 'westeurope'
param administrationMembers = [
  'andreas.kranister@georgfischer.com'
  'muhammed-kasim.ekici@georgfischer.com'
]
param capacities = [
  {
    name: 'gfcspeuwfc001'
    skuName: 'F16' 
  }
]


// ADF Settings
param dataFactories = [
  {
    name: 'gfcspeuwadf001p'
  }
  {
    name: 'gfcspeuwadf001'
  }
]
param environment = 'PRD'


// ADF Role Assignment to existing KeyVault
param roleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
param keyVaultName = 'GFCSKV0002P'

// VM Settings
param vmName = 'GFCSAZSV0003P'
param subnetName = 'GFCS-P-EUW-RG-10093255-DAH-P'
param nicName = 'GFCSAZSV0004_NIC01'
param osDiskName = 'GFCSAZSV0004_DISK01'
param vnetExternalId = '/subscriptions/cf329f3a-318f-45e5-9130-7a2a40d8cb6f/resourceGroups/MCSAz-GFCS-P-EUW-RG-MGMT/providers/Microsoft.Network/virtualNetworks/MCSAz-GFCS-P-EUW-VN-01'
param vmSize = 'Standard_D16ads_v5'
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
param storageAccountName = 'gfcsneuwsa001p'
param storageSkuName = 'Standard_RAGRS'
param storageKind = 'StorageV2'
param storageAccessTier = 'Hot'
param storageAccountBlobServiceName = 'default'
param storageAccountfileServiceName = 'default'
param storageAccountQueueServiceName = 'default'
param storageAccountTableServiceName = 'default'
param storageAccountBlobServiceContainerName = 'adfstaging'
