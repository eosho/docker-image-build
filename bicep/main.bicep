targetScope = 'subscription'

@description('Deployment region.')
param region string = 'eastus2'

@description('Deployment prefix')
param prefix string

@description('Deployment environment name')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('App resource group name')
param resourceGroupName string = '${environmentName}-${prefix}-aks-rg-${region}-01'

@description('Key vault resource name')
param keyVaultName string = '${environmentName}-${prefix}-kv-01'

@description('Azure AD object Id for key vault')
param aadObjectId string

@description('SPN Client secret value')
param spnClientSecretValue string

@description('SPN Client Id value')
param spnClientIdValue string

@description('Name of the Azure log analytics workspace for logging and metrics')
param logAnalyticsWorkspaceName string = '${environmentName}-${prefix}-log-01'

// @description('Name of the AKS cluster')
// param aksClusterName string = '${environmentName}-${prefix}-aks-01'

// @description('The size of the Virtual Machine.')
// param agentVMSize string = 'Standard_DS2_v2'

// @description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize')
// param osDiskSizeGB int = 60

// @description('Version of the kubernetes agent')
// param kubernetesVersion string = '1.20.7'

// @description('Login username for the kubernetes agent')
// param aksClusterAdminUsername string = 'groot'

// @description('Public key for kubernets agent user')
// param aksClusterAdminPublicKey string

@minLength(5)
@maxLength(50)
@description('Container registry name')
param acrName string = '${environmentName}${prefix}acr01'

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Premium'

// @description('Role Guid for the ACR RBAC')
// param acrRole string

@description('Azure resource tags metadata')
param resourceTags object = {
  CostCenter: 'Marketing Technology'
  LegalSubEntity: 'Walgreen Co'
  Sensitivity: 'Non-Sensitive'
  SubDivision: 'Digital Engineering'
  Department: 'Digital Engineering'
  SenType: 'Not-Applicable'
}

/*
 * Resource group
*/
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: resourceGroupName
  location: region
  tags: resourceTags
}

/*
 * Key vault
*/
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeploy'
  scope: resourceGroup(rg.name)
  params: {
    location: region
    tags: resourceTags
    objectId: aadObjectId
    vaultName: keyVaultName
  }
}

/*
 * Key vault secret - client Id
*/
module keyvaultSPNClientId 'modules/keyvaultsecret.bicep' = {
  name: 'kvSecretClientId'
  scope: resourceGroup(rg.name)
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'spnClientId'
    secretValue: spnClientIdValue
  }
}

/*
 * Key vault secret - client secret
*/
module keyvaultSPNClientSecret 'modules/keyvaultsecret.bicep' = {
  name: 'kvSecretClientSecret'
  scope: resourceGroup(rg.name)
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'spnClientSecret'
    secretValue: spnClientSecretValue
  }
}

/*
 * Log Analytics
*/
module logAnalytics 'modules/loganalytics.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'logAnalyticsDeploy'
  params: {
    location: region
    name: logAnalyticsWorkspaceName
    tags: resourceTags
  }
}

/*
 * ACR
*/
module acr 'modules/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrDeploy'
  params: {
    acrAdminUserEnabled: true
    acrName: acrName
    //acrRole: acrRole
    acrSku: acrSku
    //principalId: aks.outputs.identity
    location: region
    tags: resourceTags
  }
}

/*
 * AKS
*/
// module aks 'modules/aks.bicep' = {
//   scope: resourceGroup(rg.name)
//   name: 'aksDeploy'
//   params: {
//     logAnalyticsWorkspaceId: logAnalytics.outputs.id
//     osDiskSizeGB: osDiskSizeGB
//     location: region
//     aksClusterName: aksClusterName
//     kubernetesVersion: kubernetesVersion
//     agentVMSize: agentVMSize
//     aksClusterAdminPublicKey: aksClusterAdminPublicKey
//     aksClusterAdminUsername: aksClusterAdminUsername
//     tags: resourceTags
//   }
// }
