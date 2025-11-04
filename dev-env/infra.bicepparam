using './infra.bicep'

// Optional parameters - only override if needed
param aksClusterName = 'aks-kubeconna2025'
param location = 'southcentralus'
param vmName = 'demo-vm'
param adminUsername = 'azureuser'
// adminPassword is now auto-generated in the Bicep template
