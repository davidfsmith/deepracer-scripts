#!/usr/bin/env bash

disk=
ssid=
wifiPass=
all_disks=false
ignore_lock=false

uuid=$(uuidgen)

mnt_flash="/media/ubuntu/FLASH-$uuid"
mnt_boot="/media/ubuntu/BOOT-$uuid"
mnt_deepracer="/media/ubuntu/DEEPRACER-$uuid"
mnt_iso="/media/ubuntu/ISO-$uuid"

optstring=":d:s:w:al"

url_factory_reset=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/factory_reset.zip
url_ubuntu_iso=https://s3.amazonaws.com/deepracer-public/factory-restore/Ubuntu20.04/BIOS-0.0.8/ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso

log()
{
    [[ -z "$disk" ]] && log_disk="" || log_disk="[disk=$disk]" 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')][pid=$BASHPID]$log_disk $1"
}
show_usage()
{
    log "Usage: "
    log ""
    log "    $0 (-d <disk id> | -a) [ -s <SSID> -w <WIFI_PASSWORD>] [-l]"
    log ""
    log "    -d <disk id>       : selected usb device id on which the content will be created (required if -a is not used)"
    log "    -a                 : select all usb device id (required if -d is not used)"
    log "    -s <SSID>          : wifi ssid (optional, but requires -w when used)"
    log "    -w <WIFI_PASSWORD> : wifi password(optional, but requires -s when used)"
    log "    -l                 : ignore lock file (optional)"

    log ""
}
show_disk()
{
    log  ""
    log "List of available usb devices:"
    log  ""
    lsblk -o name,tran,size | grep -v " loop.*snap" | grep usb | while read line ; do log " $line" ; done
    log  ""
}

while getopts $optstring arg; do
    case ${arg} in
        a) all_disks=true;;
        l) ignore_lock=true;;
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

# check if you are running ubuntu, and if not exit
if [  -n "$(uname -a | grep Ubuntu)" ]; then
   log "Detected Ubuntu system"
else
   log "Detected a non Ubuntu system"
   log "  -> Unfortunately this script is only compatible with Ubuntu like systems"
   exit 0   
fi

if [ "$all_disks" = "true" ]; then
    disk_cnt=$(lsblk -o name,tran | grep usb | cut -d' ' -f1 | wc -l)
    
    if [ "$disk_cnt" -eq 0 ]; then
        log "Unable to find disk devices! Exiting..."
        exit 1
    fi

    log "You selected to execute the script on all attached USB drives below."

    show_disk

    log "Are you sure ? (y/n)"

    while true; do
        read -p "" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit 0;;
            * ) log "Please answer yes/y or no/n.";;
        esac
    done
    
    trap 'kill $(jobs -pr) 2>/dev/null' SIGINT SIGTERM EXIT

    while IFS= read -r result
    do
        log "Starting USB Build script for USB device $result"
        arg_wifi="-s $ssid -w $wifiPass"
        if [[ -z "$ssid" ]]; then
            arg_wifi=""
        else 
            arg_wifi="-s $ssid -w $wifiPass"
        fi
        if [ "$ignore_lock" = "true" ]; then
            arg_ignore_lock="-l"
        else
            arg_ignore_lock=""
        fi

        $0 -d $result $arg_wifi $arg_ignore_lock &
        pids="$pids $!"
    done < <(lsblk -o name,tran | grep usb | cut -d' ' -f1 )

    RESULT=0
    for pid in $pids; do
        wait $pid || let "RESULT=1"
    done

    if [ "$RESULT" == "0" ]; then
        log "Execution completed without issues."
    else
        log "One of the execition failed. Please check the logs."
    fi
    exit 0
fi

# check sudo permission, and add to sudoer with no password if not there yet
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


lock_set()
{
    log "Adding a lock file to prevent paralel execution"
    
    lock_file_path="$PWD/$0.lck.$disk"
    
    if [ ! -f ${lock_file_path} ]; then
        log "  Lock file doesn't exists, creating..."
        echo $disk > $lock_file_path
    else
        if [ "$ignore_lock" = "true" ]; then
            log "  Disk is already in use as per lock file, ignoring lock as per command parameters..."            
        else
            log "  Disk is already in use as per lock file, exiting..."
            exit 1
        fi
    fi
}
lock_remove()
{
    lock_file_path="$PWD/$0.lck.$disk"

    if [ -f ${lock_file_path} ]; then
        log " Removing lock file for Disk Id $disk..."
        rm $lock_file_path
    else
        log " Disk Id $disk lock file doesn't exists. Strange!!!!!"
    fi
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
        # if nothing returned then set to -1
        device_size=-1
    else
        # remove last character (G)
        device_size=${device_size::-1}
    # replace , by . incase you are using a differnt decimal separator, then extract the integer value
        device_size=$(echo $device_size | sed -r 's/,/./g' | xargs printf "%.*f\n" "$p")
    fi
}
create_partitions()
{
    sudo parted /dev/$disk -s -a optimal -- mktable msdos    2>&1 | while read line ; do log " $line" ; done
    sudo parted /dev/$disk -s -a optimal -- mkpart primary fat32 1MiB 4GiB     2>&1 | while read line ; do log " $line" ; done
    sudo parted /dev/$disk -s -a optimal -- mkpart primary fat32 4GiB 5GiB     2>&1 | while read line ; do log " $line" ; done
    sudo parted /dev/$disk -s -a optimal -- mkpart primary fat32 5GiB 25GiB    2>&1 | while read line ; do log " $line" ; done
}
format_partitions()
{
    sudo mkfs.vfat   /dev/$(echo $disk)1 -n "BOOT"        2>&1 | while read line ; do log " $line" ; done 
    sudo mkfs.vfat   /dev/$(echo $disk)2 -n "DEEPRACER"   2>&1 | while read line ; do log " $line" ; done 
    sudo mkfs.exfat  /dev/$(echo $disk)3 -n "FLASH"       2>&1 | while read line ; do log " $line" ; done 
}

