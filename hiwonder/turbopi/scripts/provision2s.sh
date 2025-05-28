#!/bin/bash

SETUPSCRIPTS=/home/pi/setupscripts

crontab -u pi -l | grep -v '/home/pi/setupscripts/provision2s.sh' | crontab -u pi -

sleep 10

# restart timesyncd to maybe sync time
sudo systemctl restart systemd-timesyncd

sleep 10

ping -c 4 192.168.0.1

RET = 0

if [ $? -ne 0 ]; then
    echo "Failed to ping gateway."
    RET = 1
else
    lxterminal -e "./provision2.sh $1"
fi
read -sN "Press any key to exit."
exit $RET
