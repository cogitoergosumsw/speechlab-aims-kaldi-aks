#!/bin/bash
set -eu

export DOCKER_IMAGE=kaldi-speechlab
export KUBE_NAME=kaldi-feature-test
export USER_NAME=speechlablocal
export NAMESPACE=kaldi-test

cat <<EOF

KALDI SPEECH RECOGNITION SYSTEM deployed on Kubernetes
###################################################################
Setting up the worker node for deployment
###################################################################

EOF

echo -e '\033[0;32mPlease enter the master node IP address for Kubernetes cluster set up\n\033[m'
read -p 'Master node IP address: ' MASTER_IP

echo -e '\033[0;32mEnter the command to allow this worker node to join the Kubernetes cluster\033[m e.g\033[0;31m kubeadm join 172.16.0.5:6443 --token flk0z4.r11s0asq3v3bcno2 --discovery-token-ca-cert-hash sha256:aadf4c3170a30639e90b3b48732f7202747db842dc64c5292c48174388 \033[m\n'
read -p 'Join command: ' JOIN_COMMAND

echo -e '\033[0;32m\nPlease enter the Docker Hub username with the custom Docker image\033[m'
read -p 'Username: ' DOCKER_USERNAME

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

echo -e '\033[0;32m\nInstalling Kubernetes...\n\033[m'

sudo apt-get install -qy kubelet=1.15.7-00 kubeadm=1.15.7-00 kubectl=1.15.7-00
sudo apt-mark hold kubelet kubeadm kubectl

mkdir -p $HOME/.kube
sudo chown -R $(id -u):$(id -g) $HOME/.kube

sudo $JOIN_COMMAND

echo -e '\033[0;32m\nPulling custom Docker image...\n\033[m'
# change this to the repository to pull the Docker image from
docker pull $DOCKER_USERNAME/$DOCKER_IMAGE

# prompt to put the models in the models directory
sudo cp -r ./models/ /opt/models

sudo chown -R $(id -u):$(id -g) $HOME/.kube

# copy the Kubernetes config file from the master node to the worker node
echo -e '\033[0;32m\nBasic setup on worker node is complete. We are almost done!\n\033[m'
echo -e '\033[0;31mKey in the password to the master node to enable transfer of Kubernetes cluster config file! \n\033[m'
sudo scp $USER_NAME@$MASTER_IP:/home/$USER_NAME/.kube/config /home/$USER_NAME/.kube/config
sleep 1

echo -e '\033[0;32m\nWorker node setup complete.\n\033[m'

exit 0