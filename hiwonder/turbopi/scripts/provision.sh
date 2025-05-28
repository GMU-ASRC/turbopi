#!/bin/bash

# run this file with `source ./provision.sh`

# pass INSTALL_REPO as the first argument to install our managed git repo
# after the first restart

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

SETUPSCRIPTS=/home/pi/setupscripts
# THIS ALSO NEEDS TO BE CHANGED IN provision2s.sh

# exit on error
set -e

IF_INSTALL = "${1:-__ASK__}"

if [ "$IF_INSTALL" == "INSTALL_REPO" ]; then
    ARG1 = INSTALL_REPO
elif [ "$IF_INSTALL" == "__ASK__" ]; then
    read -p "Do you want to install our managed git repo? (y/n): " ARG1
    if [ "$ARG1" == "y" ]; then
        echo "Okay, we'll install our managed git repo after the restart."
        ARG1 = INSTALL_REPO
    elif [ "$ARG1" == "n" ]; then
        echo "Okay, we won't install our managed git repo after the restart."
        ARG1 = ''
    else
        echo "Invalid input. Please enter 'y' or 'n'."
        exit 1
    fi
fi


echo "Copying setup scripts to $SETUPSCRIPTS"

cp ./* $SETUPSCRIPTS
chmod +x $SETUPSCRIPTS/*.sh
# rm $SETUPSCRIPTS/provision.sh
cd $SETUPSCRIPTS

# set hostname
# TODO: make this a prompt

# set IP
# TODO
# sudo ifconfig eth0 192.168.1.100 netmask 255.255.255.0

echo "\n\nRunning locale.sh"
. ./locale.sh
echo "\n\nRunning add_wifi.sh"
. ./add_wifi.sh
echo "\n\nRunning set_name_ip.sh"
. ./set_name_ip.sh
echo "\n\nRunning use_wpa.sh"
. ./use_wpa.sh
echo "\n\nExpanding rootfs"
. ./expand.sh
echo "-------"
echo " DONE! "
echo "-------"
echo Scheduling provision2s.sh to be run after reboot.
echo "@reboot $SETUPSCRIPTS/provision2s.sh $1" | crontab -
echo Rebooting now. See ya on the other side!
sudo reboot 3
