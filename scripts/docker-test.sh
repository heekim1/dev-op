#!/usr/bin/env bash

set -e

# A script to test the docker image for BFX

DOCKER_CMD_FILE=$1
if [ ! -f $DOCKER_CMD_FILE ]; then {
  echo "No such file: $DOCKER_CMD_FILE. Not running Docker tests. Exiting cleanly..."
  exit 0
}
fi

source onco-ci/scripts/common-utils.sh
load_modules -ttv2

# http://ghe-rss.roche.com/pages/Oncology-ctDNA/Docs/development/release_management/#build-and-deploy-debian-packages-with-maven
chmod -R g-s .

# Init vars
SCRIPT_BASH_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Get metadata for this repo
COMPONENT_NAME=`xmllint --xpath '/*[local-name()="project"]/*[local-name()="artifactId"]/text()' pom.xml`
COMPONENT_VERSION=`xmllint --xpath '/*[local-name()="project"]/*[local-name()="version"]/text()' pom.xml`

# Start the tests
echo "╔╦╗╔═╗╔═╗╦╔═╔═╗╦═╗  ╦╔╗╔╔═╗╔╦╗╔═╗╦  ╦  ╔═╗╔╦╗╦╔═╗╔╗╔"
echo " ║║║ ║║  ╠╩╗║╣ ╠╦╝  ║║║║╚═╗ ║ ╠═╣║  ║  ╠═╣ ║ ║║ ║║║║"
echo "═╩╝╚═╝╚═╝╩ ╩╚═╝╩╚═  ╩╝╚╝╚═╝ ╩ ╩ ╩╩═╝╩═╝╩ ╩ ╩ ╩╚═╝╝╚╝"
install_docker

echo "╔╦╗╔═╗╔═╗╦╔═╔═╗╦═╗  ╔╦╗╔═╗╔═╗╔╦╗"
echo " ║║║ ║║  ╠╩╗║╣ ╠╦╝   ║ ║╣ ╚═╗ ║ "
echo "═╩╝╚═╝╚═╝╩ ╩╚═╝╩╚═   ╩ ╚═╝╚═╝ ╩ "
if [[ "$(docker images -q rsu/ubuntu1804/$COMPONENT_NAME-$USER:$COMPONENT_VERSION 2> /dev/null)" != "" ]]
then {
  BASE_IMAGE="rsu/ubuntu1804"
} else {
  BASE_IMAGE="rsu/ubuntu"
}
fi
test_plc_docker "$BASE_IMAGE/$COMPONENT_NAME-$USER:$COMPONENT_VERSION" "$DOCKER_CMD_FILE"
if [ $? -ne 0 ]; then exit 1; fi

SUFFIX=`whoami`

echo "╔╦╗╔═╗╔═╗╦╔═╔═╗╦═╗  ╔═╗╦  ╔═╗╔═╗╔╗╔╦ ╦╔═╗"
echo " ║║║ ║║  ╠╩╗║╣ ╠╦╝  ║  ║  ║╣ ╠═╣║║║║ ║╠═╝"
echo "═╩╝╚═╝╚═╝╩ ╩╚═╝╩╚═  ╚═╝╩═╝╚═╝╩ ╩╝╚╝╚═╝╩  "
remove_docker "$BASE_IMAGE/$COMPONENT_NAME-$SUFFIX:$COMPONENT_VERSION"
remove_docker "$BASE_IMAGE/$COMPONENT_NAME-$SUFFIX:latest"

# Backup build logs and job config
backup_logs $JOB_NAME $BUILD_NUMBER $BUILD_ARCHIVE_DIR/$BUILD_TAG
