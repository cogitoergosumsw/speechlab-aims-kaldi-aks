# SpeechLab - Speech Recognition System Local Deployment

## Description

This portion of the project is to test a local deployment of the Speech Lab Speech Recognition System. The local deployment would not make use of any public cloud resources e.g Azure to carry out its functions. 

## Changes made to the original architecture

1. 1 master node to host the Docker cointainer registry

This particular node is deployed to host the registry where other nodes will pull the custom Docker image from. This will replace the Azure container registry used to host the Docker image. 

2. Speech recognition models are uploaded to each node 

Azure Files will be replaced with the workers mounting the models directly on the filesystem. This will also reduce the time taken to download the files from Azure Files. 
