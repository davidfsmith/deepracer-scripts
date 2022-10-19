#!/usr/bin/env bash

# https://github.com/aws-deepracer/aws-deepracer-launcher/blob/main/getting-started.md

# Install pre-requisites
sudo apt-get install -y python3-websocket python3-colcon-common-extensions python3-rosinstall

# Set the environment
source /opt/ros/foxy/setup.bash 
source /opt/intel/openvino_2021/bin/setupvars.sh

# Install GPU drivers (dependancy for device-param PR)
sudo /opt/intel/openvino_2021/install_dependencies/install_NEO_OCL_driver.sh

# Update ROS
sudo rosdep init
sudo rosdep fix-permissions
rosdep update