#!/bin/bash

echo "Welcome to TMax07's arch install helper script :D"

sudo chmod +x /install/scripts/*
sudo git clone https://github.com/TMax07/arch-configs.git /config

while true; do
    echo "Please choose a preset: "
    echo "1) Desktop   2) Laptop"
    read -p "" USER_IN
    if [[ "$USER_IN" == "1" ]]
    then
        sudo chmod +x /install/desktop-config.sh 
        sudo /install/desktop-config.sh
        break
    fi
    if [[ "$USER_IN" == "2" ]]
    then
        sudo chmod +x /install/laptop-config.sh
        sudo /install/laptop-config.sh
        break
    else
        echo "Please choose a valid preset..."
    fi
done

sudo chmod +x /install/package_install.sh
/install/package_install.sh

echo "Install finished!"
echo "Have fun :D"