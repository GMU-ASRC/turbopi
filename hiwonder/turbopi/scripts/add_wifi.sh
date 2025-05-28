#!/bin/bash

# set and enable connection to wifi via wpa_supplicant

if [ "$(id -u)" -eq 0 ]; then
        echo 'This script should not be run by root' >&2
        exit 1
fi


WPA_SECRETS = ./wpa.secret
WPA_SUPPLICANT = /etc/wpa_supplicant/wpa_supplicant.conf

if [ -f "$WPA_SECRETS" ]; then
    source $WPA_SECRETS
fi

if [ "$NEW_WPA_SSID" == "__ASK__" ]; then
    read -p "Enter new WPA SSID: " NEW_WPA_SSID
fi
if [ "$NEW_WPA_PASSPHRASE" == "__ASK__" ]; then
    read -sp "Enter new WPA passphrase: " NEW_WPA_PASSPHRASE
fi

if [ -z "$NEW_WPA_SSID" ]; then
	echo "Error: \$NEW_WPA_SSID empty or not set."
	exit 1
fi
if [ -z "$NEW_WPA_PASSPHRASE" ]; then
	echo "Error: \$NEW_WPA_PASSPHRASE empty or not set."
	exit 1
fi

# make sure wpa_supplicant.conf exists
touch $WPA_SUPPLICANT

# make sure wpa_supplicant does not contain the new ssid
if [ -z "$(grep $NEW_WPA_SSID $WPA_SUPPLICANT)" ]; then
    echo "ssid=$NEW_WPA_SSID already exists in $WPA_SUPPLICANT."
    echo "Please manually remove it and try again."
    echo "i.e. sudo vim $WPA_SUPPLICANT"
    exit 1
fi

echo -e "\n" | sudo tee -a $WPA_SUPPLICANT

wpa_passphrase $NEW_WPA_SSID $NEW_WPA_PASSPHRASE | sudo tee -a $WPA_SUPPLICANT
