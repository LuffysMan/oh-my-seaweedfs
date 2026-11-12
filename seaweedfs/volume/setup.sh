#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/seaweedfs"
source "${CONFIG_DIR}"/oh-my.conf

function main() {
    nohup weed -logdir="${log_dir}"  volume \
        -ip="${host}" \
        -ip.bind=0.0.0.0 \
        -port=8080 \
        -dir="${data_dir}"/seaweedfs/volume \
        -max=0 \
        -master="${host}":9333,"${peers[0]}":9333,"${peers[1]}":9333 \
        -dataCenter="${data_center}" \
        -rack="${rack}" \
        -minFreeSpace=15 \
        &
}

main
