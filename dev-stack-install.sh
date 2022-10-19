#!/usr/bin/env bash

# Build the core packages
sudo systemctl stop deepracer-core

# Make a backup
sudo mv /opt/aws/deepracer/lib /opt/aws/deepracer/lib.orig

# Symlink (or copy?) to the build
# sudo ln -s /home/deepracer/deepracer_ws/aws-deepracer-launcher/install /opt/aws/deepracer/lib
sudo cp -Rp $(pwd)/install /opt/aws/deepracer/lib

# Symlink (or copy?) in the console
# sudo ln -s /opt/aws/deepracer/lib.orig/device_console  /opt/aws/deepracer/lib/device_console 
sudo cp -Rp /opt/aws/deepracer/lib.orig/device_console /opt/aws/deepracer/lib/

# Restart deepracer
sudo systemctl restart deepracer-core