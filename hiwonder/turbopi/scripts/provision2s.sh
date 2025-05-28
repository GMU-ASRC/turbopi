#!/bin/bash

SETUPSCRIPTS=/home/pi/setupscripts

crontab -u pi -l | grep -v '/home/pi/setupscripts/provision2s.sh' | crontab -u pi -

sleep 20

ping -c 4 192.168.0.1

if [ $? -ne 0 ]; then
    echo "Failed to ping gateway."
    exit 1
fi

lxterminal -e "./provision2.sh $1"
read -sN "Press any key to exit."
