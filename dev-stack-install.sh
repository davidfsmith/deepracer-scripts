#!/usr/bin/env bash

# Build the core packages
sudo systemctl stop deepracer-core

# Make a backup
if [[ -d /opt/aws/deepracer/lib.custom ]]
then
    echo "Custom install exists. Deleting."
    sudo rm -rf /opt/aws/deepracer/lib.custom
fi

# Copy the build
echo "Copy files"
sudo cp -Rp $(pwd)/ws/install /opt/aws/deepracer/lib.custom

# Copy in the console code
echo "Copying console code"
sudo cp -Rp /opt/aws/deepracer/lib/device_console /opt/aws/deepracer/lib.custom/

# Create logs directory
sudo mkdir -p /opt/aws/deepracer/logs

# Restart deepracer
sudo systemctl restart deepracer-core

