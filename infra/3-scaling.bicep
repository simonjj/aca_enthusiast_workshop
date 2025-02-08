param envId string
param acr object

var serviceBusNamespaceName = 'sb-${uniqueString(resourceGroup().id)}'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusNamespaceName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource queue 'queues' = {
    name: 'queue1'
    properties: {
      lockDuration: 'PT1M'
    }
  }
}


resource app 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: 'app'
  location: resourceGroup().location
  properties: {
    environmentId: envId
    configuration: {
      registries: [
        {
          server: acr.properties.loginServer
          identity: 'system-environment'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'nginx:latest'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'sbqueue'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                namespace: 'queue1'
                queue: 'queue1'
                messageCount: '10'
              }
              identity: 'system'
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

var serviceBusOwnerRoleId = '090c5cfd-751d-490a-894a-3ce6f1109419'
resource sbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespace.id, serviceBusOwnerRoleId, app.id)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusOwnerRoleId)
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appId string = app.id
