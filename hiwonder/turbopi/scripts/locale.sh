#!/bin/bash

# sets the timezone and locale

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

# set timezone
sudo timedatectl set-timezone "America/New_York"
sudo timedatect1 set-ntp true
sudo systemctl restart systemd-timesyncd

# set locale

# should edit /etc/default/locale

# WARNING: UNTESTED
export LANG=en_US.UTF-8
sudo locale-gen en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

