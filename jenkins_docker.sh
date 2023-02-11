#!/usr/bin/env bash
#===============================================================================
# jenkins_docker.sh
# Description:
#   Installs and configures, or removes Jenkins on Docker on local host for use 
#   in a development environment
# Author:
#   Luke Gregory (lukewgregory@gmail.com)
# Date:
#   10/2/2023
# Version:
#   1.0
# Usage:
#   Setup
#     ./jenkins_docker.sh --admin_password pword --url 12.2.54.13
#   Remove
#     ./jenkins_docker.sh --remove --data --certs
# Notes:
#   Requires Docker, tested on version 23.0.0-rc.3, build e1152b2
#   Requires Dockerfile, plugins.txt and casc.yaml in same directory as script
#     Dockerfile to build a custom Jenkins image
#     plugins.txt is a list of Jenkins plugins to be installed 
#     casc.yaml is the Jenkins Configuation as Code
#   Examples which can be edited be 
# Bash Version
#   5.1.16(1)-release
#===============================================================================

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] -p password -u url
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-r] [-d] [-c]

Installs and configures Jenkins on docker by...
- Creating a jenkins network in Docker
- Running the Docker in Docker container
- Geting the certifiacte details from Docker in Docker container
- Creating a custom image for Jenkins with the plugins listed in plugin file
- Running the Jenkins container
- Copying Jenkins Configuation as Code file to the data volume

Available options:
-c, --cert             Remove certificate volume (use with -r)
-d, --data             Remove data volume (use with -r)
-h, --help             Print this help and exit
-p, --password string  Password for Jenkins admin account
-r, --remove           Remove Docker network, images and containers
-u, --url string       Jenkins URL
EOF
  exit
}

# Constants
readonly NETWORK_NAME="jenkins"
readonly DIND_CONTAINER_NAME="jenkins-docker"
readonly JENKINS_IMAGE_NAME="myjenkins-blueocean:2.375.2-1"
readonly JENKINS_OFFICIAL_IMAGE="jenkins/jenkins:2.375.2"
readonly JENKINS_CONTAINER_NAME="jenkins-blueocean"
readonly CERTS_VOLUME_NAME="jenkins-docker-certs"
readonly CERTS_VOLUME_LOCATION="/certs/client"
readonly DATA_VOLUME_NAME="jenkins-data"
readonly DATA_VOLUME_LOCATION="/var/jenkins_home"
readonly JCASC_FILE="casc.yaml"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

