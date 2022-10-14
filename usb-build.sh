#!/bin/bash

usage()
{
    echo "Usage: sudo $0 -d disk2"
    exit 0
}

# Check we have the privileges we need
if [ `whoami` != root ]; then
    echo "Please run this script as root or using sudo"
    exit 0
fi

disk=2

optstring=":d:"

while getopts $optstring arg; do
    case ${arg} in
        d) disk=${OPTARG};;
        ?) usage ;;
    esac
done

if [ $OPTIND -eq 1 ]; then
    echo "No options selected."
    usage
fi


diskutil partitionDisk /dev/${disk} MBR fat32 BOOT 8gb exfat FLASH 16gb

# Grab the ISO -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
# diskutil unmount /dev/${disk}s1
# sudo dd if=./ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso of=/dev/${disk}s1 status=progress  <- didn't work
# https://github.com/unetbootin/unetbootin/wiki/commands
/Applications/unetbootin.app/Contents/MacOS/unetbootin method=diskimage isofile=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso installtype=USB targetdrive=/dev/${disk}s1 autoinstall=yes

# Grab the zip -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
# Note if you have a smaller USB stick you'll need to unzip factory_reset.zip and copy the files across
cp -R ./factory_reset/ /Volumes/FLASH
