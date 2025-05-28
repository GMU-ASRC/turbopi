#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

echo Starting hw_wifi service. This will disable the built-in wifi AP.
echo This will not persist after reboot.
sudo rm /etc/Hiwonder/* -rf > /dev/null 2>&1
sudo systemctl restart hw_wifi.service > /dev/null 2>&1
