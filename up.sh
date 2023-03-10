#!/bin/bash

# Init defaults
DOCKER_CONFIG_PREFIX=_config
DOCKER_CONFIG_NAME=once
DOCKER_DETACH=""
DOCKER_IMAGE=donges/once:latest
DOCKER_ONCE_SRC_HOME=../_var_dev
DOCKER_OUTER_CONFIG=../_myhome
DOCKER_HTTP_PORT=8080
DOCKER_HTTPS_PORT=8443
DOCKER_SSH_PORT=8022

# ask with default
function ask_with_default {
    read -p "$1 [$2]: " answer
    if [[ -z "$answer" ]]; then
        echo "$2"
    else
        echo "$answer"
    fi
}

# print available configs
function printAvailableConfigs {
    configs=`ls -d $DOCKER_CONFIG_PREFIX* 2>/dev/null | sed "s;$DOCKER_CONFIG_PREFIX.;;"`
    if [ ! -z "$configs" ]; then
        echo "Available configs: " $configs
    fi
}

# Write docker compose file
function writeDockerComposeFile {
    file=$1
    echo "services:" > $file
    echo "  once.sh:" >> $file
    echo "    container_name: ${DOCKER_CONFIG_NAME}-once.sh_container" >> $file
    echo "    image: ${DOCKER_IMAGE}" >> $file
    echo "    volumes:" >> $file
    echo "      - /var/run/docker.sock:/var/run/docker.sock" >> $file
    echo "      - /run/snapd.socket:/run/snapd.socket" >> $file
    if [[ "$DOCKER_ONCE_SRC_HOME" == "volume" ]]; then
        echo "      - once-development:/var/dev" >> $file
    else
        mkdir -p $DOCKER_ONCE_SRC_HOME
        echo "      - ${DOCKER_ONCE_SRC_HOME}:/var/dev" >> $file
    fi
    echo "      - ${DOCKER_OUTER_CONFIG}:/outer-config" >> $file
    echo "    ports:" >> $file
    echo "      - '${DOCKER_HTTP_PORT}:8080'" >> $file
    echo "      - '${DOCKER_HTTPS_PORT}:8443'" >> $file
    echo "      - '${DOCKER_SSH_PORT}:22'" >> $file
    if [[ "$DOCKER_ONCE_SRC_HOME" == "volume" ]]; then
        echo "volumes:" >> $file
        echo "  once-development:" >> $file
    fi
}

# Usage
usage() {
    echo "Usage: $0 [-d] [-h] [<config-name>]"
    echo "  -d: Set detach mode"
    echo "  -h: Show usage information"
}

### MAIN ###

# Parse arguments
while getopts ":dh" opt; do
    case ${opt} in
        d )
            DOCKER_DETACH="-d"
            ;;
        h )
            usage
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND -1))

# Command
echo
base=${0##*/}
DOCKER_COMPOSE_COMMAND=${base%.sh}
echo "Command: $DOCKER_COMPOSE_COMMAND"

# Choose config
echo
if [ -z "$1" ]; then
    printAvailableConfigs
    DOCKER_CONFIG_NAME=$(ask_with_default "Choose a config name :" "$DOCKER_CONFIG_NAME")
else
    DOCKER_CONFIG_NAME=$1
fi
echo "Use config: $DOCKER_CONFIG_NAME"

# Check if config is created
DOCKER_CONFIG_DIR=$DOCKER_CONFIG_PREFIX.$DOCKER_CONFIG_NAME
DOCKER_COMPOSE_FILE=$DOCKER_CONFIG_DIR/docker-compose.yml
if [ ! -d $DOCKER_CONFIG_DIR ] || [ ! -f $DOCKER_COMPOSE_FILE ]; then
    mkdir -p $DOCKER_CONFIG_DIR
    pushd $DOCKER_CONFIG_DIR > /dev/null

    # Configure Docker image
    echo
    DOCKER_IMAGE=$(ask_with_default "Docker image :" "$DOCKER_IMAGE")

	# Evaluate source path (on Windows only provide "volume")
	OS_TEST=`echo $OS | grep -i win`
	if [ -z "$OS_TEST" ]; then
		if [ ! -d "$DOCKER_ONCE_SRC_HOME" ] && [ -d "/var/dev" ]; then
			DOCKER_ONCE_SRC_HOME=/var/dev
		fi
		echo
		echo "Relative paths need to be relative to: `pwd`"
		echo "Type 'volume' if you want to use a docker volume"
		DOCKER_ONCE_SRC_HOME=$(ask_with_default "EAMD.ucp source path :" "$DOCKER_ONCE_SRC_HOME")
	else
		echo "On Windows you can only use a volume for the EAMD.ucp source code"
		DOCKER_ONCE_SRC_HOME="volume"
	fi

    # Evaluate home
    echo
    echo "$DOCKER_OUTER_CONFIG, $HOME ?"
    if [ ! -d "$DOCKER_OUTER_CONFIG" ] && [ -d "$HOME/.ssh" ]; then
        DOCKER_OUTER_CONFIG=$HOME
    fi
    DOCKER_OUTER_CONFIG=$(ask_with_default "Home of git and ssh config to import from :" "$DOCKER_OUTER_CONFIG")

    # Create .gitconfig
    if [ ! -f $DOCKER_OUTER_CONFIG/.gitconfig ]; then
        mkdir -p $DOCKER_OUTER_CONFIG
        NAME=$(ask_with_default "Your name for .gitconfig :" "")
        MAIL=$(ask_with_default "Your email for .gitconfig :" "")
        cat ../gitconfig.template | sed "s;##NAME##;$NAME;" | sed "s;##MAIL##;$MAIL;" > $DOCKER_OUTER_CONFIG/.gitconfig
    fi

    # Create ssh keys
    if [ ! -f $DOCKER_OUTER_CONFIG/.ssh/id_rsa ]; then
        mkdir -p $DOCKER_OUTER_CONFIG/.ssh
        ssh-keygen -f $DOCKER_OUTER_CONFIG/.ssh/id_rsa
    fi

    # Collect ports
    echo
    DOCKER_HTTP_PORT=$(ask_with_default "HTTP port :" "$DOCKER_HTTP_PORT")
    DOCKER_HTTPS_PORT=$(ask_with_default "HTTPS port :" "$DOCKER_HTTPS_PORT")
    DOCKER_SSH_PORT=$(ask_with_default "SSH port :" "$DOCKER_SSH_PORT")

    # Create docker-compose.yml
    writeDockerComposeFile "docker-compose.yml"

    popd > /dev/null
fi

pushd $DOCKER_CONFIG_DIR > /dev/null
docker-compose -p $DOCKER_CONFIG_NAME $DOCKER_COMPOSE_COMMAND $DOCKER_DETACH
popd > /dev/null
