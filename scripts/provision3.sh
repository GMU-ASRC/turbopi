#!/bin/bash

# install our managed git repo, hiwonder_common, and caspyan
# as well as buttonman

if [ "$(id -u)" -eq 0 ]; then
    echo 'This script should not be run by root' >&2
    exit 1
fi

set -e  # exit on error

source ./config

touch $SETUPSCRIPTS/setup3ran

source ~/.bashrc

if ! command -v pyenv &> /dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

echo "installing python 3.12.9"
pyenv doctor
pyenv install 3.12.9 --force
pyenv global 3.12.9

# Put our git repo in /home/pi
cd $H

git init
git remote add origin https://github.com/GMU-ASRC/turbopi-root.git
git fetch
git reset origin/main --hard
git checkout -t origin/main
git config pull.ff only

git submodule update --init --recursive

sudo python -m pip install pip -U

sudo pip install -e hiwonder_common

cd $H/boot
chmod +x install_buttonman.sh
sudo ./install_buttonman.sh

cd $H/caspyan
git switch main
git pull
sudo pip install -e .
cd $H

echo ALL DONE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
sleep 5
