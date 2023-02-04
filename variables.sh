#!/bin/bash

# variables.sh
# Created by Luke Gregory (lukewgregory@gmail.com)
# 4/2/2023

NETWORK_NAME="jenkins"
DIND_CONTAINER_NAME="jenkins-docker"
JENKINS_IMAGE_NAME="myjenkins-blueocean:2.375.2-1"
JENKINS_OFFICIAL_IMAGE="jenkins/jenkins:2.375.2"
JENKINS_CONTAINER_NAME="jenkins-blueocean"
CERTS_VOLUME_NAME="jenkins-docker-certs"
CERTS_VOLUME_LOCATION="/certs/client"
DATA_VOLUME_NAME="jenkins-data"
DATA_VOLUME_LOCATION="/var/jenkins_home"
JCASC_FILE="casc.yaml"
