#!/usr/bin/env bash

###############################################
# setup pg+pgboucer for filer on vm4
###############################################

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/opt/seaweedfs-meta"


function main() {
    read -rsp "DB name: " db_name
    read -rsp "username: " username
    read -rsp "password: " db_pass
    # install
    mkdir -p "${WORK_DIR}"
    cp -fH --remove-destination "${CURRENT_DIR}"/docker-compose.yml "${WORK_DIR}"/
    cp -fH --remove-destination "${CURRENT_DIR}"/.env "${WORK_DIR}"/.env

    # config
    sed -i "/POSTGRES_DB=/c POSTGRES_DB=${db_name}" "${WORK_DIR}"/.env
    sed -i "/POSTGRES_USER=/c POSTGRES_DB=${username}" "${WORK_DIR}"/.env
    sed -i "/POSTGRES_PASSWORD=/c POSTGRES_PASSWORD=${db_pass}" "${WORK_DIR}"/.env

    # start
    cd "${WORK_DIR}"
    docker compose up -d
}

main
