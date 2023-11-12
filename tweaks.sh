#!/usr/bin/env bash

usage()
{
    echo "Usage: sudo $0 -h HOSTNAME -p PASSWORD"
    exit 0
}

# Check we have the privileges we need
if [ `whoami` != root ]; then
    echo "Please run this script as root or using sudo"
    exit 0
fi

oldHost=NULL
varHost=NULL
varPass=NULL

backupDir=/home/deepracer/backup
if [ ! -d ${backupDir} ]; then
    mkdir ${backupDir}
fi

optstring=":h:p:"

while getopts $optstring arg; do
    case ${arg} in
        h) varHost=${OPTARG};;
        p) varPass=${OPTARG};;
        ?) usage ;;
    esac
done

# Stop DeepRacer Stack
systemctl stop deepracer-core

# Disable IPV6 on all interfaces
cp /etc/sysctl.conf ${backupDir}/sysctl.conf.bak
printf "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf

# Update the DeepRacer console password
if [ $varPass != NULL ]; then
    echo "Updating password to: $varPass"
    tempPass=$(echo -n $varPass | sha224sum)
    IFS=' ' read -ra encryptedPass <<< $tempPass
    cp /opt/aws/deepracer/password.txt ${backupDir}/password.txt.bak
    printf "${encryptedPass[0]}" > /opt/aws/deepracer/password.txt
fi

# Grant deepracer user sudoers rights
echo deepracer ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/deepracer
chmod 0440 /etc/sudoers.d/deepracer

# Check version
. /etc/lsb-release
if [ $DISTRIB_RELEASE = "16.04" ]; then
    echo 'Ubuntu 16.04 detected'
    echo "Please update your car to 20.04 -> https://docs.aws.amazon.com/deepracer/latest/developerguide/deepracer-ubuntu-update-preparation.html"
    exit 1

elif [ $DISTRIB_RELEASE = "20.04" ]; then
    echo 'Ubuntu 20.04 detected'

    bundlePath=/opt/aws/deepracer/lib/device_console/static
    webserverPath=/opt/aws/deepracer/lib/webserver_pkg/lib/python3.8/site-packages/webserver_pkg
    systemPath=/opt/aws/deepracer/lib/deepracer_systems_pkg/lib/python3.8/site-packages/deepracer_systems_pkg

else
    echo 'Not sure what version of OS, terminating.'
    exit 1
fi

echo 'Updating...'

# Get latest key from OpenVINO
curl -o GPG-PUB-KEY-INTEL-SW-PRODUCTS https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS

# Update Ubuntu
sudo apt-get update
sudo apt-get upgrade -o Dpkg::Options::="--force-overwrite" -o Dpkg::Options::='--force-confold' -y

# Update DeepRacer
sudo apt-get install aws-deepracer-* -y

# Ensure all packages installed
sudo apt-get update
sudo apt-get upgrade -y

# Remove redundant packages
sudo apt autoremove -y

# If changing hostname need to change the flag in network_config.py
# /opt/aws/deepracer/lib/deepracer_systems_pkg/lib/python3.8/site-packages/deepracer_systems_pkg/network_monitor_module/network_config.py
# SET_HOSTNAME_TO_CHASSIS_SERIAL_NUMBER = False
if [ $DISTRIB_RELEASE = "20.04" ]; then
    if [ $varHost != NULL ]; then
        oldHost=$HOSTNAME
        hostnamectl set-hostname ${varHost}
        cp /etc/hosts ${backupDir}/hosts.bak
        rm /etc/hosts
        cat ${backupDir}/hosts.bak | sed -e "s/${oldHost}/${varHost}/" > /etc/hosts

        cp ${systemPath}/network_monitor_module/network_config.py ${backupDir}/network_config.py.bak
        rm ${systemPath}/network_monitor_module/network_config.py
        cat ${backupDir}/network_config.py.bak | sed -e "s/SET_HOSTNAME_TO_CHASSIS_SERIAL_NUMBER = True/SET_HOSTNAME_TO_CHASSIS_SERIAL_NUMBER = False/" > ${systemPath}/network_monitor_module/network_config.py

    fi

    # Disable software_update
    cp ${systemPath}/software_update_module/software_update_config.py ${backupDir}/software_update_config.py.bak
    rm ${systemPath}/software_update_module/software_update_config.py
    cat ${backupDir}/software_update_config.py.bak | sed -e "s/ENABLE_PERIODIC_SOFTWARE_UPDATE = True/ENABLE_PERIODIC_SOFTWARE_UPDATE = False/" > ${systemPath}/software_update_module/software_update_config.py

fi

# Disable video stream by default
cp $bundlePath/bundle.js ${backupDir}/bundle.js.bak
rm $bundlePath/bundle.js
cat ${backupDir}/bundle.js.bak | sed -e "s/isVideoPlaying\: true/isVideoPlaying\: false/" > $bundlePath/bundle.js

# Disable system suspend
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Disable network power saving
echo -e '#!/bin/sh\n/usr/sbin/iw dev mlan0 set power_save off\n' > /etc/network/if-up.d/disable_power_saving
chmod 755 /etc/network/if-up.d/disable_power_saving

# Enable SSH
service ssh start
ufw allow ssh

# Allow multiple logins on the console
cp /etc/nginx/sites-enabled/default ${backupDir}/default.bak
rm /etc/nginx/sites-enabled/default
cat ${backupDir}/default.bak | sed -e "s/auth_request \/auth;/#auth_request \/auth;/" > /etc/nginx/sites-enabled/default

# Change the cookie duration
cp $webserverPath/login.py ${backupDir}/login.py.bak
rm $webserverPath/login.py
cat ${backupDir}/login.py.bak | sed -e "s/datetime.timedelta(hours=1)/datetime.timedelta(hours=12)/" > $webserverPath/login.py

# Disable Gnome and other services
# - to enable gnome - systemctl set-default graphical
# - to start gnome -  systemctl start gdm3
systemctl set-default multi-user
systemctl stop bluetooth
systemctl stop cups-browsed

# Default running service list
# service --status-all | grep '\[ + \]'
#  [ + ]  acpid
#  [ + ]  alsa-utils
#  [ + ]  apparmor
#  [ + ]  apport
#  [ + ]  avahi-daemon
#  [ + ]  binfmt-support
#  [ + ]  bluetooth
#  [ + ]  console-setup
#  [ + ]  cron
#  [ + ]  cups-browsed
#  [ + ]  dbus
#  [ + ]  dnsmasq
#  [ + ]  fail2ban
#  [ + ]  grub-common
#  [ + ]  irqbalance
#  [ + ]  isc-dhcp-server
#  [ + ]  keyboard-setup
#  [ + ]  kmod
#  [ + ]  lightdm
#  [ + ]  network-manager
#  [ + ]  networking
#  [ + ]  nginx
#  [ + ]  ondemand
#  [ + ]  procps
#  [ + ]  rc.local
#  [ + ]  resolvconf
#  [ + ]  rsyslog
#  [ + ]  speech-dispatcher
#  [ + ]  ssh
#  [ + ]  thermald
#  [ + ]  udev
#  [ + ]  ufw
#  [ + ]  urandom
#  [ + ]  uuidd
#  [ + ]  watchdog
#  [ + ]  whoopsie

# Restart services
echo 'Restarting services'
systemctl start deepracer-core
service nginx restart

echo "Done!"
