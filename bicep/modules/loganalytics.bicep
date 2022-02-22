@description('Name of the log analytics workspace.')
param name string

@description('Resource tagging metadata.')
param tags object

@description('Deployment location')
param location string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}

output id string = logAnalytics.id
output workspaceName string = logAnalytics.name
output workspaceId string = logAnalytics.properties.customerId
