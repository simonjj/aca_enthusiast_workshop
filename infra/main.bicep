targetScope = 'resourceGroup'


var appendix = 'techconnect${uniqueString(resourceGroup().id)}'
var containerAppsLocation = resourceGroup().location
var acrName = 'acr${appendix}'
var logAnalyticsWorkspaceName = 'log-${appendix}'
var acaEnvName = 'pub-ace-${appendix}'
var privateAcaEnvName = 'priv-ace-${appendix}'

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
// public environment
resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: containerAppsLocation
  properties: {
    publicNetworkAccess: 'Enabled'

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
var location = containerAppsLocation

var containerAppNames = [
  'request-delay-app'
  'request-logger-app'
]

var containerAppImages = [
  'docker.io/tdarolywala/test-images:long-running-http-conn'
  'simon.azurecr.io/request-logger:latest'
]

var appPorts = [
  '8080'
  '8080'
]

// create multiple container apps
resource containerApps 'Microsoft.App/containerApps@2024-02-02-preview' = [for i in range(0, length(containerAppNames)): {
  name: containerAppNames[i]
  location: containerAppsLocation
  properties: {
    environmentId: containerAppEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: appPorts[i]
        transport: 'Auto'
      }
    }
    template: {
      containers: [
        {
          name: containerAppNames[i]
          image: containerAppImages[i]
          resources: {
            cpu: '1'
            memory: '2Gi'
          }
        }
      ]
      scale: {
        maxReplicas: '1'
        minReplicas: '1'
      }
    }
  }
  dependsOn: [
    env
  ]
}]

resource probeProblemsApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: 'sickly-app'
  location: containerAppsLocation
  properties: {
    environmentId: containerAppEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'Auto'
      }
    }
    template: {
      containers: [
        // resources 
        {
          name: 'health-probe-problems'
          image: 'simon.azurecr.io/sick_app:latest'
          resources: {
            cpu: '1'
            memory: '2Gi'
          }
          probes: [
            {
              type: 'readiness'
              tcpSocket: {
                port: 8081
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 1
            }
            {
              type: 'startup'
              httpGet: {
                path: '/startup_slow'
                port: 8080
                scheme: 'HTTP'
                httpHeaders: [
                  {
                    name: 'Custom-Header'
                    value: 'startup probe'
                  }
                ]
              }
              initialDelaySeconds: 3
              failureThreshold: 1
              periodSeconds: 3
            }
          ] // probes
          
        }

      ] // containers
      scale: {
            maxReplicas: '1'
            minReplicas: '1'
      }
    }
  }
  dependsOn: [
    env
  ]
}





// private environment and app for AFD
resource envPrivate 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: privateAcaEnvName
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

resource containerApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: 'quickstart-behind-afd'
  location: containerAppsLocation
  properties: {
    environmentId: envPrivate.id
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
          name: 'quickstart-behind-afd'
          image: 'mcr.microsoft.com/k8se/quickstart:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
        }
      ]
      scale: {
        maxReplicas: '1'
        minReplicas: '1'
      }
    }
  }
  dependsOn: [
    envPrivate
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
    acaEnvId: envPrivate.id
    acaEnvName: acaEnvName
  }
  dependsOn: [
    envPrivate
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
    containerAppEnvId: envPrivate.id
    containerAppFqdn: containerApp.properties.configuration.ingress.fqdn
    location: location
    appendix: appendix
  }
  dependsOn: [
    envPrivate, containerApp
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
output APP3_NAME string = app3.outputs.appName
