# DeepRacer Scripts

Please note this scripts are provided as is.... if something breaks through use then a) I'm sorry b) fix it and submit a PR ;-)

## dev-build.sh

Runs on the car from `/home/deepracer` and the intention is that can be used to test pull requests / dev code

    chmod +x dev-build.sh
    bash /dev-build.sh

## dev-stack-*

Refactoring of the `dev-build.sh`, which splits it into three distinct scripts.

To ensure that car configuration is correct, please run `tweaks.sh` once after flashing the car.

| File | Description |
|------|--------------|
| `dev-stack-dependencies.sh` | Installs the dependencies for a custom DR stack. Script is only required to be run one time. |
| `dev-stack-build.sh` | Downloads the packages defined in `ws/.rosinstall` and builds them into the `ws` folder. |
| `dev-stack-install.sh` | Installs the stack built in `ws/install` into `/opt/aws/deepracer/lib`.

## usb-build

Requirements:
* `factory_reset.zip` unzipped in the same directory (will be downloaded and unzipped if missing)
* `ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso` in the same directory (will be downloaded if missing)

Both files can be downloaded from here https://docs.aws.amazon.com/deepracer/latest/developerguide/deepracer-ubuntu-update-preparation.html

#### OSX version  

Requirements:

* https://unetbootin.github.io/ installed

Command:

```
sudo ./usb-build.sh -d disk2
```

**Note:** Should be updated to use the more generic dd

#### Windows PowerShell version

Requirements:

* Run in an Administrator / elevated mode PowerShell command window

Command:

```
start powershell {.\usb-build.ps1 -DiskId <disk number>}
```

Additional switches:

Description                                           | Switch
------------------------------------------------------|---------------------------------------------------
Provide Wifi Credentials                              | `-SSID <WIFI_SSID> -SSIDPassword <WIFI_PASSWORD>`
Create partitions (default value is True)             | `-CreatePartition <True/False>`
Ignore lock files (default value is False)            | `-IgnoreLock <True/False>`
Create Factory Reset content (default value is False) | `-IgnoreFactoryReset <True/False>`
Create Boot Drive (default value is False)            | `-IgnoreBootDrive <True/False>`


## tweaks.sh

A script to change a couple of things on the car that I've found useful at events

* Change the hostname
* Change the car console password (**Note:** Update the default password in the script)
* Update Ubuntu
* Update the car software
* Disable IPV6 on network interfaces
* Disable the video stream on the car console by default
* Disable system suspend
* Disable network power saving
* Disable the software update check
* Enable SSH (You've probably already done this)
* Allow multiple logins to the car console
* Increase the car console cookie duration
* Disable Gnome, Bluetooth & CUPS

    sudo ./tweaks.sh -h newhostname -p magicpassword

## reset-usb.sh

Needs to be run on the car to reset USB in the event of a failure of the front USB hub, faster than a full reboot of the car - works ~70% of the time YMMV

## VS.Code Dev Container

Files have been added to the repository (`.devcontainer` and `.vscode`) that allows the normal DR packages to be built on another machine, isolated from what is installed on the OS. Tested on Ubuntu 20.04.

Container includes most relevant ROS2 Foxy packages, as well as the OpenVINO release that is used on the car.

Before opening the container run `docker volume create deepracer-ros-bashhistory` to get your commandline history enabled inside the container.
