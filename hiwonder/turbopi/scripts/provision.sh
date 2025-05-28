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


cp ./* $SETUPSCRIPTS
chmod +x $SETUPSCRIPTS/*.sh
rm $SETUPSCRIPTS/provision.sh
cd $SETUPSCRIPTS

# set hostname
# TODO: make this a prompt

# set IP
# TODO
# sudo ifconfig eth0 192.168.1.100 netmask 255.255.255.0


. ./locale.sh
. ./add_wifi.sh
. ./set_name_ip.sh
. ./use_wpa.sh
. ./locale.sh

echo "@reboot $SETUPSCRIPTS/provision2s.sh $1" | crontab -
sudo reboot now
