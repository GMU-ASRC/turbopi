#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

echo 'Removing symlink /etc/systemd/system/buttonman.service'
systemctl stop buttonman.service
systemctl disable buttonman.service
rm /etc/systemd/system/buttonman.service
echo 'Enabling hw_button_scan.service'
systemctl enable hw_button_scan.service
systemctl start hw_button_scan.service
echo 'Done'
