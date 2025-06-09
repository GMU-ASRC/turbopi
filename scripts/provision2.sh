#!/bin/bash

# install goodies and our repo to the turbopi

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

source ./config

if [ "$(whoami)" != "$U" ]; then
    echo "ERROR: This script should be run as user '$U' but you are $(whoami)."
    exit 1
fi

touch $SETUPSCRIPTS/setup2ran
export USER=$U
export HOME=$H
echo $-
source $H/.bashrc  # reload bashrc

CONNECTIVITY_CHECK=8.8.8.8

echo waiting for connection...

for i in {1..100}; do
    if ping -c 1 $CONNECTIVITY_CHECK; then
        break
    fi
    sleep 1
done
set -e
sleep 2

echo ensuring stable connectivity...
ping -c 4 $CONNECTIVITY_CHECK
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
# sleep 5

# check if interactive
if [[ $- == *i* ]]; then
    IS_INTERACTIVE=1
else
    IS_INTERACTIVE=0
fi

# install pyenv and other useful tools
set +e
echo "Running goodies.sh"
source $SETUPSCRIPTS/goodies.sh
set +e
source $H/.bashrc  # reload bashrc

echo provision2.sh complete

# install our managed git repo, hiwonder_common, and caspyan
# as well as buttonman

if [[ "$1" == "INSTALL_REPO" ]]; then
    cd $SETUPSCRIPTS
    echo running provision3.sh
    source $SETUPSCRIPTS/provision3.sh
else
    echo skipping provision3.sh
fi
sleep 5

if [ $IS_INTERACTIVE -eq 1 ]; then
    read -sp "Done with setup. Press any key to exit, or CTRL-C to exit." -N 1
fi
echo
echo
