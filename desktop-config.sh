#!/bin/bash

echo "Configuring a desktop install..."

echo "Enabeling NetworkManager..."
sudo systemctl enable --now NetworkManager.service

if ping -c 1 ping.archlinux.org
then 
    echo "Connected to the internet, continueing..."
else 
    echo "No internet connection, please connect to the internet and restart the system"
    exit
fi

sudo /install/scripts/reflector.sh
