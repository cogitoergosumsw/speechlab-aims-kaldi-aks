# SpeechLab - AIMS Speech Recognition System 

## About

This repository is meant to experiment with better architecture querying the speech recognition models. All the Azure resources can be deleted and regenerated via the `deploy.sh` script. 

## Usage

1. Install Azure CLI - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

2. Sign In with your Azure account via Azure CLI
`az login` - https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest
It is assumed that you have a valid Azure account with the permissions to create resources within the portal.

3. Give execute permission to deploy.sh
`chmod +x ./deploy.sh`

4. Run the deploy script in your terminal (for Unix/Linux machines)
`./deploy.sh`

The deploy.sh script will set up the Kuberbetes cluster, static public IP address, private docker registry, and the storage account all at once. It will also create the docker image of the kaldi image to be deployed on Helm. 


## Project Description

This project is supposed to use Kubernetes and Docker to create a container orchestration system that can handle incoming requests for the speech-to-text speech recognition system jointly developed by NTU and AISG. This system should be able to load balance the requests from the users and distribute the load evenly to all workers. With the aim of making the system scalable in the future, the Kubernetes setup should be able to scale according to the usage of the system. The system should be able to optimise the resources and best serve the needs of the users.

**Test with HTTP client**

- cd into the project directory

```bash
curl  -X PUT -T docker/audio/test.wav --header "model: SingaporeCS_0519NNET3" --header "content-type: audio/x-wav" "http://[STATIC_PUBLIC_IP]/client/dynamic/recognize"

```

## Architecture Design 

![Archtecture Diagram](./architecture_diagram.png)