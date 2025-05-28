#!/bin/bash

# install goodies and our repo to the turbopi

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi

sudo apt update

sudo apt install ncdu bat aptitude vim python-is-python3 -y

# install pyenv and other useful tools
bash /home/pi/setupscripts/goodies.sh

# install our managed git repo, hiwonder_common, and caspyan
# as well as buttonman

if [ "$1" == "INSTALL_REPO" ]; then
    bash /home/pi/setupscripts/provision3.sh
fi

read -sN "Press any key to exit."
