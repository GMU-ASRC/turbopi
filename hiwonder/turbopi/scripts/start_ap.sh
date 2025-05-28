#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

sudo rm /etc/Hiwonder/* -rf > /dev/null 2>&1
sudo systemctl restart hw_wifi.service > /dev/null 2>&1
