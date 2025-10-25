#!/bin/bash

echo "Configuring a desktop install..."

/install/scripts/reflector.sh
/install/scripts/pacman.sh
/install/scripts/timesyncd.sh
/install/scripts/sssd.sh
/install/scripts/yay.sh
/install/scripts/auto-cpufreq.sh
/install/scripts/autofs.sh
/install/scripts/snapper.sh