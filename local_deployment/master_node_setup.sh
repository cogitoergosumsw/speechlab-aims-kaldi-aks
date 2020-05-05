#!/bin/bash
set -eu

export DOCKER_IMAGE=kaldi-speechlab
export KUBE_NAME=kaldi-feature-test
export USER_NAME=speechlablocal
export NAMESPACE=kaldi-test
export NGINX_STICKY=nginx-sticky
PRIVATE_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

cat <<EOF

KALDI SPEECH RECOGNITION SYSTEM deployed on Kubernetes
###################################################################
Setting up the master node for deployment
###################################################################

EOF

echo -e '\033[0;32m\nUpdating system software...\n\033[m'
sleep 1

sudo apt update && sudo apt upgrade -y

echo -e '\033[0;32m\nInstalling Helm...\n\033[m'
sleep 1
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get >/tmp/install-helm.sh
chmod u+x /tmp/install-helm.sh
/tmp/install-helm.sh

echo -e '\033[0;32m\nInstalling Docker...\n\033[m'

sudo apt autoremove -y

sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo usermod -aG docker $USER

# might remove in the future to facilitate a better solution to push Docker image
echo -e '\033[0;32m\nPlease login to Docker Hub to push & pull the custom Docker image\033[m'
sudo docker login

echo -e '\033[0;32m\nPlease enter your Docker Hub username for subsequent setup\033[m'
read -p 'Username: ' DOCKER_USERNAME

echo -e '\033[0;32m\nInstalling Kubernetes...\n\033[m'

sudo apt-get install -qy kubelet=1.15.7-00 kubeadm=1.15.7-00 kubectl=1.15.7-00
sudo apt-mark hold kubelet kubeadm kubectl

echo -e '\033[0;32m\nInitializing Kubernetes Cluster...\033[m'
echo -e 'this process may take a few minutes, please wait patiently \n'
sleep 1

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 > kube_details.txt
echo -e '\033[0;32m\nKubernetes cluster is successfully set up.\n\033[m'

echo -e '\033[0;32m\nConfiguring Kubernetes Cluster...\n\033[m'
sleep 1

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown -R $(id -u):$(id -g) $HOME/.kube/config
sudo chown -R $USER_NAME /home/$USER_NAME/.kube/

# install flannel CNI
# Flannel is used as the network overlay, for nodes in the cluster to communicate with each other
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl create namespace $NAMESPACE
kubectl config set-context --current --namespace $NAMESPACE
kubectl taint nodes --all node-role.kubernetes.io/master-

# installing tiller, part of helm installation
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

kubectl apply -f docker/secret/run_kubernetes_secret.yaml
kubectl apply -f pv/local-models-pv.yaml
kubectl apply -f pv/local-models-pvc.yaml

echo -e '\033[0;32m\nBuilding custom SpeechLab Docker image...\n\033[m'
sleep 1

sudo cp ~/.kube/config docker/secret/
sleep 1
docker build -t $DOCKER_USERNAME/$DOCKER_IMAGE docker/
sleep 1
# change this to the repository to push the Docker image to
docker push $DOCKER_USERNAME/$DOCKER_IMAGE

# echo -e '\033[0;32mSetting up local Docker container registry on current node...\n\033[m'
# echo -e 'All containers in the cluster will pull the Docker image from the current container registry. \n'

# KIV: issue with worker nodes pulling image from local Docker registry
#######################################################################
# Local Docker registry is hosted on this machine at port 5000
# docker run -d -p 5000:5000 --name registry registry:2

# Tag custom Docker image to push to local registry
# docker image tag $DOCKER_IMAGE localhost:5000/$DOCKER_IMAGE

# Push custom Docker image to this registry
# docker push localhost:5000/$DOCKER_IMAGE
#######################################################################

echo -e '\033[0;32m\nPulling custom Docker image...\n\033[m'
# change this to the repository to pull the Docker image from
docker pull $DOCKER_USERNAME/kaldi-speechlab

echo -e '\033[0;32m\nInitialising Kaldi Speech Recognition System...\033[m'

# prompt to put the models in the models directory
sudo cp -r ./models/ /opt/models

echo -e '\033[0;32m\nModels copied to mount directory!\n\033[m'

# might need to give the Kubernetes cluster some time before deploying the application
sleep 10
helm install --name $KUBE_NAME --namespace $NAMESPACE docker/helm/$KUBE_NAME/
sleep 1

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
sleep 1
helm repo update
sleep 1
helm install --name $NGINX_STICKY ingress-nginx/ingress-nginx
sleep 1

kubectl apply -f nginx-sticky-server.yaml

kubectl patch svc $NGINX_STICKY-ingress-nginx-controller -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer", "externalIPs":["'$PRIVATE_IP'"]}}'

sudo swapoff -a

sudo chown -R $(id -u):$(id -g) $HOME/.kube/config

sudo chmod +x deploy-prometheus-grafana.sh

sudo ./deploy-prometheus-grafana.sh

echo -e '\033[0;32m\nCongratulations, the Kubernetes cluster is set up now!\n\033[m'
echo -e 'You can find the command for a worker node to join this Kubernetes cluster at \033[0;31m/local_deployment/kube_details.txt\033[m\n'

exit 0