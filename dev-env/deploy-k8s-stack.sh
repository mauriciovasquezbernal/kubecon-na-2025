#!/bin/bash

# Deploy applications to AKS cluster
echo "Starting AKS application deployment at $(date)"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
kubectl version --client

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Create YAML files from environment variables
echo "Creating Kubernetes manifests..."
echo "$PROMETHEUS_YAML" > prometheus.yaml
echo "$GRAFANA_YAML" > grafana.yaml
echo "$GRAFANA_SERVICE_YAML" > grafana-service.yaml

# Deploy prometheus
echo "Deploying Prometheus..."
kubectl apply -f prometheus.yaml

# Deploy grafana
echo "Deploying Grafana..."
kubectl apply -f grafana.yaml

# Deploy grafana service
echo "Deploying Grafana service..."
kubectl apply -f grafana-service.yaml

echo "Deployment completed successfully at $(date)"
