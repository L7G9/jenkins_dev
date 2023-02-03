#!/bin/bash

# setup.sh
# Created by Luke Gregory (lukewgregory@gmail.com)
# 3/2/2023


# exit if any command fails
set -e

echo "<---Starting Jenkins Docker in Docker setup--->"

if (($# != 3))
then
  echo "3 arguments required..."
  echo "  1nd : Jenkins admin Id"
  echo "  2rd : Jenkins admin password"
  echo "  3th : Jenkins URL"
  exit 1
fi

NETWORK_NAME="jenkins"

DIND_CONTAINER_NAME="jenkins-docker"
JENKINS_IMAGE_NAME="myjenkins-blueocean:2.375.2-1"
JENKINS_CONTAINER_NAME="jenkins-blueocean"
CERTS_VOLUME_NAME="jenkins-docker-certs"
CERTS_VOLUME_LOCATION="/certs/client"
DATA_VOLUME_NAME="jenkins-data"
DATA_VOLUME_LOCATION="/var/jenkins_home"
JCASC_FILE="casc.yaml"
JENKINS_ADMIN_ID=$1
JENKINS_ADMIN_PASSWORD=$2
JENKINS_URL=$3

echo "\n<---Creating docker network--->"
docker network create $NETWORK_NAME

echo "\n<---Adding Jcasc file to data volume--->"
docker run -v $DATA_VOLUME_NAME:$DATA_VOLUME_LOCATION --name helper busybox true
docker cp $JCASC_FILE helper:$DATA_VOLUME_NAME
docker rm helper

echo "\n<---Starting DIND (docker in docker) container--->"
docker run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network $NETWORK_NAME \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume $CERTS_VOLUME_NAME:$CERTS_VOLUME_LOCATION \
  --volume $DATA_VOLUME_NAME:$DATA_VOLUME_LOCATION \
  --publish 2376:2376 \
  docker:dind \
  --storage-driver overlay2

echo "\n<---Building Jenkins image--->"
docker build -t $JENKINS_IMAGE_NAME .

echo "\n<---Starting Jenkins container--->"
docker run \
  --name $JENKINS_CONTAINER_NAME \
  --restart=on-failure \
  --detach \
  --network jenkins \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=$CERTS_VOLUME_LOCATION \
  --env DOCKER_TLS_VERIFY=1 \
  --env JENKINS_ADMIN_ID=$JENKINS_ADMIN_ID \
  --env JENKINS_ADMIN_PASSWORD=$JENKINS_ADMIN_PASSWORD \
  --env JENKINS_URL=$JENKINS_URL \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --volume $DATA_VOLUME_NAME:$DATA_VOLUME_LOCATION \
  --volume $CERTS_VOLUME_NAME:$CERTS_VOLUME_LOCATION:ro \
  $JENKINS_IMAGE_NAME

echo "\n<---Script Complete--->"