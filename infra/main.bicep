targetScope = 'resourceGroup'


var containerAppsLocation = resourceGroup().location
var acrName = 'acrtechconnect${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = 'log-techconnect${uniqueString(resourceGroup().id)}'
var acaEnvName = 'ace-techconnect'


resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  sku: {
    name: 'Premium'
  }
  name: acrName
  location: containerAppsLocation
  tags: {}
  properties: {
    adminUserEnabled: false
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    anonymousPullEnabled: false
    metadataSearch: 'Enabled'
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}


resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: containerAppsLocation
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
         workloadProfileType: 'Consumption'
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }

}


output ACR_NAME string = acrName
