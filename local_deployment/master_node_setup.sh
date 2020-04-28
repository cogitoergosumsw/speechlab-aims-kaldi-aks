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
