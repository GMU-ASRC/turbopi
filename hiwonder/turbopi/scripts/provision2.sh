#!/bin/bash

# install goodies and our repo to the turbopi

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi


USER="$(whoami)"
HOME="/home/$USER"
touch $HOME/setupscripts/setup2ran
export USER=$USER
export HOME=$HOME
set -i
echo $-
source /home/pi/.bashrc  # reload bashrc


echo waiting for connection...

for i in {1..10}; do
    if ping -c 1 8.8.8.8; then
        break
    fi
done
set -e
sleep 1

echo ensuring connectivity...
ping -c 4 8.8.8.8
RET=0

if [ $? -ne 0 ]; then
    echo "Failed to ping dns."
    read -N 1 -sp "Press any key to exit."
    echo
    exit 1
fi
echo



echo restarting time server
# restart timesyncd to maybe sync time
sudo systemctl restart systemd-timesyncd
sleep 1

# install pyenv and other useful tools
set +e
bash -i /home/pi/setupscripts/goodies.sh
set +e
source /home/pi/.bashrc  # reload bashrc

# install our managed git repo, hiwonder_common, and caspyan
# as well as buttonman

echo provision2.sh complete

if [[ "$1" == "INSTALL_REPO" ]]; then
    echo running provision3.sh
    bash -i /home/pi/setupscripts/provision3.sh
else
    echo skipping provision3.sh
fi
sleep 5

read -sp "Quitting provision2.sh in 8 seconds. Press any key to continue, or CTRL-C to exit." -t 8 -N 1
echo
echo
