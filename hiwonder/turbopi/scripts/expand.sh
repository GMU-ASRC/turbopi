#!/bin/bash

echo "Running raspi-config nonint do_expand_rootfs"
echo "This may take a moment..."
sleep 1
sudo raspi-config nonint do_expand_rootfs
echo "Done."
