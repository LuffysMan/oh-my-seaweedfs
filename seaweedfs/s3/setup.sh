#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$(dirname "${CURRENT_DIR}")")"
CONFIG_DIR="/etc/seaweedfs"
S3_CONF="${CONFIG_DIR}"/s3.json
source "${CONFIG_DIR}"/oh-my.conf


function main() {
    # config
    cp "${PACKAGE_ROOT}"/config/s3.json "${CONFIG_DIR}"
    sed -i "" "${S3_CONF}"

    # start
    nohup weed s3 \
    -ip.bind=0.0.0.0 \
    -port=8333 \
    -filer="${local}":8888,"${peers[0]}":8888,"${peers[1]}":8888 \
    -config="${S3_CONF}" \
    -encryptVolumeData \
    &
}

main