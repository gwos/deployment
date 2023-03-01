#!/bin/bash

TAG=
DOCKER_USER=
DOCKER_PASSWORD=
GW8_INSTANCE_NAME=
GW8_IMAGE=
GW8_DIR="gw8"
ADDS=

__parse_config_yaml() {
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs
  fs=$(echo @ | tr @ '\034')
  sed -ne "s|^\($s\):|\1|" \
    -e "s|^\($s\)\($w\)$s:${s}[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'"$prefix"'",vn, $2, $3);
      }
   }'
}

__check_environment() {
  if ! which docker | grep "docker" >/dev/null 2>/dev/null; then
    echo "ERROR: 'docker' should be installed"
    exit 1
  fi
  if ! which docker-compose | grep "docker-compose" >/dev/null 2>/dev/null; then
    echo "ERROR: 'docker-compose' should be installed"
    exit 1
  fi

  DOCKER_VERSION_LIM=20.10.13
  DOCKER_COMPOSE_VERSION_LIM=1.17.0
  MSG="ERROR: docker ${DOCKER_VERSION_LIM}+ and docker-compose ${DOCKER_COMPOSE_VERSION_LIM}+ are required"
  if [ ! "$(command -v docker)" ] || [ ! "$(command -v docker-compose)" ]; then
    echo "${MSG}"
    exit 1
  fi
  DOCKER_COMPOSE_VERSION=$(docker-compose version --short)
  DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
  if [ "$(__version "$DOCKER_COMPOSE_VERSION")" -lt "$(__version "$DOCKER_COMPOSE_VERSION_LIM")" ] ||
    [ "$(__version "$DOCKER_VERSION")" -lt "$(__version "$DOCKER_VERSION_LIM")" ]; then
    echo "${MSG}"
    exit 1
  fi
}

