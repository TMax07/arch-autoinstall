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

echo "Preventing btrfs slowdowns..."
if_file_exists_rm "/etc/updatedb.conf"
link_config_to_dir "/config/locate/updatedb.conf" "/etc/updatedb.conf"

echo "Setting up snapper..."

sudo pacman -S --noconfirm snapper btrfs-assistant

sudo umount /.snapshots
sudo rm -r /.snapshots

sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots

sudo mkdir /.snapshots
sudo mount -a
sudo chmod 750 /.snapshots

if_not_dir_mk_dir "/etc/snapper"
if_not_dir_mk_dir "/etc/snapper/configs"
if_file_exists_rm "/etc/snapper/configs/config"
link_config_to_dir "/config/snapper/config" "/etc/snapper/configs/config"

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

echo "Setting up pacman hooks..."
sudo pacman -S --noconfirm snap-pac
