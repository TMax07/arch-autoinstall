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

echo "Setting up SSSD..."

sudo pacman -S sssd

if_not_dir_mk_dir "/etc/sssd"
if_file_exists_rm "/etc/sssd/sssd.conf"
link_config_to_dir "/config/sssd/sssd.conf" "/etc/sssd/sssd.conf"
if_not_dir_mk_dir "/etc/pam.d"
if_file_exists_rm "/etc/pam.d/sssd"
link_config_to_dir "/config/sssd/pam.conf" "/etc/pam.d/sssd"
