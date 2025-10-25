#!/bin/bash

echo "Configuring a desktop install..."

if ping -c 1 ping.archlinux.org
then 
    echo "Connected to the internet, continueing..."
else 
    echo "No internet connection, please connect to the internet and restart the system"
    exit 1
fi

/install/scripts/reflector.sh
/install/scripts/pacman.sh
/install/scripts/timesyncd.sh
/install/scripts/sssd.sh
/install/scripts/yay.sh
/install/scripts/auto-cpufreq.sh
/install/scripts/autofs.sh
/install/scripts/snapper.sh