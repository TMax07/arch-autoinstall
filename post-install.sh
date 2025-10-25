#!/bin/bash

echo "Welcome to TMax07's arch install helper script :D"

echo "Enabeling NetworkManager..."
sudo systemctl enable --now NetworkManager.service > /dev/null # check if already running

echo "Testing for network connection..."
while true; do
    if ping -c 1 ping.archlinux.org
    then 
        echo "Connected to the internet, continueing..."
        break
    else 
        echo "No internet connection, please connect to the internet"
        echo "This could be due to a delay in network configuration"
        while true; do 
            echo "Do you want to run the test again? yn"
            read USER_IN
            if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
            then
                break
            elif [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
            then
                echo "Please connect to the internet and then either restart your system or start the cript again manually"
                echo "The script is located under /install/post-install.sh"
                exit 0
        done
    fi
done 

sudo chmod +x /install/scripts/*
sudo git clone https://github.com/TMax07/arch-configs.git /config

while true; do
    echo "Please choose a preset: "
    echo "1) Desktop   2) Laptop"
    read -p "" USER_IN
    if [[ "$USER_IN" == "1" ]]
    then
        sudo chmod +x /install/desktop-config.sh 
        /install/desktop-config.sh
        break
    fi
    if [[ "$USER_IN" == "2" ]]
    then
        sudo chmod +x /install/laptop-config.sh
        /install/laptop-config.sh
        break
    else
        echo "Please choose a valid preset..."
    fi
done

sudo chmod +x /install/package_install.sh
/install/package_install.sh

echo "Install finished!"
echo "Have fun :D"