#===============================================================================
# Parse & validate arugments from command line then call setup_jenkins or 
# remove_jenkins
# Globals:
#   None
# Arguments:
#   Command line arguments, an array of strings.  
# Outputs:
#   Writes location to stdout
#===============================================================================
parse_params() {

  # Default values of variables set from params
  local admin_password=''
  local jenkins_url=''
  local remove_jenkins=0
  local remove_data_volume=0
  local remove_cert_volume=0

  # 
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -r | --remove) remove_jenkins=1 ;;
    -d | --data) remove_data_volume=1 ;;
    -c | --cert) remove_cert_volume=1 ;;
    -p | --password)
      admin_password="${2-}"
      shift
      ;;
    -u | --url)
      jenkins_url="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  #
  args=("$@")

  # Check correct params and flags, then call setup or remove as required
  if (( $remove_jenkins == 0)); then
    [[ -z "${admin_password-}" ]] && die "Missing required parameter: password"
    [[ -z "${jenkins_url-}" ]] && die "Missing required parameter: url"
    (( $remove_data_volume == 1 )) && die "Unexpeected flag: data"
    (( $remove_cert_volume == 1 )) && die "Unexpeected flag: cert"
    (( ${#args[@]} > 0 )) && die "No arguments expected"

    setup_jenkins "${admin_password}" "${jenkins_url}"
  else
    [[ -n "${admin_password-}" ]] && die "Unexpeected parameter: password"
    [[ -n "${jenkins_url-}" ]] && die "Unexpeected parameter: url"
    (( ${#args[@]} > 0 )) && die "No arguments expected"

    remove_jenkins "${remove_data_volume}" "${remove_cert_volume}"
  fi

  return 0
}

#===============================================================================
# Setup & configure a Jenkins development environment with Docker on local host
# Globals:
#   NETWORK_NAME
#   DIND_CONTAINER_NAME
#   CERTS_VOLUME_NAME
#   CERTS_VOLUME_LOCATION
#   DATA_VOLUME_NAME
#   DATA_VOLUME_LOCATION
#   JENKINS_IMAGE_NAME
#   JENKINS_CONTAINER_NAME
#   JCASC_FILE
# Arguments:
#   Password for Jenkins admin account, a password.  
#   Jenkins URL, a URL.  
# Outputs:
#   Writes location to stdout
#===============================================================================
setup_jenkins() {

  # Store aguments
  local jenkins_admin_password="$1"
  local jenkins_url="$2"

  # Create network
  docker network create "${NETWORK_NAME}"

  # Run Docker in Doocker container
  docker run \
    --name "${DIND_CONTAINER_NAME}" \
    --restart=unless-stopped \
    --detach \
    --privileged \
    --network "${NETWORK_NAME}" \
    --network-alias docker \
    --env DOCKER_TLS_CERTDIR=/certs \
    --volume "${CERTS_VOLUME_NAME}:${CERTS_VOLUME_LOCATION}" \
    --volume "${DATA_VOLUME_NAME}:${DATA_VOLUME_LOCATION}" \
    --publish 2376:2376 \
    docker:dind \
    --storage-driver overlay2

  # Wait for Docker in Docker container to start
  sleep 30

  # Get certificates from Docker in Docker container
  local client_key=$(docker exec jenkins-docker cat /certs/client/key.pem)
  local client_cert=$(docker exec jenkins-docker cat /certs/client/cert.pem)
  local server_ca=$(docker exec jenkins-docker cat /certs/server/ca.pem)

  # Build custom Jenkins Docker image
  docker build -t "${JENKINS_IMAGE_NAME}" .

  # Run Jenkin container
  docker run \
    --name "${JENKINS_CONTAINER_NAME}" \
    --restart=unless-stopped \
    --detach \
    --network "${NETWORK_NAME}" \
    --env DOCKER_HOST=tcp://docker:2376 \
    --env DOCKER_CERT_PATH="${CERTS_VOLUME_LOCATION}" \
    --env DOCKER_TLS_VERIFY=1 \
    --env JENKINS_ADMIN_ID="admin" \
    --env JENKINS_ADMIN_PASSWORD="${jenkins_admin_password}" \
    --env JENKINS_URL="${jenkins_url}" \
    --env CLIENT_KEY="${client_key}" \
    --env CLIENT_CERT="${client_cert}" \
    --env SERVER_CA="${server_ca}" \
    --publish 8080:8080 \
    --publish 50000:50000 \
    --volume "${DATA_VOLUME_NAME}:${DATA_VOLUME_LOCATION}" \
    --volume "${CERTS_VOLUME_NAME}:${CERTS_VOLUME_LOCATION}:ro" \
    "${JENKINS_IMAGE_NAME}"

  # Copy Jcasc file to data volume
  docker cp ${JCASC_FILE} "${JENKINS_CONTAINER_NAME}:${DATA_VOLUME_LOCATION}"
}

#===============================================================================
# Remove Jenkins development environment from local host
# Globals:
#   JENKINS_CONTAINER_NAME
#   DIND_CONTAINER_NAME
#   JENKINS_IMAGE_NAME
#   NETWORK_NAME
#   DATA_VOLUME_NAME
#   CERTS_VOLUME_NAME
# Arguments:
#   Remove data volume, a flag.  
#   Remove certificate volume, a flag.
# Outputs:
#   Writes location to stdout
#===============================================================================
remove_jenkins() {

  # Store aguments
  local remove_data_volume=$1
  local remove_cert_volume=$2

  # Stop & remove containers
  docker container stop "${JENKINS_CONTAINER_NAME}"
  docker container stop "${DIND_CONTAINER_NAME}"
  docker container rm "${JENKINS_CONTAINER_NAME}"
  docker container rm "${DIND_CONTAINER_NAME}"

  # Remove custom Jenkins image
  docker image rm "${JENKINS_IMAGE_NAME}"

  # Remove Docker network
  docker network rm "${NETWORK_NAME}"

  # Remove volumes
  (( $remove_data_volume == 1 )) && docker volume rm "${DATA_VOLUME_NAME}"
  (( $remove_cert_volume == 1 )) && docker volume rm "${CERTS_VOLUME_NAME}"
}

# Start script by parsing parameters
parse_params "$@"
