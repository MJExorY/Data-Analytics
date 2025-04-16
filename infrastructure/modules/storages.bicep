param storageAccountName string
param location string
param storageSkuName string
param storageKind string
param storageAccessTier string
param storageAccountBlobServiceName string
param storageAccountfileServiceName string
param storageAccountQueueServiceName string
param storageAccountTableServiceName string
param storageAccountBlobServiceContainerName string

resource storageAccountResource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: storageKind
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    isSftpEnabled: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: storageAccessTier
  }
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccountResource
  name: storageAccountBlobServiceName
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
  }
}

resource storageAccountfileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccountResource
  name: storageAccountfileServiceName
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource storageAccountQueueService 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: storageAccountResource
  name: storageAccountQueueServiceName
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource storageAccountTableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: storageAccountResource
  name: storageAccountTableServiceName
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource storageAccountBlobServiceContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: storageAccountBlobService
  name: storageAccountBlobServiceContainerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}
