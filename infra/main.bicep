targetScope = 'resourceGroup'


var appendix = 'techconnect${uniqueString(resourceGroup().id)}'
var containerAppsLocation = resourceGroup().location
var acrName = 'acr${appendix}'
var logAnalyticsWorkspaceName = 'log-${appendix}'
var acaEnvName = 'ace-${appendix}'

// pe + private dns + afd
var vnetName  = 'vnet-${appendix}'
var subnetName  = 'subnet-${appendix}'

var privateEndpointName  = 'pe-${appendix}'
var dnsNetLinkName = 'dns-pe-link-${appendix}'

var frontDoorEndpointName  = 'afd-${appendix}'





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


// ACA resources: env and containerApp

resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: containerAppsLocation
  properties: {
    publicNetworkAccess: 'Disabled'

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
var containerAppEnv = env

// create a quickstart app
// import these from the top respectively
var containerAppName = 'quickstart'
var location = containerAppsLocation


var image = 'mcr.microsoft.com/k8se/quickstart:latest'
resource containerApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: containerAppName
  location: location
  properties: {
    environmentId: containerAppEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'Auto'
      }
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: image
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
        }
      ]
    }
  }
  dependsOn: [
    env
  ]
}





// create vnet and private endpoint
module vnetPe 'vnet_pe.bicep' = {
  name: 'vnetPeDeployment'
  params: {
    location: containerAppsLocation
    vnetName: vnetName
    subnetName: subnetName
    privateEndpointName: privateEndpointName
    acaEnvId: env.id
    acaEnvName: acaEnvName
  }
  dependsOn: [
    env
  ]
}


// create private dns resouces
module privateDns 'private_dns.bicep' = {
  name: 'privateDnsDeployment'
  params: {
    location: containerAppsLocation
    vnetId: vnetPe.outputs.vnetId
    dnsNetLinkName: dnsNetLinkName
  }
  dependsOn: [
    vnetPe
  ]
}


// create Frontdoor resources
module afd 'afd.bicep' = {
  name: 'afdDeployment'
  params: {
    frontDoorProfileName: frontDoorEndpointName
    containerAppEnvId: env.id
    containerAppFqdn: containerApp.properties.configuration.ingress.fqdn
    location: location
    appendix: appendix
  }
  dependsOn: [
    env
  ]
}

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, acrPullRoleId, env.id)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: env.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


module app3 '3-scaling.bicep' = {
  name: 'app3Module'
  params: {
    acr: registry
    envId: env.id
  }
}


output ACR_NAME string = acrName
output APP3_ID string = app3.outputs.appId
