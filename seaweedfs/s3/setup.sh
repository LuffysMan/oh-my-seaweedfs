#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$(dirname "${CURRENT_DIR}")")"
CONFIG_DIR="/etc/seaweedfs"
S3_CONF="${CONFIG_DIR}"/s3.json
SECURITY_TOML="${CONFIG_DIR}"/security.toml
SERVICE_PATH="/etc/systemd/system/seaweedfs-s3.service"

source "${CONFIG_DIR}"/oh-my.conf


function main() {
    # read access key and secret key
    read -rp "access key for admin: " access_key_adm
    read -rsp "secret key for admin: " secret_key_adm && echo
    read -rp "access key for readonly_user: " access_key_ro
    read -rsp "secret key for readonly_user: " secret_key_ro && echo
    read -rp "access key for readwrite_user: " access_key_rw
    read -rsp "secret key for readwrite_user: " secret_key_rw && echo

    # s3 configuration
    ## s3.json
    cp -fH --remove-destination "${PACKAGE_ROOT}"/config/s3.json "${CONFIG_DIR}"
    # config admin
    sed -i "s/REPLACE_WITH_ADMIN_ACCESS_KEY/${access_key_adm}/g" "${S3_CONF}"
    sed -i "s/REPLACE_WITH_ADMIN_SECRET_KEY/${secret_key_adm}/g" "${S3_CONF}"
    # config readonly user
    sed -i "s/REPLACE_WITH_RO_ACCESS_KEY/${access_key_ro}/g" "${S3_CONF}"
    sed -i "s/REPLACE_WITH_RO_SECRET_KEY/${secret_key_ro}/g" "${S3_CONF}"
    # config readwrite user
    sed -i "s/REPLACE_WITH_RW_ACCESS_KEY/${access_key_rw}/g" "${S3_CONF}"
    sed -i "s/REPLACE_WITH_RW_SECRET_KEY/${secret_key_rw}/g" "${S3_CONF}"

    ## security.toml
    cp -fH --remove-destination "${PACKAGE_ROOT}"/config/security.toml "${CONFIG_DIR}"
    key_encryption_key=$(opessl rand -hex 32)
    sed -i "s/REPLACE_WITH_64_HEX_CHARACTERS/${key_encryption_key}/g" "${SECURITY_TOML}"

    # register s3 server as a service
    cp -fH --remove-destination "${CURRENT_DIR}"/service "${SERVICE_PATH}"
    ## configuration
    sed -i "s/LOG_DIR/${log_dir}/g" "${SERVICE_PATH}"
    sed -i "s/PORT_S3/${port_s3}/g" "${SERVICE_PATH}"
    sed -i "s/FILERS/${local}:${port_filer},${peers[0]}:${port_filer},${peers[1]}:${port_filer}/g" "${SERVICE_PATH}"

    systemctl enable seaweedfs-s3.service
    systemctl daemon-reload

    # start
    systemctl start seaweedfs-s3.service
}

main