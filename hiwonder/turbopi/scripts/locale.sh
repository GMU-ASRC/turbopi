#!/bin/bash

# sets the timezone and locale

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

TIMEZONE="America/New_York"
NEWLANG=en_US.UTF-8
NEWLANGUAGE=$(echo $NEWLANG | cut -d'.' -f1)
NEWLCALL=$NEWLANG

# set timezone
echo "Setting timezone to $TIMEZONE"
sudo timedatectl set-timezone $TIMEZONE
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd

# set locale

# should edit /etc/default/locale

# WARNING: UNTESTED
echo "Setting locale to $LANG"
sudo locale-gen $NEWLANGUAGE $NEWLANG
# sudo dpkg-reconfigure locales
export LANG=$NEWLANG
export LANGUAGE=$NEWLANGUAGE
export LC_ALL=$NEWLCALL
echo LC_ALL = $LC_ALL
sudo localectl set-locale LANG=$NEWLANG
sudo update-locale LC_ALL=$NEWCALL LANG=$NEWLANG LANGUAGE=$NEWLANGUAGE
sudo raspi-config nonint do_change_locale $NEWLANG

