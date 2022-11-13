#!/usr/bin/env bash

usage()
{
    echo "Usage: sudo $0 -d disk2 [ -s SSID -w WIFI_PASSWORD]"
    exit 0
}

# Check we have the privileges we need
# if [ `whoami` != root ]; then
#     echo "Please run this script as root or using sudo"
#     exit 0
# fi

disk=disk2
ssid=NULL
wifiPass=NULL

optstring=":d:s:w:"

while getopts $optstring arg; do
    case ${arg} in
        d) disk=${OPTARG};;
        s) ssid=${OPTARG};;
        w) wifiPass=${OPTARG};;
        ?) usage ;;
    esac
done

if [ $OPTIND -eq 1 ]; then
    echo "No options selected."
    usage
fi

diskutil partitionDisk /dev/${disk} MBR fat32 BOOT 4gb fat32 DEEPRACER 2gb exfat FLASH 14gb

# Grab the zip -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
factoryResetURL=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
if [ ! -d factory_reset ]; then
    curl -O ${factoryResetURL}
    unzip factory_reset.zip

    # uncomment `# reboot` on lines 520 & 528 of `usb_flash.sh`
    cp factory_reset/usb_flash.sh factory_reset/usb_flash.sh.bak
    rm factory_reset/usb_flash.sh
    cat factory_reset/usb_flash.sh.bak | sed -e "s/#reboot/reboot/g" > factory_reset/usb_flash.sh
fi
rsync -av --progress factory_reset/* /Volumes/FLASH

# Grab the ISO -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
isoFilename=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
isoURL=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
if [ ! -f ${isoFilename} ]; then
    curl -O ${isoURL}
fi

# Issues with OSX Ventura -> https://github.com/unetbootin/unetbootin/issues/337
# https://github.com/unetbootin/unetbootin/wiki/commands
sudo /Applications/unetbootin.app/Contents/MacOS/unetbootin method=diskimage isofile=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso installtype=USB targetdrive=/dev/${disk}s1 autoinstall=yes

# Create wifi-creds.txt for auto network goodness
if [ ${ssid} != NULL ] && [ ${wifiPass} != NULL ]; then

    cat > /Volumes/DEEPRACER/wifi-creds.txt << EOF
ssid: ${ssid}
password: ${wifiPass}
EOF

fi

echo "Done"

exit 0