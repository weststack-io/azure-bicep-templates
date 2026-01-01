/* This Bicep file creates a Linux function app with VNet integration and private endpoints
that connects to Azure Storage by using managed identities with Microsoft Entra ID. */

//********************************************
// Parameters
//********************************************

@description('Primary region for all Azure resources.')
@minLength(1)
param location string = resourceGroup().location

@description('Language runtime used by the function app.')
@allowed(['dotnet-isolated', 'python', 'java', 'node', 'powerShell'])
param functionAppRuntime string = 'python'

@description('Target language version used by the function app.')
@allowed(['3.10', '3.11', '7.4', '8.0', '9.0', '10', '11', '17', '20'])
param functionAppRuntimeVersion string = '3.11'

@description('The maximum scale-out instance count limit for the app.')
@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100

@description('The memory size of instances used by the app.')
@allowed([2048, 4096])
param instanceMemoryMB int = 2048

@description('A unique token used for resource name generation.')
@minLength(3)
param resourceToken string = toLower(uniqueString(subscription().id, location, 'myapp', 'dev'))

@description('A globally unique name for your deployed function app.')
param appName string = 'func-${resourceToken}'

@description('VNet address prefix.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Function app subnet address prefix.')
param functionSubnetPrefix string = '10.0.1.0/24'

@description('Private endpoint subnet address prefix.')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

//********************************************
// Variables
//********************************************

var deploymentStorageContainerName = 'app-package-${take(appName, 32)}-${take(resourceToken, 7)}'
var storageAccountAllowSharedKeyAccess = false
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageQueueDataContributorId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var storageTableDataContributorId = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
var monitoringMetricsPublisherId = '3913510d-42f4-4e42-8a64-420c390055eb'

//********************************************
// Networking resources
//********************************************

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${resourceToken}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-function'
        properties: {
          addressPrefix: functionSubnetPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'snet-privateendpoint'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

resource privateDnsZoneBlobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneBlob
  name: 'link-blob'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateDnsZoneTable 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.table.${environment().suffixes.storage}'
  location: 'global'
}

resource privateDnsZoneTableLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneTable
  name: 'link-table'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateDnsZoneQueue 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.queue.${environment().suffixes.storage}'
  location: 'global'
}

resource privateDnsZoneQueueLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZoneQueue
  name: 'link-queue'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

//********************************************
// Azure resources
//********************************************

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${resourceToken}'
  location: location
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableLocalAuth: true
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: 'st${resourceToken}'
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: storageAccountAllowSharedKeyAccess
    dnsEndpointType: 'Standard'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
  }
  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {}
    }
    resource deploymentContainer 'containers' = {
      name: deploymentStorageContainerName
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-blob-${resourceToken}'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/snet-privateendpoint'
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateEndpointBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpointBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config-blob'
        properties: {
          privateDnsZoneId: privateDnsZoneBlob.id
        }
      }
    ]
  }
}

resource privateEndpointTable 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-table-${resourceToken}'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/snet-privateendpoint'
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-table'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
}

resource privateEndpointTableDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpointTable
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config-table'
        properties: {
          privateDnsZoneId: privateDnsZoneTable.id
        }
      }
    ]
  }
}

resource privateEndpointQueue 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-queue-${resourceToken}'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/snet-privateendpoint'
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-queue'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
}

resource privateEndpointQueueDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpointQueue
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config-queue'
        properties: {
          privateDnsZoneId: privateDnsZoneQueue.id
        }
      }
    ]
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uai-data-owner-${resourceToken}'
  location: location
}

resource roleAssignmentBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storage.id, userAssignedIdentity.id, 'Storage Blob Data Owner')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storage.id, userAssignedIdentity.id, 'Storage Blob Data Contributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentQueueStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storage.id, userAssignedIdentity.id, 'Storage Queue Data Contributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentTableStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, storage.id, userAssignedIdentity.id, 'Storage Table Data Contributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageTableDataContributorId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentAppInsights 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, applicationInsights.id, userAssignedIdentity.id, 'Monitoring Metrics Publisher')
  scope: applicationInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherId)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

//********************************************
// Function app with VNet integration (Linux)
//********************************************

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-${resourceToken}'
  location: location
  kind: 'linux'
  sku: {
    name: 'P0v3'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    reserved: true
    virtualNetworkSubnetId: '${vnet.id}/subnets/snet-function'
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      vnetRouteAllEnabled: true
      linuxFxVersion: '${upper(functionAppRuntime)}|${functionAppRuntimeVersion}'
    }
  }
  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage__accountName: storage.name
      AzureWebJobsStorage__credential: 'managedidentity'
      AzureWebJobsStorage__clientId: userAssignedIdentity.properties.clientId
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${userAssignedIdentity.properties.clientId};Authorization=AAD'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: functionAppRuntime
      WEBSITE_CONTENTOVERVNET: '1'
      WEBSITE_DNS_SERVER: '168.63.129.16'
    }
  }
}
