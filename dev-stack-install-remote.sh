#!/usr/bin/env bash

# Package and copy file
echo "Tar files"
tar cvzf bundle.tgz ./ws/install
scp bundle.tgz $1:~/
rm bundle.tgz

# Extract contents 
echo "Extract on remote"
ssh $1 "tar xvzf bundle.tgz"

# Run installation
echo "Run installation"
ssh $1 < dev-stack-install.sh
