// Parameters
@description('The name of the AKS cluster')
param aksClusterName string = 'aks-kubeconna2025'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the VM')
param vmName string = 'demo-vm'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

// Generate a random password for the VM using deployment ID and resource group
var adminPassword = '${take(uniqueString(resourceGroup().id, deployment().name, vmName), 10)}Aa1!'

// AKS Cluster - Minimal configuration for demo
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: aksClusterName
    enableRBAC: true

    // Single node pool with minimal settings
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: 2
        vmSize: 'Standard_D8s_v3'
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
      }
    ]
  }
}

// User-assigned managed identity for deployment script and VM
resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'deployment-identity'
  location: location
}

// Role assignment to give the identity access to the AKS cluster (used by both deployment script and VM)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentIdentity.id, 'Azure Kubernetes Service Cluster User Role')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4abbcc35-e782-43d8-92c5-2d3f1bd2253f') // Azure Kubernetes Service Cluster User Role
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deployment script to deploy apps to AKS
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deploy-to-aks'
  location: location
  dependsOn: [aksCluster, roleAssignment]
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT30M'
    retentionInterval: 'PT4H'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'PROMETHEUS_YAML'
        value: loadTextContent('prometheus.yaml')
      }
      {
        name: 'GRAFANA_YAML'
        value: loadTextContent('grafana.yaml')
      }
    ]
    scriptContent: loadTextContent('deploy-k8s-stack.sh')
  }
}

// Virtual Network for VM
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 102
          protocol: 'TCP'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// Public IP for VM
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${vmName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network Interface for VM
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  dependsOn: [aksCluster, roleAssignment]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity.id}': {}
    }
  }
  tags: {
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D8s_v3'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(loadTextContent('vm-setup.sh'))
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Outputs
@description('The FQDN of the AKS cluster')
output aksClusterFqdn string = aksCluster.properties.fqdn

@description('The name of the AKS cluster')
output aksClusterName string = aksCluster.name

@description('The name of the VM')
output vmName string = vm.name

@description('The public IP address of the VM')
output vmPublicIP string = publicIP.properties.ipAddress

@description('SSH command to connect to the VM')
output sshCommand string = 'ssh ${adminUsername}@${publicIP.properties.ipAddress}'

@description('VM can now access AKS cluster using kubectl')
output vmKubectlAccess string = 'VM has been configured with kubectl access to AKS cluster. SSH to the VM and use kubectl commands.'

@description('Commands to access your deployed applications')
output k8sCommands string = 'kubectl get all -n demo-apps'

@description('Deployment script logs location')
output deploymentScriptLogs string = 'Check deployment script logs with: az deployment-scripts show-log --resource-group ${resourceGroup().name} --name deploy-to-aks'

//@description('Deployment script result')
//output deploymentResult object = {
//  scriptName: deploymentScript.name
//  provisioningState: deploymentScript.properties.provisioningState
//  outputs: deploymentScript.properties.outputs
//}
