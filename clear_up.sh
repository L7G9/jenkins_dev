#!/bin/bash

# clear_up.sh
# Created by Luke Gregory (lukewgregory@gmail.com)
# 3/2/2023

echo "<---Starting Jenkins Docker in Docker clear up--->"

# import common varibales
source variables.sh

echo "<---Stopping containers--->"
docker container stop $JENKINS_CONTAINER_NAME
docker container stop $DIND_CONTAINER_NAME

echo "<---Removing containers--->"
docker container rm $JENKINS_CONTAINER_NAME
docker container rm $DIND_CONTAINER_NAME

echo "<---Removing images--->"
docker image rm $JENKINS_IMAGE_NAME

echo "<---Removing docker network--->"
docker network rm $NETWORK_NAME

echo "<---Removing data volumes--->"
docker volume rm $DATA_VOLUME_NAME
docker volume rm $CERTS_VOLUME_NAME

echo "<---Script Complete--->"
