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

echo "Setting up flatpak..."

sudo pacman -S flatpak

flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
