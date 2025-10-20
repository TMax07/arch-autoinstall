#!/bin/bash

#####################################################
# Helper functions

function if_not_dir_mk_dir() {
    if [[ -d "$1" ]]
    then
        return
    else
        sudo mkdir "$1"
    fi
}

function if_file_exists_rm() {
    if [[ -f "$1" ]] 
    then
        sudo rm -f "$1"
    fi 
}

function link_config_to_dir() {
    sudo ln -s "$1" "$2"
}

#####################################################

echo "Setting up ntp..."

if_not_dir_mk_dir "/etc/systemd"
if_file_exists_rm "/etc/systemd/timesyncd.conf"
link_config_to_dir "/config/systemd/timesyncd.conf" "/etc/systemd/timesyncd.conf"

sudo timedatectl set-ntp true