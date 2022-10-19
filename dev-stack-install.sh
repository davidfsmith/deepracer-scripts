#!/usr/bin/env bash

# Build the core packages
sudo systemctl stop deepracer-core

# Make a backup
if [[ -d /opt/aws/deepracer/lib.orig ]]
then
    echo "Backup exists"
    if [[ -d /opt/aws/deepracer/lib ]]
    then
        echo "Deleting current install"
        sudo rm -rf /opt/aws/deepracer/lib
    fi
else
    echo "Making backup"
    sudo mv /opt/aws/deepracer/lib /opt/aws/deepracer/lib.orig
fi

# Symlink (or copy?) to the build
echo "Copy files"
sudo cp -Rp $(pwd)/ws/install /opt/aws/deepracer/lib

# Symlink (or copy?) in the console
echo "Copying console code"
sudo cp -Rp /opt/aws/deepracer/lib.orig/device_console /opt/aws/deepracer/lib/

# Create logs directory
sudo mkdir -p /opt/aws/deepracer/logs

# Restart deepracer
sudo systemctl restart deepracer-core