#!/bin/bash

# sets the timezone and locale

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

TIMEZONE="America/New_York"
LANG=en_US.UTF-8
LANGUAGE=$(echo $LANG | cut -d'.' -f1)

# set timezone
echo "Setting timezone to $TIMEZONE"
sudo timedatectl set-timezone $TIMEZONE
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd

# set locale

# should edit /etc/default/locale

# WARNING: UNTESTED
echo "Setting locale to $LANG"
export LANG=$LANG
export LANGUAGE=$LANGUAGE
export LC_ALL=$LANGUAGE
sudo locale-gen $LANG
sudo localectl set-locale LANG=$LANG
sudo update-locale LC_ALL=$LC_ALL LANG=$LANG LANGUAGE=$LANGUAGE
sudo raspi-config nonint do_change_locale $LANG

