#!/bin/bash
set -u

az feature register --name VMSSPreview --namespace Microsoft.ContainerService

az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | awk '{print $2}'| sed -n 3p

# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview

# Install CLI to use kubectl on az
az aks install-cli

state=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)

while [[ -z $state ]]
do
    state=$(az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}" | grep -i registered)
    echo 'waiting for registration'
    sleep 3
    clear
    sleep 10
done
echo $state

KUBE_NAME='kaldi-feature-test'
RESOURCE_GROUP='kaldi-demos'

az provider register --namespace Microsoft.ContainerService

az group create --name $RESOURCE_GROUP --location southeastasia

az aks create -g $RESOURCE_GROUP -n $KUBE_NAME --node-count 5 --enable-vmss --enable-cluster-autoscaler --min-count 5 --max-count 8 --node-vm-size 'Standard_E2s_v3'

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_NAME

kubectl create -f pvc/nfs-server-azure-pvc.yml
 
kubectl create -f rc/nfs-server-rc.yml

kubectl create -f services/nfs-server-service.yml 

NFS_IP=$(kubectl get service nfs-server | awk '{print $3}' | sed -n 2p)
 
sed "s/NFS_CLUSTER_IP/$NFS_IP/g" pv/nfs-pv-template.yml > nfs-pv.yml
 
kubectl create -f nfs-pv.yml
 
rm nfs-pv.yml

kubectl create -f pvc/nfs-pvc.yml

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
