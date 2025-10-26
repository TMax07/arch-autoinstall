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

echo "Setting up autofs..."

sudo pacman -S --noconfirm samba
yay -S --noconfirm autofs

if_not_dir_mk_dir "/etc/autofs"
if_file_exists_rm "/etc/autofs/autofs.conf"
link_config_to_dir "/config/autofs/autofs.conf" "/etc/autofs/autofs.conf"
if_file_exists_rm "/etc/autofs/auto.master"
link_config_to_dir "/config/autofs/auto.master" "/etc/autofs/auto.master"
if_file_exists_rm "/etc/autofs/auto.nas"
link_config_to_dir "/config/autofs/auto.nas" "/etc/autofs/auto.nas"

while true; do
    echo "NAS username: "
    read -p "" USER_IN
    USER="$USER_IN"
    echo "Is the user '$USER' correct? Yn"
    read -p "" USER_IN
    if [[ "$USER_IN" != "n" && "$USER_IN" != "N" ]]
    then
        break
    fi
done
while true; do
    echo "NAS password: "
    read -s -p "" USER_IN
    PASSWORD="$USER_IN"
    echo "Enter password again: "
    read -s -p "" USER_IN
    if [[ "$USER_IN" == "$PASSWORD" ]]
    then
        break
    fi
done

sudo sed -i "s/USERNAME/$USER/" /config/autofs/auto.nas
sudo sed -i "s/PASSWORD/$PASSWORD/" /config/autofs/auto.nas

while true; do
    echo "Choose a mount point for autofs"
    read -p "" USER_IN
    MOUNT="$USER_IN"
    if [[ -d "$MOUNT" ]]
    then
        break
    else
        echo "Directory does not exist"
    fi
done

sudo systemctl enable --now autofs