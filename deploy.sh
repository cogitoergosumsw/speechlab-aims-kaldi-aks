#!/bin/bash
set -u

# Install CLI to use kubectl on az
az aks install-cli

export KUBE_NAME=kaldi-feature-test
export RESOURCE_GROUP=kaldi-test
export STORAGE_ACCOUNT_NAME=kalditeststorage
export LOCATION=southeastasia
export MODEL_SHARE=model-azurefile-share
export NAMESPACE=kaldi-test

az provider register --namespace Microsoft.ContainerService

az group create --name $RESOURCE_GROUP --location $LOCATION

az feature register --name VMSSPreview --namespace Microsoft.ContainerService

# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

az feature register --namespace "Microsoft.ContainerService" --name "AKSAzureStandardLoadBalancer"

# required to get the change propagated
az provider register -n Microsoft.ContainerService

# wait until "namespace": "Microsoft.ContainerService", "registrationState": "Registered",
az provider show -n Microsoft.ContainerService | grep registrationState

VMSS_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
AKS_LOAD_BALANCER_STATE=$($(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}" | grep -i registered))

while [[ -z $VMSS_STATE ]]
do
    state=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/VMSSPreview registration'
    sleep 3
    clear
    sleep 10
done
echo $VMSS_STATE

while [[ -z $AKS_LOAD_BALANCER_STATE ]]
do
    state=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/AKSAzureStandardLoadBalancer registration'
    sleep 3
    clear
    sleep 5
done
echo $AKS_LOAD_BALANCER_STATE

# refresh the registration
az provider register --namespace Microsoft.ContainerService

az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -l $LOCATION --sku Standard_LRS --kind StorageV2

export AZURE_STORAGE_CONNECTION_STRING=`az storage account show-connection-string -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -o tsv`

# Create the file share
az storage share create -n $MODEL_SHARE --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Echo storage account name and key
echo Storage account name: $STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY

az aks create \
-g $RESOURCE_GROUP \
-n $KUBE_NAME \
--node-count 5 \
--enable-vmss \
--enable-cluster-autoscaler \
--min-count 5 \
--max-count 8 \
--enable-rbac \
--node-vm-size Standard_B4ms \
--load-balancer-sku standard 

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_NAME

kubectl create namespace $NAMESPACE

kubectl create secret generic volume-azurefile-storage-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY

# kubectl create -f secret/secret.yml

# kubectl create -f pvc/nfs-server-azure-pvc.yml
kubectl create -f pvc/nfs-pvc.yml

kubectl create -f rc/nfs-server-rc.yml

kubectl create -f services/nfs-server-service.yml

NFS_IP=$(kubectl get service nfs-server | awk '{print $3}' | sed -n 2p)

sed "s/NFS_CLUSTER_IP/$NFS_IP/g" pv/nfs-pv-template.yml > pv/nfs-pv.yml

kubectl create -f pv/nfs-pv.yml

rm pv/nfs-pv.yml

kubectl create -f deployment/master-rc.yml

kubectl create -f services/master-svc.yml

MASTER_STATE=$(kubectl get service master-service | grep -i pending)
while [[ ! -z $MASTER_STATE ]]
do
    sleep 10
    echo 'waiting for master to init'
    MASTER_STATE=$(kubectl get service master-service | grep -i pending)
done

kubectl create -f deployment/worker-rc.yml
