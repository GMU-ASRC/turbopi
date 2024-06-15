#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run by root' >&2
    exit 1
fi

echo 'Updating pip'

sudo python -m pip install --upgrade pip
# echo
# echo 'Installing Dependencies'
# echo
echo 'Installing hiwonder_common...'
sudo pip install -e .

sudo python -c "import hiwonder_common"
if [ $? -eq 0 ]; then
    echo 'hiwonder_common successfully installed!'
else
    echo "Something went wrong, hiwonder_common doesn't seem to be installed..."
fi