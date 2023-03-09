#!/bin/bash

DOCKER_CONFIG_PREFIX=_config
DOCKER_CONFIG_NAME=once

# ask with default
function ask_with_default {
    read -p "$1 [$2]: " answer
    if [[ -z "$answer" ]]; then
        echo "$2"
    else
        echo "$answer"
    fi
}

### MAIN ###

echo "Running containers"
docker ps --format "{{.Names}}" | grep once.sh

echo
configs=`ls -d $DOCKER_CONFIG_PREFIX* 2>/dev/null | sed "s;$DOCKER_CONFIG_PREFIX.;;"`
if [ ! -z "$configs" ]; then
    echo "Available configs: " $configs
fi
DOCKER_CONFIG_NAME=$(ask_with_default "Choose a config name :" "$DOCKER_CONFIG_NAME")

DOCKER_CONFIG_DIR=$DOCKER_CONFIG_PREFIX.$DOCKER_CONFIG_NAME

pushd $DOCKER_CONFIG_DIR > /dev/null
docker-compose -p $DOCKER_CONFIG_NAME down
popd > /dev/null