mount_partitions()
{
    sudo rm -rf $mnt_boot      > /dev/null 2>&1
    sudo rm -rf $mnt_deepracer > /dev/null 2>&1
    sudo rm -rf $mnt_flash     > /dev/null 2>&1

    sudo mkdir -p $mnt_boot      > /dev/null 2>&1
    sudo mkdir -p $mnt_deepracer > /dev/null 2>&1
    sudo mkdir -p $mnt_flash     > /dev/null 2>&1

    sudo mount /dev/$(echo $disk)1   $mnt_boot      > /dev/null 2>&1
    sudo mount /dev/$(echo $disk)2   $mnt_deepracer > /dev/null 2>&1
    sudo mount /dev/$(echo $disk)3   $mnt_flash     > /dev/null 2>&1
}
unmount_partitions()
{
    sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 
}

# check if the device exists and its size, must be bigger than 25GB
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

lock_set

log "Installing additional packages..."
sudo apt-get --ignore-missing -o DPkg::Lock::Timeout=-1 install \
    mtools \
    exfat-utils \
    parted \
    dosfstools  -y -qq | while read line ; do log " $line" ; done # > /dev/null

log "Unmounting device existing partitions..."
unmount_partitions

log "Erasing device current partition table..."
sudo dd if=/dev/zero of=/dev/$disk bs=4k count=100 status=progress 2>&1 | while read line ; do log " $line" ; done
sudo sync 2>&1 | while read line ; do log " $line" ; done
sudo wipefs --all --force /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Creating new partitions..."
create_partitions

log "Informing the OS of partition table changes using partprobe..."
sudo partprobe /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

if ! sudo mkfs.vfat   /dev/$(echo $disk)1 > /dev/null 2>&1  ; then
    log "Unable to use to format the partitions."
    log "Consider using a different USB port and retry."
    log "Exiting..."*
    lock_remove
    exit 1
fi

log "Formating the device partitions.."
format_partitions

log "Downloading file..."
download_files

log "Mounting the partitions & iso..."
mount_partitions
       
log "Generating the FLASH partition content using rsync with factory_reset ..."
sudo rsync -rltdvz --progress factory_reset/* $mnt_flash 2>&1 # | while read line ; do log " $line" ; done 

log "Generating the BOOT partition content using dd and the ubuntu iso..."
sudo dd if=${url_ubuntu_iso##*/}  of=/dev/$(echo $disk)1 conv=fdatasync bs=4M status=progress # 2>&1 | while read line ; do log " $line" ; done 
sudo sync

# Create wifi-creds.txt for auto network goodness
if [ ! -z "$ssid" ] && [ ! -z "$wifiPass" ]; then
    log "Generating the DEEPRACER partition content with WiFi credentials..."
    (
        echo "ssid: ${ssid}" 
        echo "password: ${wifiPass}" 
    ) | sudo tee $mnt_deepracer/wifi-creds.txt > /dev/null 2>&1
fi

sudo lsblk /dev/$disk -o name,fstype,label,size,mountpoint,partflags,partlabel 2>&1 | while read line ; do log " $line" ; done 
sudo fdisk -l /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Unmounting device existing partitions..."
unmount_partitions

log "Removing partition mount points..."
sudo rm -rf $mnt_boot      > /dev/null 2>&1
sudo rm -rf $mnt_deepracer > /dev/null 2>&1
sudo rm -rf $mnt_flash     > /dev/null 2>&1

log "Ejecting the disk..."
sudo eject /dev/$disk

usb=$(find /sys/bus/usb/devices/usb*/ -name dev | grep "/$disk/dev")
log "You can now remove your device : "
log "   USB port id     : $(echo ${usb##*/usb} | cut -d/ -f 1)"
log "   USB port host   : $(echo ${usb##*/host} | cut -d/ -f 1)"
log "   USB port target : $(echo ${usb##*/target} | cut -d/ -f 1)"

lock_remove 

log "Done"
exit 0
