#!/bin/bash
set -u

# installing helm
# (preferably run on own local machine first)
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > /tmp/install-helm.sh
chmod u+x /tmp/install-helm.sh
/tmp/install-helm.sh

# Install CLI to use kubectl on az
az aks install-cli

export KUBE_NAME=kaldi-feature-test
export RESOURCE_GROUP=kaldi-test
export STORAGE_ACCOUNT_NAME=kalditeststorage
export LOCATION=southeastasia
export MODEL_SHARE=online-models
export NAMESPACE=kaldi-test
export CONTAINER_REGISTRY=kalditest
export DOCKER_IMAGE_NAME=kalditestscaled
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

while [[ -z $VMSS_STATE ]]; do
    VMSS_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/VMSSPreview registration'
    sleep 3
    clear
    sleep 10
done
echo $VMSS_STATE

while [[ -z $AKS_LOAD_BALANCER_STATE ]]; do
    AKS_LOAD_BALANCER_STATE=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKSAzureStandardLoadBalancer')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'Waiting for Microsoft.ContainerService/AKSAzureStandardLoadBalancer registration'
    sleep 3
    clear
    sleep 5
done
echo $AKS_LOAD_BALANCER_STATE

# refresh the registration
az provider register --namespace Microsoft.ContainerService

az acr create --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --sku Standard --admin-enabled true

az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -l $LOCATION --sku Standard_LRS --kind StorageV2

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -o tsv)

# Create the file share
az storage share create -n $MODEL_SHARE --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

# Echo storage account name and key
echo Storage account name: $STORAGE_ACCOUNT_NAME
echo Storage account key: $STORAGE_KEY

az storage container create -n $AZURE_CONTAINER_NAME --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME

# prompt to put the models in the models directory
NUM_MODELS=$(find ./models/ -maxdepth 1 -type d | wc -l)
if [ $NUM_MODELS -gt 1 ]; then
    echo "Uploading models to storage..."
    # az storage blob upload-batch -d $AZURE_CONTAINER_NAME --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME -s models/
    az storage file upload-batch -d $MODEL_SHARE --account-key $STORAGE_KEY --account-name $STORAGE_ACCOUNT_NAME -s models/
else
    printf "\n"
    printf "##########################################################################\n"
    echo "Please put at least one model in the ./models directory before continuing"
    printf "##########################################################################\n"

    exit 1
fi
echo "$((NUM_MODELS - 1)) models uploaded to Azure File Share storage | Azure Files: $MODEL_SHARE"

sed "s/AZURE_STORAGE_ACCOUNT_DATUM/$STORAGE_ACCOUNT_NAME/g" docker/secret/run_kubernetes_secret_template.yaml >docker/secret/run_kubernetes_secret.yaml
sed -i "s|AZURE_STORAGE_ACCESS_KEY_DATUM|$STORAGE_KEY|g" docker/secret/run_kubernetes_secret.yaml

sed "s/AZURE_STORAGE_ACCOUNT_DATUM/$STORAGE_ACCOUNT_NAME/g" docker/secret/docker-compose-local_template.env >docker/secret/docker-compose-local.env
sed -i "s|AZURE_STORAGE_ACCESS_KEY_DATUM|$STORAGE_KEY|g" docker/secret/docker-compose-local.env

# get docker registry password
CONTAINER_REGISTRY_PASSWORD=$(az acr credential show -n kalditest --query passwords[0].value | grep -oP '"\K[^"]+')
echo "Container Registry | username: $CONTAINER_REGISTRY | password: $CONTAINER_REGISTRY_PASSWORD"

# ACR_ID=$(az acr show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --query id --output tsv)

az aks create \
    -g $RESOURCE_GROUP \
    -n $KUBE_NAME \
    --node-count 3 \
    --enable-vmss \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 15 \
    --node-vm-size Standard_B4ms \
    --kubernetes-version 1.15.5 \
    --zones 1 2 3 \
    --vm-set-type VirtualMachineScaleSets \
    # --attach-acr $ACR_ID \
    --load-balancer-sku standard

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_NAME --admin --overwrite-existing
sleep 1
CURRENT_DIRECTORY=$(pwd)

sudo cp ~/.kube/config $CURRENT_DIRECTORY/docker/secret/
sleep 1

docker build -t $CONTAINER_REGISTRY.azurecr.io/$DOCKER_IMAGE_NAME docker/
sleep 1
# there might be an issue with Docker login to Azure private container registry
# in that case try out this StackOverflow link to see if solves the issue - https://stackoverflow.com/questions/50151833/cannot-login-to-docker-account
# docker login $CONTAINER_REGISTRY.azurecr.io --username $CONTAINER_REGISTRY --password $CONTAINER_REGISTRY_PASSWORD
az acr login --name $CONTAINER_REGISTRY --username $CONTAINER_REGISTRY --password $CONTAINER_REGISTRY_PASSWORD
sleep 1
docker push $CONTAINER_REGISTRY.azurecr.io/$DOCKER_IMAGE_NAME

# create 'kaldi-test' namespace within cluster
kubectl create namespace $NAMESPACE


export STATIC_PUBLIC_IP_NAME=kaldi-static-ip
export AKS_NODE_RESOURCE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
export PUBLIC_DNS_NAME="kaldi-feature-test"

# create new static IP address for values.yaml
az network public-ip create --resource-group $AKS_NODE_RESOURCE_GROUP --name $STATIC_PUBLIC_IP_NAME --sku Standard --allocation-method static
sleep 3
PUBLIC_IP_ADDRESS=$(az network public-ip show --resource-group $AKS_NODE_RESOURCE_GROUP --name $STATIC_PUBLIC_IP_NAME --query ipAddress --output tsv)
sed "s/STATIC_IP_ADDRESS/$PUBLIC_IP_ADDRESS/g" docker/helm/values.yaml.template >docker/helm/kaldi-feature-test/values.yaml

# Get the resource-id of the public ip
PUBLICIPID=$(az network public-ip show --resource-group $AKS_NODE_RESOURCE_GROUP --name $STATIC_PUBLIC_IP_NAME --query id -o tsv)
# Update public ip address with DNS name
az network public-ip update --ids $PUBLICIPID --dns-name $PUBLIC_DNS_NAME

# installing tiller, part of helm installation
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

# Create a service account to access private azure docker registry
##################################################################
kubectl create secret docker-registry azure-cr-secret \
    --docker-server=https://kalditest.azurecr.io \
    --docker-username=$CONTAINER_REGISTRY \
    --docker-password=$CONTAINER_REGISTRY_PASSWORD \
    --namespace $NAMESPACE

export MODELS_FILESHARE_SECRET="models-files-secret"
# k8 secret for accessing Azure File share
kubectl create secret generic $MODELS_FILESHARE_SECRET \
    --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY \
    --namespace $NAMESPACE

# after filling in the azure storage account details...
#########################################################
kubectl apply -f docker/secret/run_kubernetes_secret.yaml

# create the persistent volume that will store the models
kubectl apply -f pv/kaldi-models-pv.yaml
kubectl apply -f pv/kaldi-models-pvc.yaml

# Deploy to Kubernetes cluster
sleep 30
helm install --name $KUBE_NAME --namespace $NAMESPACE docker/helm/kaldi-feature-test/

exit 0
