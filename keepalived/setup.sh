#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/seaweedfs"
CONF_FILE="/etc/keepalived/keepalived.conf"
source "${CONFIG_DIR}"/oh-my.conf

function main() {
    # install
    snap install keepalived

    # configuring  /etc/keepalived/keepalived.conf
    cp -fH --remove-destination "${CURRENT_DIR}"/keepalived.conf "${CONF_FILE}"
    chown -h root:root "${CONF_FILE}"
    chmod 640 "${CONF_FILE}"

    # configuring
    sed -i "s/HOST/${host}/g" "${CONF_FILE}"
    sed -i "s/PEER_1/${peer[0]}/g" "${CONF_FILE}"
    sed -i "s/PEER_2/${peer[1]}/g" "${CONF_FILE}"
    sed -i "s/VIRTUAL_IP/${float_ip}/g" "${CONF_FILE}"
    sed -i "s/INTERFACE_NAME/${enp1s0}/g" "${CONF_FILE}"

    snap enable keepalived
    snap start keepalived
}