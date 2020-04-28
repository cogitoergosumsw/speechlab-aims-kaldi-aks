#!/bin/bash
set -eu

cat <<EOF

KALDI SPEECH RECOGNITION SYSTEM deployed on Kubernetes
###################################################################
Setting up the master node for deployment
###################################################################

EOF

echo -e '\033[0;32mUpdating system software...\n\033[m'
sleep 1

sudo apt update && sudo apt upgrade -y

echo -e '\033[0;32mInstalling Docker...\n\033[m'

sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

echo -e '\033[0;32mInstalling Kubernetes...\n\033[m'

sudo apt install -y kubelet kubeadm kubectl -y

echo -e '\033[0;32mInitializing Kubernetes Cluster...\n\033[m'
echo 'this process may take a while, please wait patiently \n'
sleep 1

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 > kube_details.txt
echo 'Kubernetes cluster is successfully set up. \n'

echo -e '\033[0;32mConfiguring Kubernetes Cluster...\n\033[m'
sleep 1

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# install flannel CNI
# Flannel is used as the network overlay, for nodes in the cluster to communicate with each other
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo -e '\033[0;31mSetting up local Docker container registry on current node...\n\033[m'
echo 'All containers in the cluster will pull the Docker image from the current container registry. \n'
sleep 1



echo -e '\033[0;31mCongratulations, the Kubernetes cluster is set up now!\n\033[m'
echo -e 'you may now join other nodes to this Kubernetes cluster by running this command - \033[0;32msudo kubeadm join [your unique string from the kubeadm init command]\033[m \n'
echo 'you can find the unique string from \033[0;32mkube_details.txt\033[m \n'
sleep 1
