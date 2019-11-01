# SpeechLab - AIMS Speech Recognition System 

## Project Description

This project is supposed to use Kubernetes and Docker to create a container orchestration system that can handle incoming requests for the speech-to-text speech recognition system jointly developed by NTU and AISG. This system should be able to load balance the requests from the users and distribute the load evenly to all workers. With the aim of making the system scalable in the future, the Kubernetes setup should be able to scale according to the usage of the system. The system should be able to optimise the resources and best serve the needs of the users.

## Architecture Design 

![Archtecture Diagram](./architecture_diagram.png)