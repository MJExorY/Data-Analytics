param dataFactories array
param location string
param roleDefinitionId string
param keyVaultName string

resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVaultName
}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = [for (item, index) in dataFactories: {
  name: item.name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (item, index) in dataFactories: {
  name: guid(existingKeyVault.id, dataFactory[index].id, roleDefinitionId)
  scope: existingKeyVault
  dependsOn: [
    dataFactory[index]
  ]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: dataFactory[index].identity.principalId
  }
}]
