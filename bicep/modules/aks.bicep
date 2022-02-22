@description('Name of the AKS cluster')
param aksClusterName string

@description('Resource Id for the log analytics workspace')
param logAnalyticsWorkspaceId string

@description('Deployment location')
param location string

@description('The size of the Virtual Machine.')
param agentVMSize string

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize')
param osDiskSizeGB int

@description('Version of the kubernetes agent')
param kubernetesVersion string

@description('Login username for the kubernetes agent')
param aksClusterAdminUsername string

@description('Public key for kubernets agent user')
param aksClusterAdminPublicKey string

@description('Resource tagging metadata.')
param tags object

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-03-01' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${aksClusterName}-dnsprefix'
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'wbaagentpool'
        count: 2
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        osDiskSizeGB: osDiskSizeGB
        enableAutoScaling: false
      }
    ]
    linuxProfile: {
      adminUsername: aksClusterAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: aksClusterAdminPublicKey
          }
        ]
      }
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

output identity string = aksCluster.identity.principalId
output aksName string = aksCluster.name
