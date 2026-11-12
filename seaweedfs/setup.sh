#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/seaweedfs"
source "${CONFIG_DIR}"/oh-my.conf

function main() {
    # create dir
    mkdir -p ${data_dir}/seaweedfs/master
    mkdir -p ${data_dir}/seaweedfs/volume
    mkdir -p /etc/seaweedfs

    # set permissions
    chown -R 1000:1000 ${data_dir}/seaweedfs
    chmod 755 ${data_dir}/seaweedfs
    chown -R 1000:1000 /etc/seaweedfs
    chmod 755 /etc/seaweedfs
}
