#!/bin/bash

TAG=
DOCKER_USER=
DOCKER_PASSWORD=

# TODO: use tag
gw8image="groundworkdevelopment/gw8:GROUNDWORK-2204"

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
  if ! which psql | grep "psql" >/dev/null 2>/dev/null; then
    echo "ERROR: 'psql' should be installed"
    exit 1
  fi
  if ! which influx | grep "influx" >/dev/null 2>/dev/null; then
    echo "ERROR: 'influx' should be installed"
    exit 1
  fi
}

__set_variables() {
  if [[ "$version" == "" ]]; then
    echo "ERROR: 'version' should be specified"
    exit 1
  fi
  TAG=$version
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
}

__docker_login() {
  docker login --username "$DOCKER_USER" --password "$DOCKER_PASSWORD"
}

__pull_gw8_image() {
  docker pull "$gw8image"
  # docker pull "$gw8image:${TAG}"
}

__extract_gw8_image() {
  mkdir gw8
  cd gw8 || exit
  GW8_INSTANCE_NAME=$(hostname -f)
  PARENT_INSTANCE_NAME=
  CHILD_INSTANCE_NAME=
  docker run \
    -e GW8_INSTANCE_NAME="$GW8_INSTANCE_NAME" \
    -e PARENT_INSTANCE_NAME="$PARENT_INSTANCE_NAME" \
    -e CHILD_INSTANCE_NAME="$CHILD_INSTANCE_NAME" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${HOME}"/.docker:/root/.docker \
    -v /tmp:/tmp/tmp \
    --name gw8 $gw8image /src/docker_cmd.sh
  # --name gw8 "$gw8image:$TAG" /src/docker_cmd.sh
  docker cp gw8:RELEASE .
  docker cp gw8:docker-compose.yml .
  docker cp gw8:.env .
  docker cp gw8:gw8.env .
  docker cp gw8:docker-compose.override.yml .
  docker rm gw8
  docker-compose pull
  docker-compose up -d
}

__check_environment
eval "$(__parse_config_yaml config.yml)"
__set_variables
__docker_login
__pull_gw8_image
__extract_gw8_image

### REMOVE VOLUMES
# docker volume rm dockergw8_archive-var dockergw8_elk-config dockergw8_elk-data dockergw8_grafana-dashboards dockergw8_grafana-etc dockergw8_grafana-provisioning dockergw8_grafana-var dockergw8_influxdb dockergw8_jaegertracing dockergw8_jasperserver dockergw8_kafka-config dockergw8_kafka-data dockergw8_monarch-backup dockergw8_monarch-data dockergw8_monarch-gdma-discovered dockergw8_monarch-htdocs dockergw8_nagios-etc dockergw8_nagios-libexec dockergw8_nagios-var dockergw8_nedi-php-sess dockergw8_nedi-rrd dockergw8_nedi-sysobj dockergw8_nedi-topo dockergw8_nfdump-var dockergw8_nginx-confd dockergw8_pgvol dockergw8_revproxy-certs dockergw8_revproxy-nginx dockergw8_rstools-cache dockergw8_rstools-images dockergw8_rstools-var dockergw8_tcg-var dockergw8_ulg dockergw8_ulg-var dockergw8_zk-data
