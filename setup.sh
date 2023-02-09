#!/bin/bash

# setup.sh
# Created by Luke Gregory (lukewgregory@gmail.com)
# 3/2/2023

# exit if any command fails
set -e

echo "<---Starting Jenkins Docker in Docker setup--->"

if (($# != 2))
then
  echo "1 arguments required..."
  echo "  1st : Jenkins admin password"
  echo "  2nd : Jenkins URL"
  exit 1
fi

# import common variables
source variables.sh

JENKINS_ADMIN_ID="admin"
JENKINS_ADMIN_PASSWORD=$1
JENKINS_URL=$2

echo "<---Creating docker network--->"
docker network create $NETWORK_NAME

echo "<---Starting DIND (docker in docker) container--->"
docker run \
  --name $DIND_CONTAINER_NAME \
  --restart=unless-stopped \
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

echo "<---Waiting for $DIND_CONTAINER_NAME to start--->"
sleep 30

echo "<---Get certificates from $DIND_CONTAINER_NAME--->"
CLIENT_KEY=$(docker exec jenkins-docker cat /certs/client/key.pem)
CLIENT_CERT=$(docker exec jenkins-docker cat /certs/client/cert.pem)
SERVER_CA=$(docker exec jenkins-docker cat /certs/server/ca.pem)

echo "<---Building Jenkins image--->"
docker build -t $JENKINS_IMAGE_NAME .

echo "<---Starting Jenkins container--->"
docker run \
  --name $JENKINS_CONTAINER_NAME \
  --restart=unless-stopped \
  --detach \
  --network $NETWORK_NAME \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=$CERTS_VOLUME_LOCATION \
  --env DOCKER_TLS_VERIFY=1 \
  --env JENKINS_ADMIN_ID=$JENKINS_ADMIN_ID \
  --env JENKINS_ADMIN_PASSWORD=$JENKINS_ADMIN_PASSWORD \
  --env JENKINS_URL=$JENKINS_URL \
  --env CLIENT_KEY="$CLIENT_KEY" \
  --env CLIENT_CERT="$CLIENT_CERT" \
  --env SERVER_CA="$SERVER_CA" \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --volume $DATA_VOLUME_NAME:$DATA_VOLUME_LOCATION \
  --volume $CERTS_VOLUME_NAME:$CERTS_VOLUME_LOCATION:ro \
  $JENKINS_IMAGE_NAME

echo "<---Copy Jcasc file to data volume--->"
docker cp $JCASC_FILE $JENKINS_CONTAINER_NAME:$DATA_VOLUME_LOCATION

echo "<---Script Complete--->"
