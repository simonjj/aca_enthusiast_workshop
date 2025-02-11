param envId string
param acr object

var serviceBusNamespaceName = 'sb-${uniqueString(resourceGroup().id)}'
var queueName = 'queue1'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: serviceBusNamespaceName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource queue 'queues' = {
    name: queueName
    properties: {
      lockDuration: 'PT1M'
    }
  }
}


resource app 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: 'app3'
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
          image: 'mcr.microsoft.com/k8se/quickstart:latest' // this will be replaced with the image from the ACR in the post-deployment script
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: 'QUEUE_NAME'
              value: queueName
            }
            {
              name: 'SERVICE_BUS_NAMESPACE'
              value: '${serviceBusNamespace.name}.servicebus.windows.net'
            }
          ]
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
output appName string = app.name
