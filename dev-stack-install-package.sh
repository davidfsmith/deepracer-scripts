#!/usr/bin/env bash

export DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Build the core packages
sudo systemctl stop deepracer-core

# DeepRacer Repos
sudo cp $DIR/files/deepracer-larsll.asc /etc/apt/trusted.gpg.d/
sudo cp $DIR/files/aws_deepracer-community.list /etc/apt/sources.list.d/
sudo apt-get update

sudo apt-get install aws-deepracer-core

# Restart deepracer
sudo systemctl start deepracer-core
