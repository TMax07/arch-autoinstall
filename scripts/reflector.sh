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

echo "Setting up reflector..."

if_not_dir_mk_dir "/etc/xdg"
if_not_dir_mk_dir "/etc/xdg/reflector"
if_file_exists_rm "/etc/xdg/reflector/reflector.conf"

link_config_to_dir "/config/reflector/reflector.conf" "/etc/xdg/reflector/reflector.conf"

sudo pacman -S --noconfirm reflector

sudo systemctl enable reflector.timer
sudo systemctl start --now reflector.timer 

#echo "Finding best pacman mirrors..."
#sudo systemctl start reflector.service