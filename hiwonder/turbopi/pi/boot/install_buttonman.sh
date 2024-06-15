#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

echo 'Updating pip'

python -m pip install --upgrade pip
echo
echo 'Installing Dependencies'
echo
pip install psutil python-statemachine

ln -sf /home/pi/boot/buttonman.service /etc/systemd/system/buttonman.service
echo
echo 'buttonman service was linked to /etc/systemd/system/buttonman.service'
echo
echo 'Replacing hw_button_scan.service with buttonman.service'
echo
systemctl disable hw_button_scan.service
systemctl stop hw_button_scan.service
systemctl enable buttonman.service
systemctl start buttonman.service
echo
echo Done!