__version() {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

__load_alpine() {
  ## quick tests for failing with separate alpine image before long full load
  if [ -z "$SKIP_ALPINE" ]; then
    echo Try to run alpine container
    if ! docker run --rm alpine:latest echo 'Test alpine OK'; then
      printf '\nTest alpine FAILED\n'
      __exit_1
    fi

    DF=$(docker run --rm alpine:"${ALPINE_VERSION}" sh -c "df -B 1073741824 | awk '/ \/\$/ {printf \"%0.0f\n\",\$4;}'")
    RAM=$(docker run --rm alpine:"${ALPINE_VERSION}" sh -c "free | awk '/Mem:/ {printf \"%0.0f\n\",\$2/1000000;}'")
    NPROC=$(docker run --rm alpine:"${ALPINE_VERSION}" nproc)
    MSG_DF="${DF}GB of disk space available"
    MSG_RAM="${RAM}GB of RAM installed"
    MSG_NPROC="${NPROC} cores CPU available"
    if [ "$NPROC" -eq 1 ]; then
      MSG_NPROC="Single-core CPU available"
    fi

    if [ "$DF" -le 24 ]; then
      MSG=$(
        cat <<EOM
ERROR: This system does not meet the minimum requirements
for GroundWork 8. GroundWork requires a minimum of 25GB
of disk space to properly install.
  * 25GB of disk space required - ${MSG_DF}
EOM
      )
      echo "${MSG}"
      exit 1
    fi

    if [ "$NPROC" -le 3 ] || [ "$RAM" -le 31 ] || [ "$DF" -le 999 ]; then
      MSG=$(
        cat <<EOM
ERROR: This system does not meet the recommended minimum
requirements for GroundWork 8. GroundWork recommends the
following minimum environment specification for correct
operation in production:
  * 4 cores CPU - ${MSG_NPROC}
  * 32GB of RAM - ${MSG_RAM}
  * 1TB of disk space - ${MSG_DF}
EOM
      )
      echo "${MSG}"
      exit 1
    fi
  fi
}

__set_variables() {
  if [[ "$docker_user" == "" ]]; then
    echo "ERROR: 'docker_user' should be specified"
    exit 1
  fi
  DOCKER_USER=$docker_user

  if [[ "$docker_password" == "" ]]; then
    echo "ERROR: 'docker_password' should be specified"
    exit 1
  fi
  DOCKER_PASSWORD=$docker_password

  if [[ "$gw8_tag" == "" ]]; then
    echo "ERROR: 'gw8_tag' should be specified"
    exit 1
  fi
  TAG=$gw8_tag

  if [[ "$gw8_instance_name" == "" ]]; then
    echo "ERROR: 'gw8_instance_name' should be specified"
    exit 1
  fi
  GW8_INSTANCE_NAME=$gw8_instance_name

  if [[ "$gw8_image" == "" ]]; then
    echo "ERROR: 'gw8_image' should be specified"
    exit 1
  fi
  GW8_IMAGE=$gw8_image

  GW8_TZ=$gw8_timezone
  GW8_DIR=$gw8_dir
  PARENT_INSTANCE_NAME=$gw8_parent_instance_name
  CHILD_INSTANCE_NAME=$gw8_child_instance_name
}

__docker_login() {
  docker login --username "$DOCKER_USER" --password "$DOCKER_PASSWORD"
}

__pull_gw8_image() {
  docker pull "$GW8_IMAGE:${TAG}"
}

__extract_gw8_image() {
  for fname in ./config/*; do
    if [ -s "$fname" ]; then
      fname=$(basename $fname)
      ADDS="${ADDS} -v $PWD/config/$fname:/src/config/$fname "
    fi
  done

  mkdir "$GW8_DIR"

  if ! cd "$GW_DIR"; then
    echo "gw8 directory doesn't exist"
    exit 1
  fi

  if ! docker run \
    -e GW8_INSTANCE_NAME="$GW8_INSTANCE_NAME" \
    -e PARENT_INSTANCE_NAME="$PARENT_INSTANCE_NAME" \
    -e CHILD_INSTANCE_NAME="$CHILD_INSTANCE_NAME" \
    -e GW8_TZ="$GW8_TZ" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${HOME}"/.docker:/root/.docker \
    -v /tmp:/tmp/tmp \
    $ADDS \
    --name gw8 "${GW8_IMAGE}:${TAG}" /src/docker_cmd.sh; then
    echo "GroundWork 8 Installation FAILED"
    exit 1
  fi

  docker cp gw8:RELEASE .
  docker cp gw8:.env .
  docker cp gw8:docker-compose.yml .

  if [ ! -f gw8.env ]; then
    docker cp gw8:gw8.env .
  fi
  if [ ! -f docker-compose.override.yml ]; then
    docker cp gw8:docker-compose.override.yml .
  fi
  docker rm gw8

  if [ -f "gw8.env" ]; then
    cat gw8.env | sed -e '/^\s*TZ\s*=/s/TZ/GW8_TZ/' >gw8.env.updated
    mv -f gw8.env.updated gw8.env
    rm -f gw8.env.updated
  fi

  docker-compose pull
  docker-compose up -d
}

__check_environment
eval "$(__parse_config_yaml config.yml)"
__set_variables
__docker_login
__load_alpine
__pull_gw8_image
__extract_gw8_image

### REMOVE VOLUMES
# docker volume rm dockergw8_archive-var dockergw8_elk-config dockergw8_elk-data dockergw8_grafana-dashboards dockergw8_grafana-etc dockergw8_grafana-provisioning dockergw8_grafana-var dockergw8_influxdb dockergw8_jaegertracing dockergw8_jasperserver dockergw8_kafka-config dockergw8_kafka-data dockergw8_monarch-backup dockergw8_monarch-data dockergw8_monarch-gdma-discovered dockergw8_monarch-htdocs dockergw8_nagios-etc dockergw8_nagios-libexec dockergw8_nagios-var dockergw8_nedi-php-sess dockergw8_nedi-rrd dockergw8_nedi-sysobj dockergw8_nedi-topo dockergw8_nfdump-var dockergw8_nginx-confd dockergw8_pgvol dockergw8_revproxy-certs dockergw8_revproxy-nginx dockergw8_rstools-cache dockergw8_rstools-images dockergw8_rstools-var dockergw8_tcg-var dockergw8_ulg dockergw8_ulg-var dockergw8_zk-data
