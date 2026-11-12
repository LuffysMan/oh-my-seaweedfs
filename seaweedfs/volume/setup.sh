#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/seaweedfs"
SERVICE_PATH="/etc/systemd/system/seaweedfs-volume.service"
source "${CONFIG_DIR}"/oh-my.conf

function main() {
    # register volume server as a service
    cp -fH --remove-destination "${CURRENT_DIR}"/service "${SERVICE_PATH}"

    # configuration
    sed -i "s/LOG_DIR/${log_dir}/g" "${SERVICE_PATH}"
    sed -i "s/LOCAL_IP/${local}/g" "${SERVICE_PATH}"
    sed -i "s/PORT_VOLUME/${port_volume}/g" "${SERVICE_PATH}"
    sed -i "s/MASTERS/${local}:${port_master},${peers[0]}:${port_master},${peers[1]}:${port_master}/g" "${SERVICE_PATH}"
    sed -i "s/DATA_CENTER/${data_center}/g" "${SERVICE_PATH}"
    sed -i "s/RACK/${rack}/g" "${SERVICE_PATH}"

    systemctl enable seaweedfs-volume.service
    systemctl daemon-reload

    # start
    systemctl start seaweedfs-volume.service
}

main
