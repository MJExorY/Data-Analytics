@allowed(['westeurope'])
param location string

param capacities array

param administrationMembers array



resource msFabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = [for (capacity, index) in capacities: {
  name: capacity.name
  location: location
  sku: {
    name: capacity.skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: administrationMembers
    }
  }
}]
