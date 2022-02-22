@description('Container registry name')
param acrName string

@description('Container registry sku')
param acrSku string

@description('Enable or disable admin user on your container registry')
param acrAdminUserEnabled bool

// @description('Role Guid for the ACR RBAC')
// param acrRole string

// @description('Principal Id value for the AKS cluster')
// param principalId string

@description('Deployment location')
param location string

@description('Resource tagging metadata.')
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}

// resource aksAcrPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(resourceGroup().id)
//   scope: acr
//   properties: {
//     principalId: principalId
//     roleDefinitionId: acrRole
//   }
// }

output acrLoginServer string = acr.properties.loginServer
