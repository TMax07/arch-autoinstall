#!bin/bash

echo "Welcome to TMax07's arch install helper script :D"

chmod +x /install/scripts/*
git clone https://github.com/TMax07/arch-configs.git /config

while true; do
    echo "Please choose a preset: "
    echo "1) Desktop   2) Laptop"
    read -p "" USER_IN
    if [[ "$USER_IN" == "1" ]]
    then
        chmod +x /install/desktop-config.sh 
        /install/desktop-config.sh
        break
    fi
    if [[ "$USER_IN" == "2" ]]
    then
        chmod +x /install/laptop-config.sh
        /install/laptop-config.sh
        break
    else
        echo "Please choose a valid preset..."
    fi
done

echo "Install finished!"
echo "Have fun :D"