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
export CONTAINER_REGISTRY=kalditest
export DOCKER_IMAGE_NAME=kaldi-test-scaled
export AZURE_CONTAINER_NAME=online-models

az group create --name $RESOURCE_GROUP --location $LOCATION

az feature register --name VMSSPreview --namespace Microsoft.ContainerService

# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

az feature register --namespace "Microsoft.ContainerService" --name "AKSAzureStandardLoadBalancer"

# required to get the change propagated
az provider register --namespace Microsoft.ContainerService

# wait until "namespace": "Microsoft.ContainerService", "registrationState": "Registered",
az provider show -n Microsoft.ContainerService | grep registrationState

VMSS_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
AKS_LOAD_BALANCER_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}" | grep -i registered)

while [[ -z $VMSS_STATE ]]
do
    VMSS_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/VMSSPreview registration'
    sleep 3
    clear
    sleep 10
done
echo $VMSS_STATE

while [[ -z $AKS_LOAD_BALANCER_STATE ]]
do
    AKS_LOAD_BALANCER_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/AKSAzureStandardLoadBalancer registration'
    sleep 3
    clear
    sleep 5
done
echo $AKS_LOAD_BALANCER_STATE

# refresh the registration
az provider register --namespace Microsoft.ContainerService

az acr create --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --sku Standard

az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -l $LOCATION --sku Standard_LRS --kind StorageV2

export AZURE_STORAGE_CONNECTION_STRING=`az storage account show-connection-string -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -o tsv`

# Create the file share
az storage share create -n $MODEL_SHARE --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Echo storage account name and key
echo Storage account name: $STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY

az storage container create -n $AZURE_CONTAINER_NAME --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME

# TODO: edit this part to upload the correct model files
az storage blob upload --container-name $AZURE_CONTAINER_NAME --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME

sed "s/AZURE_STORAGE_ACCOUNT_DATUM/$STORAGE_ACCOUNT_NAME/g" docker/secret/run_kubernetes_secret_template.yaml > docker/secret/run_kubernetes_secret.yaml
sed -i "s|AZURE_STORAGE_ACCESS_KEY_DATUM|$STORAGE_KEY|g" docker/secret/run_kubernetes_secret.yaml

sed "s/AZURE_STORAGE_ACCOUNT_DATUM/$STORAGE_ACCOUNT_NAME/g" docker/secret/docker-compose-local_template.env > docker/secret/docker-compose-local.env
sed -i "s|AZURE_STORAGE_ACCESS_KEY_DATUM|$STORAGE_KEY|g" docker/secret/docker-compose-local.env

az aks create \
-g $RESOURCE_GROUP \
-n $KUBE_NAME \
--node-count 5 \
--enable-vmss \
--enable-cluster-autoscaler \
--min-count 5 \
--max-count 8 \
--node-vm-size Standard_B4ms \
--load-balancer-sku standard 

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_NAME

kubectl create namespace $NAMESPACE

# installing helm
# (preferably run on own local machine first)

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > /tmp/install-helm.sh
chmod u+x /tmp/install-helm.sh
/tmp/install-helm.sh

# create new static IP address for values.yaml
az network public-ip create --resource-group $RESOURCE_GROUP --name publicIP --sku Standard --allocation-method Static
PUBLIC_IP_ADDRESS=$(az network public-ip show --resource-group kaldi-test --name publicIP | grep -oP '(?<="ipAddress": ")[^"]*')
sed "s/STATIC_IP_ADDRESS/$PUBLIC_IP_ADDRESS/g" docker/helm/values.yaml.template > docker/helm/speechlab/values.yaml

# installing tiller, part of helm installation
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

az acr login -n kalditest
docker build -t $CONTAINER_REGISTRY.azurecr.io/$DOCKER_IMAGE_NAME:latest docker
docker push $CONTAINER_REGISTRY.azurecr.io/$DOCKER_IMAGE_NAME:latest

# after filling in the azure storage account details...
#########################################################
kubectl apply -f docker/secret/run_kubernetes_secret.yaml

# kubectl create secret generic volume-azurefile-storage-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY

# Create a service account to access private azure docker registry
##################################################################
kubectl create secret docker-registry azure-cr-secret \
--docker-server=https://kalditest.azurecr.io \
--docker-username=kalditest \
--docker-password=kalditestpassword \
--namespace $NAMESPACE

# Deploy to Kubernetes cluster
helm install --name=$KUBE_NAME --namespace=$NAMESPACE docker/helm/speechlab/

# kubectl create -f secret/secret.yml

# kubectl create -f pvc/nfs-server-azure-pvc.yml
# kubectl create -f pvc/nfs-pvc.yml

# kubectl create -f rc/nfs-server-rc.yml

# kubectl create -f services/nfs-server-service.yml

# NFS_IP=$(kubectl get service nfs-server | awk '{print $3}' | sed -n 2p)

# sed "s/NFS_CLUSTER_IP/$NFS_IP/g" pv/nfs-pv-template.yml > pv/nfs-pv.yml

# kubectl create -f pv/nfs-pv.yml

# rm pv/nfs-pv.yml

# kubectl create -f deployment/master-rc.yml

# kubectl create -f services/master-svc.yml

# MASTER_STATE=$(kubectl get service master-service | grep -i pending)
# while [[ ! -z $MASTER_STATE ]]
# do
#     sleep 10
#     echo 'waiting for master to init'
#     MASTER_STATE=$(kubectl get service master-service | grep -i pending)
# done

# kubectl create -f deployment/worker-rc.yml
