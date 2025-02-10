// Front Door Resources
// CLI Details can be found here:
// https://learn.microsoft.com/en-us/azure/container-apps/how-to-integrate-with-azure-front-door

param frontDoorProfileName string
param containerAppEnvId string
param containerAppFqdn string
param appendix string
param location string

var frontDoorOriginGroupName = 'fdog-${appendix}'
var frontDoorOriginName = 'fdon-${appendix}'
var frontDoorRouteName = 'fdrn-${appendix}'
var frontDoorEndpointName = 'afd-${appendix}'


resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}


resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}


resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: null
  }
}


resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-09-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: containerAppFqdn
    originHostHeader: containerAppFqdn
    priority: 1
    weight: 500
    sharedPrivateLinkResource: {
      groupId: 'managedEnvironments'
      privateLink: {
        id: containerAppEnvId
      }
      privateLinkLocation: location
      requestMessage: 'AFD Private Link Request'
      status: 'Approved'
    }
  }
}


resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

// TODO: spit out the needed outputs