param location string
param vnetName string
param subnetName string
param privateEndpointName string
param acaEnvId string
param acaEnvName string


// create a vnet and suvbnet for pe termination only for ACA we use a managed network
// CLI Details can be found here:
// https://learn.microsoft.com/en-us/azure/container-apps/how-to-use-private-endpoint?pivots=azure-cli

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefixes: [ '10.0.1.0/24' ]
          delegations: [ ]
        }
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: '${acaEnvName}-connection'
        properties: {
          privateLinkServiceId: acaEnvId
          groupIds: [
            'managedEnvironments'
          ]
          privateLinkServiceConnectionState: {
            actionsRequired: 'None'
            status: 'Approved'
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

// TODO: spit out the needed outputs
output vnetId string = vnet.id