#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/seaweedfs"
source "${CONFIG_DIR}"/oh-my.conf

function main() {
    nohup weed -logdir="${log_dir}"  master \
    -ip="${host}" \
    -ip.bind=0.0.0.0 \
    -port=9333 \
    -mdir="${data_dir}"/seaweedfs/master \
    -peers="${peers[0]}:9333,${peers[1]}:9333" \
    -raftHashicorp \
    -defaultReplication="${default_replication}" \
    -volumeSizeLimitMB=1000 \
    &
}
