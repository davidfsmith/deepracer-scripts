#!/usr/bin/env bash

url_factory_reset=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
url_ubuntu_iso=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso

log()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}
show_usage()
{
    log "Usage: "
    log ""
    log "    sudo $0 -d <disk id> [ -s SSID -w WIFI_PASSWORD]"
    log ""
}

show_disk()
{
    log  ""
    log "List of available devices:"
    log  ""
    lsblk -o name,tran,size | grep -v " loop.*snap" | grep usb | while read line ; do log " $line" ; done
    log  ""
}

donwload_file()
{
    url="$1"
    file_name=${url##*/}
    dir_name="${file_name%.*}"
    
    log "Checking if ${file_name} has been downloaded..."
    if [ ! -f ${file_name} ]; then
        log "   --> downloading ${file_name}"
        # curl -O ${url}
        wget -O ${file_name}.tmp ${url} && mv ${file_name}{.tmp,}
        log exit code $? 
    else
        log "   --> ${file_name} is already present"
    fi
}

unzip_file()
{
    file_name="$1"
    dir_name="${file_name%.*}"
    
    log "Checking if ${file_name} has been unzipped..."
    if [ ! -d ${dir_name} ]; then
            log "   --> extracting ${file_name}"
            unzip -qq ${file_name} 
            ret=$?
            if [ $ret != 0 ]; then
                  log "Unexpected exit code ${ret}. Exiting ..."
                  exit 1
            fi    
    else
            log "   --> ${file_name} is already extracted"
    fi
}

get_factory_reset()
{
    # Grab the zip -> $url_factory_reset
    donwload_file $url_factory_reset
    unzip_file factory_reset.zip
    
    log "Adjusting flash script..."    
    # uncomment `# reboot` on lines 520 & 528 of `usb_flash.sh`
    cp factory_reset/usb_flash.sh factory_reset/usb_flash.sh.bak
    rm -f factory_reset/usb_flash.sh
    cat factory_reset/usb_flash.sh.bak | sed -e "s/#reboot/reboot/g" > factory_reset/usb_flash.sh
    log "   --> done"
}

get_ubuntu_iso()
{
    # Grab the ISO -> $url_ubuntu_iso
    donwload_file $url_ubuntu_iso
}

download_files()
{
    get_factory_reset
    get_ubuntu_iso
}

get_usb_device_size()
{
    device_name="$1"
    device_size="$(lsblk -o name,tran,size | grep -v " loop.*snap" | grep usb | grep "$device_name  " | awk '{print $3}' )"
    if [ -z "$device_size" ]; then
        device_size=-1
    else
        device_size=${device_size::-1}
        device_size=$(echo $device_size | xargs printf "%.*f\n" "$p")
    fi
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
            ?) show_usage ;;
    esac
done

if [ $OPTIND -eq 1 ]; then
    log "No options selected."
    show_usage
    exit 1
fi

get_usb_device_size $disk

if [ "$device_size" -lt 0 ]; then
    log "Unable to find the provided disk device : $disk"
    
    show_usage
    show_disk
    exit 1
fi


if [ "$device_size" -lt "25" ]; then
    log "USB device is too small. It must be at least 25GB"
    
    show_usage
    show_disk
    exit 1
fi

sudo_response=$(SUDO_ASKPASS=/bin/false sudo -A whoami 2>&1 | wc -l)
if [ $sudo_response = 2 ]; then
    can_sudo=1
elif [ $sudo_response = 1 ]; then
    can_sudo=0
else
    log "Unexpected sudo response: $sudo_response" >&2
    exit 1
fi


if [[ "$EUID" != 0 ]]; then
    sudo -k # make sure to ask for password on next sudo
    if sudo true; then
        sudo_ok=1
        
        sudoer_user_file="/etc/sudoers.d/dont-prompt-$USER-for-sudo-password"
        if [ ! -f "$sudoer_user_file" ]; then
            log "Adding current user to sudoers nopasswd list"
            echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee $sudoer_user_file > /dev/null 2>&1 
        fi     

    else
    	log "Please provide the sudo password"
    	exit 1
    fi
fi

if [[ $OSTYPE == 'darwin'* ]]; then
    log "Detected macOS, so we may need some package to install but I don't know"
  
    partition_flash="/Volumes/FLASH"
    partition_boot="/Volumes/BOOT"
    partition_deepracer="/Volumes/DEEPRACER"
    
    log "Partitioning USB flash drive ${disk} using macOS diskutil"  
    diskutil partitionDisk /dev/${disk} MBR fat32 BOOT 4gb fat32 DEEPRACER 2gb exfat FLASH 14gb    
    
    log "Downloading file..."
    download_files
    
    log "RSync factory_reset into flash volume..."
    rsync -av --progress factory_reset/* $partition_flash

    log "Creating BOOT volume using unetbootin..."
    # Issues with OSX Ventura -> https://github.com/unetbootin/unetbootin/issues/337
    # https://github.com/unetbootin/unetbootin/wiki/commands
    sudo /Applications/unetbootin.app/Contents/MacOS/unetbootin method=diskimage isofile=ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso installtype=USB targetdrive=/dev/${disk}s1 autoinstall=yes

    # Create wifi-creds.txt for auto network goodness
    if [ ${ssid} != NULL ] && [ ${wifiPass} != NULL ]; then
        log "Adding WiFi credentials"
        (
            echo "ssid: ${ssid}" 
            echo "password: ${wifiPass}" 
        ) | sudo tee $partition_deepracer/wifi-creds.txt > /dev/null 2>&1
    fi
elif [[ $OSTYPE == 'linux'* ]]; then
    if grep -qi microsoft /proc/version; then
        log "Detected Linux on Windows (WSL)"
        log "  -> Unfortunately, USB devices are not fully supported with WSL and therefore this script won't function properly."        
        exit 0        
    else
        log "Detected Linux native"
        
        uuid=$(uuidgen)

        partition_flash="/media/ubuntu/FLASH-$uuid"
        partition_boot="/media/ubuntu/BOOT-$uuid"
        partition_deepracer="/media/ubuntu/DEEPRACER-$uuid"
        
        log "Installing additional packages..."
        sudo apt-get install gdisk gparted mtools exfatprogs -y -qq | while read line ; do log " $line" ; done # > /dev/null

        # log "Unmounting all existing partitions..."
        # sudo ls /dev/$disk[1-99] | xargs -n1 sudo umount -l > /dev/null 2>&1 

        # log "Erasing the current partition table..."
        # sudo dd if=/dev/zero of=/dev/$disk bs=512 count=1 seek=0 > /dev/null 2>&1 # status=progress

        log "Creating new partitions..."
        (
            echo o # create a new empty GUID partition table (GPT)
            echo Y
            echo n # Create partition
            echo 1 # Partition number
            echo   # First sector 
            echo +4GiB # Last sector (Accept default: varies)
            echo   # partition GUID
            echo n # Add a new partition
            echo 2 # Partition number
            echo   # First sector 
            echo +1GiB # Last sector (Accept default: varies)
            echo   # partition GUID
            echo n # Add a new partition
            echo 3 # Partition number
            echo   # First sector 
            echo +20GiB # Last sector (Accept default: varies)
            echo   # partition GUID
            echo w # write and exit
            echo Y
        ) | sudo gdisk /dev/$disk | while read line ; do log " $line" ; done # > /dev/null 2>&1 
	
        sudo sgdisk -c 1:BOOT      /dev/$(echo $disk) 
        sudo sgdisk -c 2:DEEPRACER /dev/$(echo $disk)
        sudo sgdisk -c 3:FLASH     /dev/$(echo $disk)
        
        log "Informing the OS of partition table changes using partprobe..."
        sudo partprobe /dev/$disk # > /dev/null 2>&1 

        # log "Unmounting all existing partitions..."
        # sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 

        # log "Wiping the disk..."
        # sudo wipefs /dev/$(echo $disk)1 | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        # sudo wipefs /dev/$(echo $disk)2 | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        # sudo wipefs /dev/$(echo $disk)3 | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        
        log "Formating the disk partitions.."
        sudo mkfs.vfat  /dev/$(echo $disk)1 -n "BOOT"       | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        sudo mkfs.vfat  /dev/$(echo $disk)2 -n "DEEPRACER"  | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        sudo mkfs.exfat /dev/$(echo $disk)3 -L "FLASH"      | while read line ; do log " $line" ; done # > /dev/null 2>&1
        
        log "New partition list..."
        lsblk /dev/$disk -o name,mountpoint,label,size,uuid | while read line ; do log " $line" ; done
        
        # log "Mounting the partitions..."
        # sudo rm -rf $partition_boot
        # sudo rm -rf $partition_deepracer
        # sudo rm -rf $partition_flash

        # sudo mkdir -p $partition_boot
        # sudo mkdir -p $partition_deepracer
        # sudo mkdir -p $partition_flash

        # sudo mount /dev/$(echo $disk)1 $partition_boot 
        # sudo mount /dev/$(echo $disk)2 $partition_deepracer 
        # sudo mount /dev/$(echo $disk)3 $partition_flash

        log "Downloading file..."
        download_files
        
        log "RSync factory_reset into flash volume..."
        sudo rsync -rltdvz --progress factory_reset/* $partition_flash # | while read line ; do log " $line" ; done
        
        log "Creating BOOT volume using dd..."
        sudo dd if=${url_ubuntu_iso##*/} of=/dev/$(echo $disk)1 conv=fdatasync bs=8M status=progress | while read line ; do log " $line" ; done

        # Create wifi-creds.txt for auto network goodness
        if [ ${ssid} != NULL ] && [ ${wifiPass} != NULL ]; then
            log "Adding WiFi credentials"
            (
                echo "ssid: ${ssid}" 
                echo "password: ${wifiPass}" 
            ) | sudo tee $partition_deepracer/wifi-creds.txt > /dev/null 2>&1
        fi

        # log "Changing ownership of factory_reset files in flash volume..."
        # sudo chown -fR $(id -u):$(id -g) $partition_flash

        log "Synching the drive..."
        sudo sync -f /dev/$disk

        log "Unmounting all existing partitions..."
        sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 

        sudo exfatlabel /dev/$(echo $disk)1 BOOT      | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        sudo exfatlabel /dev/$(echo $disk)2 DEEPRACER | while read line ; do log " $line" ; done # > /dev/null 2>&1 
        sudo exfatlabel /dev/$(echo $disk)3 FLASH     | while read line ; do log " $line" ; done # > /dev/null 2>&1 

        sudo rm -rf $partition_boot      > /dev/null 2>&1
        sudo rm -rf $partition_deepracer > /dev/null 2>&1
        sudo rm -rf $partition_flash     > /dev/null 2>&1

        log "Ejecting the disk..."        
        sudo eject /dev/$disk       
    fi
fi

log "Done"
exit 0
