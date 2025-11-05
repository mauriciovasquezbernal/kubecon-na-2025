#!/bin/bash

set -eoux pipefail

export IG_VERSION=v0.46.0
export IG_ARCH=amd64

sudo apt-get update

# install az
sudo apt-get install -y \
    apt-transport-https ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
  gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

AZ_DIST=$(lsb_release -cs)
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

sudo apt-get update
sudo apt-get install azure-cli

# Configure kubectl to connect to AKS cluster
# Get the resource group name from instance metadata
RESOURCE_GROUP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2021-02-01&format=text")

# Get the AKS cluster name (assuming it follows the naming pattern)
CLUSTER_NAME="aks-kubeconna2025"

# Login using the VM's managed identity
az login --identity

# Get AKS credentials and configure kubectl
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME -f /home/azureuser/.kube/config
sudo chown azureuser /home/azureuser/.kube/config

# install docker
sudo apt-get install -y docker.io
sudo usermod -aG docker azureuser

# prepull builder image
sudo -E docker pull ghcr.io/inspektor-gadget/gadget-builder:${IG_VERSION}

# install ig binary
curl -sL https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${IG_VERSION}/ig-linux-${IG_ARCH}-${IG_VERSION}.tar.gz | sudo tar -C /usr/local/bin -xzf - ig

# install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${IG_ARCH}/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# install kubectl-gadget
curl -sL https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${IG_VERSION}/kubectl-gadget-linux-${IG_ARCH}-${IG_VERSION}.tar.gz  | sudo tar -C /usr/local/bin -xzf - kubectl-gadget

# Verify the connection
kubectl cluster-info
