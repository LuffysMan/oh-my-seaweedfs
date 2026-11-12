#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$(dirname "${CURRENT_DIR}")")"
CONFIG_DIR="/etc/seaweedfs"
FILER_CONF="${CONFIG_DIR}"/filer.toml
OH_MY_CONF="${CONFIG_DIR}"/oh-my.conf
SERVICE_PATH="/etc/systemd/system/seaweedfs-filer.service"

LOG_FILE=/var/log/seaweedfs/filer.log

source "${OH_MY_CONF}"


function main() {
    read -rp "DB name: " db_name
    read -rp "username: " username
    read -rsp "password: " db_pass    
    # copy
    cp -afH "${PACKAGE_ROOT}"/config/filer.toml "${FILER_CONF}"
    chmod 644 "${FILER_CONF}"

    # config filer.toml
    sed -i "/hostname =/c hostname = \"${backend_ip}\"" "${FILER_CONF}"
    sed -i "/username =/c username = \"${username}\"" "${FILER_CONF}"
    sed -i "/password =/c password = \"${db_pass}\"" "${FILER_CONF}"
    sed -i "/database =/c database = \"${db_name}\"" "${FILER_CONF}"

    # register filer server as a service
    cp -fH --remove-destination "${CURRENT_DIR}"/service "${SERVICE_PATH}"

    # configuration
    sed -i "s/LOG_DIR/${log_dir}/g" "${SERVICE_PATH}"
    sed -i "s/LOCAL_IP/${local}/g" "${SERVICE_PATH}"
    sed -i "s/PORT_FILER/${port_filer}/g" "${SERVICE_PATH}"
    sed -i "s/MASTERS/${local}:${port_master},${peers[0]}:${port_master},${peers[1]}:${port_master}/g" "${SERVICE_PATH}"
    sed -i "s/DEFAULT_REPLICATION/${default_replication}/g" "${SERVICE_PATH}"
    sed -i "s/DATA_CENTER/${data_center}/g" "${SERVICE_PATH}"
    sed -i "s/RACK/${rack}/g" "${SERVICE_PATH}"

    systemctl enable seaweedfs-filer.service
    systemctl daemon-reload

    # start
    systemctl start seaweedfs-filer.service
}

main