# DeepRacer Scripts

Please note this scripts are provided as is.... if something breaks through you using it then a) I'm sorry b) fix it and submit a PR ;-)

## dev-build.sh

Runs on the car from `/home/deepracer` and the intention is that can be used to test pull requests / dev code

    chmod +x dev-build.sh
    sudo nohup ./dev-build.sh > ./dev-build.log

## usb-build.sh

(OSX only)

Requirements:
* `factory_reset.zip` unzipped in the same directory
* `ubuntu-20.04.1-20.11.13_V1-desktop-amd64.iso` in the same directory
* https://unetbootin.github.io/ installed

Download both from here https://docs.aws.amazon.com/deepracer/latest/developerguide/deepracer-ubuntu-update-preparation.html