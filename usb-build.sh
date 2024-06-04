#!/usr/bin/env bash

usage()
{
    echo "Usage: sudo $0 -d disk2 [ -s SSID -w WIFI_PASSWORD]"
    exit 0
}

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

echo -e -n "\nCreating partitions on USB /dev/${disk}\n"
diskutil partitionDisk /dev/${disk} MBR fat32 BOOT 4gb fat32 DEEPRACER 2gb exfat FLASH 14gb

# Grab the ISO -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
echo -e -n "\nChecking if we have the Ubuntu ISO"
isoFilename=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
isoURL=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso
if [ ! -f ${isoFilename} ]; then
    echo -e -n "\n- ISO not found - downloading"
    curl -O ${isoURL}
else
    echo -e -n "\n- ISO found"
fi

# Create wifi-creds.txt for auto network goodness
if [ ${ssid} != NULL ] && [ ${wifiPass} != NULL ]; then
    echo -e -n "\nWriting 'wifi-creds.txt'\n"

    sudo cat > /Volumes/DEEPRACER/wifi-creds.txt << EOF
ssid: ${ssid}
password: ${wifiPass}
EOF

fi

# https://github.com/unetbootin/unetbootin/wiki/commands
echo -e -n "\n- Writing ISO to USB - Password required for disk access"
sudo /Applications/unetbootin.app/Contents/MacOS/unetbootin method=diskimage isofile=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso installtype=USB targetdrive=/dev/${disk}s1 autoinstall=yes
# sudo diskutil umount /dev/${disk}s1
# sudo dd if=${isoFilename} of=/dev/${disk}s1 bs=1m status=progress

# Grab the zip -> https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
echo -e -n "\nChecking if we have 'factory_reset.zip'\n"
factoryResetURL=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
if [ ! -d factory_reset ]; then
    echo -e -n "\n- Zip file not found - downloading"
    curl -O ${factoryResetURL}
    unzip factory_reset.zip

    # uncomment `# reboot` on lines 520 & 528 of `usb_flash.sh`
    echo -e -n "\n- Updating 'usb_flash.sh' so the car reboots after install"
    cp factory_reset/usb_flash.sh factory_reset/usb_flash.sh.bak
    rm factory_reset/usb_flash.sh
    cat factory_reset/usb_flash.sh.bak | sed -e "s/#reboot/reboot/g" > factory_reset/usb_flash.sh
else
    echo -e -n "\nZip file found"
fi

echo -e -n "\n- Writing zip file contents to USB\n"
rsync -av --progress factory_reset/* /Volumes/FLASH

echo -e -n "\nEjecting USB /dev/${disk}\n"
sudo diskutil eject /dev/${disk}
echo -e -n "\nDone"

exit 0
