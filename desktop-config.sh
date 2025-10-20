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
sudo /install/scripts/pacman.sh
sudo /install/scripts/timesyncd.sh
sudo /install/scripts/sssd.sh
sudo /install/scripts/cron.sh
sudo /install/scripts/yay.sh
sudo /install/scripts/auto-cpufreq.sh
sudo /install/scripts/autofs.sh
sudo /install/scripts/snapper.sh