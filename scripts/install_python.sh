#!/bin/bash

# install our managed git repo, hiwonder_common, and caspyan
# as well as buttonman

if [ "$(id -u)" -eq 0 ]; then
    echo 'This script should not be run by root' >&2
    exit 1
fi

set -e  # exit on error

source ./config

rm -f $SETUPSCRIPTS/setup_Py_done
touch $SETUPSCRIPTS/setup_Py_started

source ~/.bashrc

if ! command -v pyenv &> /dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

echo "installing python 3.13.4"
pyenv doctor
pyenv install 3.13.4 --force
pyenv global 3.13.4

touch $SETUPSCRIPTS/setup_Py_done
rm -f $SETUPSCRIPTS/setup_Py_started

echo -----------------------
echo Python 3.13.4 installed
echo -----------------------
sleep 5
