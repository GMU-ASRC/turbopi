#!/bin/bash

# run this file with `source ./provision.sh`

# pass INSTALL_REPO as the first argument to install our managed git repo
# after the first restart

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

dos2unix -q ./config
source ./config

# exit on error
set -e

IF_INSTALL="${1:-__ASK__}"

if [ "$IF_INSTALL" == "INSTALL_REPO" ]; then
    ARG1=INSTALL_REPO
elif [ "$IF_INSTALL" == "__ASK__" ]; then
    read -p "Do you want to install our managed git repo? (y/n): " ARG1
    if [ "$ARG1" == "y" ]; then
        echo "Okay, we'll install our managed git repo after the restart."
        ARG1=INSTALL_REPO
    elif [ "$ARG1" == "n" ]; then
        echo "Okay, we won't install our managed git repo after the restart."
        ARG1=''
    else
        echo "Invalid input. Please enter 'y' or 'n'."
        exit 1
    fi
fi

echo "Copying setup scripts to $SETUPSCRIPTS"

dos2unix -q *.sh
mkdir -p $SETUPSCRIPTS
cp ./* $SETUPSCRIPTS
chmod +x $SETUPSCRIPTS/*.sh
set +e
chmod +x $SETUPSCRIPTS/*.secret
set -e
chmod +x $SETUPSCRIPTS/config
# rm $SETUPSCRIPTS/*.secret
cd $SETUPSCRIPTS

# modify resume_turbopi_setup.service with the correct path to setupscripts
SETUPSERVICE="$SETUPSCRIPTS/resume_turbopi_setup.service"
NEWCOMMAND="$SETUPSCRIPTS/resume_turbopi_setup.sh $ARG1"
REPLACESTRING="/ExecStart=/c\\ExecStart=$NEWCOMMAND"
sed -i "$REPLACESTRING" $SETUPSERVICE
sed -i "$/WorkingDirectory=/c\\WorkingDirectory=${SETUPSCRIPTS}" $SETUPSERVICE
sed -i "$/User=/c\\User=${U}" $SETUPSERVICE


echo DONE COPYING
sleep 1



# TODO
# sudo ifconfig eth0 192.168.1.100 netmask 255.255.255.0

echo -e "\n\nRunning locale.sh"
bash ./locale.sh
echo -e "\n\nRunning add_wifi.sh"
bash ./add_wifi.sh
echo -e "\n\nRunning set_name_ip.sh"
bash ./set_name_ip.sh
echo -e "\n\nRunning use_wpa.sh"
bash ./use_wpa.sh
echo -e "\n\nExpanding rootfs"
bash ./expand.sh
echo
echo -e "-------"
echo -e " DONE! "
echo -e "-------"
echo -e Scheduling provision2s.sh to be run after reboot.
sudo ln -sf "$SETUPSCRIPTS/resume_turbopi_setup.service" /etc/systemd/system/resume_turbopi_setup.service
sudo systemctl enable resume_turbopi_setup.service
# echo -e "@reboot $SETUPSCRIPTS/provision2s.sh $ARG1" | sudo crontab -u root -
# echo "The following commands have been added to the crontab:"
# sudo crontab -lu root
echo -e Rebooting now. See ya on the other side!
sleep 5
sudo reboot now
