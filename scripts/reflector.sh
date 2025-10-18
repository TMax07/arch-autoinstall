#!/bin/bash

#####################################################
# Helper functions

function if_not_dir_mk_dir(dir) {
    if [[ -d "$dir" ]]
    then
    else
        sudo mkdir "$dir"
    fi
}

function if_file_exists_rm(file) {
    if [[ -f "$file" ]] 
    then
        sudo rm -f "$file"
    fi 
}

function link_config_to_dir(src, dst) {
    sudo ln -s "$src" "$dst"
}

#####################################################

echo "Setting up reflector..."

if_not_dir_mk_dir("/etc/xdg")
if_not_dir_mk_dir("/etc/xdg/reflector")
if_file_exists_rm("/etc/xdg/reflector/reflector.conf")

link_config_to_dir("/config/reflector/reflector.conf", "/etc/xdg/reflector/reflector.conf")

sudo systemctl enable reflector.timer
sudo systemctl start --now reflector.timer 