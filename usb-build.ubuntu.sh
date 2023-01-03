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
        # if nothing returned then set to -1
        device_size=-1
    else
        # remove last character (G)
        device_size=${device_size::-1}
    # replace , by . incase you are using a differnt decimal separator, then extract the integer value
        device_size=$(echo $device_size | sed -r 's/,/./g' | xargs printf "%.*f\n" "$p")
    fi
}

# check if you are running ubuntu, and if not exit
if [  -n "$(uname -a | grep Ubuntu)" ]; then
   log "Detected Ubuntu system"
else
   log "Detected a non Ubuntu system"
   log "  -> Unfortunately this script is only compatible with Ubuntu like systems"
   exit 0   
fi  
    
disk=NULL
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

uuid=$(uuidgen)

mnt_flash="/media/ubuntu/FLASH-$uuid"
mnt_boot="/media/ubuntu/BOOT-$uuid"
mnt_deepracer="/media/ubuntu/DEEPRACER-$uuid"
mnt_iso="/media/ubuntu/ISO-$uuid"

log "Installing additional packages..."
sudo apt-get install gdisk       -y -qq | while read line ; do log " $line" ; done # > /dev/null
sudo apt-get install mtools      -y -qq | while read line ; do log " $line" ; done # > /dev/null
sudo apt-get install exfat-utils -y -qq | while read line ; do log " $line" ; done # > /dev/null
sudo apt-get install parted      -y -qq | while read line ; do log " $line" ; done # > /dev/null

log "Unmounting all existing partitions..."
sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 

log "Erasing the current partition table..."
sudo dd if=/dev/zero of=/dev/$disk count=1
# sudo dd if=/dev/zero of=/dev/$disk bs=512 count=1 seek=0 2>&1 | while read line ; do log " $line" ; done 

log "Erasing disk..."
sudo wipefs --all --force /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Creating new partitions..."
(
    echo x
    echo z
    echo w
    echo Y # confirm overwrite
) | sudo gdisk /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

sudo sgdisk -o /dev/$disk 
sudo sgdisk --new 1::+512M --typecode 1:8300 /dev/$disk 
sudo sgdisk --new 2::+4G   --typecode 2:8300 /dev/$disk 
sudo sgdisk --new 3::+1G   --typecode 3:8300 /dev/$disk 
sudo sgdisk --new 4::+20G  --typecode 4:8300 /dev/$disk 
(
    echo o # Create a new empty DOS partition table
    echo Y # confirm overwrite
    echo n # Add a new partition
    echo 1 # Partition number
    echo   # First sector (Accept default: 1)
    echo +5GiB # Last sector (Accept default: varies)
    echo   # GUUID
    echo n # Add a new partition
    echo 2 # Partition number
    echo   # First sector (Accept default: 1)
    echo +1GiB # Last sector (Accept default: varies)
    echo   # GUUID
    echo n # Add a new partition
    echo 3 # Partition number
    echo   # First sector (Accept default: 1)
    echo +20GiB # Last sector (Accept default: varies)
    echo   # GUUID
    echo x # toggle a bootable flag
    echo a # toggle a bootable flag
    echo 1 # Partition number
    echo 2 # Attribute
    echo   # GUUID
    echo w # Write changes
    echo Y # confirm overwrite    
) | sudo gdisk /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Informing the OS of partition table changes using partprobe..."
sudo partprobe /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Unmounting all existing partitions..."
sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 

log "Formating the disk partitions.."
sudo mkfs.vfat  /dev/$(echo $disk)1 -n "BOOT"        2>&1 | while read line ; do log " $line" ; done 
sudo mkfs.vfat  /dev/$(echo $disk)2 -n "DEEPRACER"   2>&1 | while read line ; do log " $line" ; done 
sudo mkfs.exfat /dev/$(echo $disk)3 -n "FLASH"       2>&1 | while read line ; do log " $line" ; done 

log "Downloading file..."
download_files

log "Mounting the partitions & iso..."
sudo rm -rf $mnt_boot      > /dev/null 2>&1
sudo rm -rf $mnt_deepracer > /dev/null 2>&1
sudo rm -rf $mnt_flash     > /dev/null 2>&1
sudo rm -rf $mnt_iso       > /dev/null 2>&1

sudo mkdir -p $mnt_boot      > /dev/null 2>&1
sudo mkdir -p $mnt_deepracer > /dev/null 2>&1
sudo mkdir -p $mnt_flash     > /dev/null 2>&1
sudo mkdir -p $mnt_iso       > /dev/null 2>&1

sudo mount /dev/$(echo $disk)1   $mnt_boot      > /dev/null 2>&1
sudo mount /dev/$(echo $disk)2   $mnt_deepracer > /dev/null 2>&1
sudo mount /dev/$(echo $disk)3   $mnt_flash     > /dev/null 2>&1
sudo mount ${url_ubuntu_iso##*/} $mnt_iso       > /dev/null 2>&1
        
log "Generating the FLASH partition content using rsync with factory_reset ..."
sudo rsync -rltdvz --progress factory_reset/* $mnt_flash 2>&1 # | while read line ; do log " $line" ; done 

log "Generating the BOOT partition content using dd and the ubuntu iso..."
# sudo dd if=${url_ubuntu_iso##*/}  of=/dev/$(echo $disk)1 conv=fdatasync bs=8M status=progress 2>&1 | while read line ; do log " $line" ; done 
# sudo parted /dev/$(echo $disk)1 set 1 boot on
sudo cp -rfi $mnt_iso/* $mnt_boot 2>&1 # | while read line ; do log " $line" ; done 


# Create wifi-creds.txt for auto network goodness
if [ ${ssid} != NULL ] && [ ${wifiPass} != NULL ]; then
    log "Generating the DEEPRACER partition content with WiFi credentials..."
    (
        echo "ssid: ${ssid}" 
        echo "password: ${wifiPass}" 
    ) | sudo tee $mnt_deepracer/wifi-creds.txt > /dev/null 2>&1
fi

sudo lsblk /dev/$disk -o name,fstype,label,size,mountpoint,partflags,partlabel 2>&1 | while read line ; do log " $line" ; done 
sudo fdisk -l /dev/$disk 2>&1 | while read line ; do log " $line" ; done 

log "Unmounting all existing partitions..."
sudo ls /dev/$disk[1-99] 2> /dev/null | xargs -n1 sudo umount -l > /dev/null 2>&1 

log "Removing partition mount points..."
sudo rm -rf $mnt_boot      > /dev/null 2>&1
sudo rm -rf $mnt_deepracer > /dev/null 2>&1
sudo rm -rf $mnt_flash     > /dev/null 2>&1
sudo rm -rf $mnt_iso       > /dev/null 2>&1

# log "Ejecting the disk..."
# sudo eject /dev/$disk

usb=$(find /sys/bus/usb/devices/usb*/ -name dev | grep "/$disk/dev")
log "You can now remove your device : "
log "   USB port id     : $(echo ${usb##*/usb} | cut -d/ -f 1)"
log "   USB port host   : $(echo ${usb##*/host} | cut -d/ -f 1)"
log "   USB port target : $(echo ${usb##*/target} | cut -d/ -f 1)"

log "Done"
exit 0
