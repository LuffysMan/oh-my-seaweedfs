#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$(dirname "${CURRENT_DIR}")")"
CONFIG_DIR="/etc/seaweedfs"
FILER_CONF="${CONFIG_DIR}"/filer.toml
OH_MY_CONF="${CONFIG_DIR}"/oh-my.conf

LOG_FILE=/var/log/seaweedfs/filer.log

source "${OH_MY_CONF}"


function main() {
    read -rp "DB name: " db_name
    read -rp "username: " username
    read -rsp "password: " db_pass    
    # copy
    cp -afH "${PACKAGE_ROOT}"/config/filer.toml "${FILER_CONF}"
    chmod 644 "${FILER_CONF}"

    # config
    sed -i "/hostname =/c hostname = \"${backend_ip}\"" "${FILER_CONF}"
    sed -i "/username =/c username = \"${username}\"" "${FILER_CONF}"
    sed -i "/password =/c password = \"${db_pass}\"" "${FILER_CONF}"
    sed -i "/database =/c database = \"${db_name}\"" "${FILER_CONF}"

    # start filer
    nohup weed -logdir="${log_dir}" filer \
    -ip="${host}" \
    -ip.bind=0.0.0.0 \
    -port=8888 \
    -master="${host}":9333,"${peers[0]}":9333,"${peers[1]}":9333 \
    -defaultReplicaPlacement=001 \
    -dataCenter="${data_center}" \
    -rack="${rack}" \
    -encryptVolumeData \
    &
}

main