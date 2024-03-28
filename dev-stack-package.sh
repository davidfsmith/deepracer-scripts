#!/usr/bin/env bash
set -e

export DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

PACKAGES="aws-deepracer-core"

while getopts "p:v:" opt; do
  case $opt in
  p)
    PACKAGES=$OPTARG
    ;;
  v)
    VERSION=$OPTARG
    ;;
  \?)
    echo "Invalid option -$OPTARG" >&2
    usage
    ;;
  esac
done

if [ -z "$PACKAGES" ]; then
       echo "No packages provided. Exiting."
       exit 1
fi

if [ -z "$VERSION" ]; then
       echo "No version provided. Exiting."
       exit 1
fi

# DeepRacer Repos
sudo cp $DIR/files/deepracer.asc /etc/apt/trusted.gpg.d/
sudo cp $DIR/files/aws_deepracer.list /etc/apt/sources.list.d/
sudo apt-get update

rm -rf $DIR/pkg-build/aws* 
mkdir -p $DIR/pkg-build $DIR/pkg-build/src $DIR/dist
cd $DIR/pkg-build
mkdir -p $PACKAGES

# Check which packages we have
cd $DIR/pkg-build/src
for pkg in $PACKAGES;
do
       if [ "$(compgen -G $pkg*.deb | wc -l )" -eq 0 ];
       then
              PACKAGES_DOWNLOAD="$PACKAGES_DOWNLOAD $pkg:amd64"
       fi
done

# Download missing AMD64 packages
if [ -n "$PACKAGES_DOWNLOAD" ];
then
       sudo apt-get update

       echo -e '\n### Downloading original packages ###\n'
       echo "Missing packages: $PACKAGES_DOWNLOAD"
       apt download $PACKAGES_DOWNLOAD
fi

# Build required packages
cd $DIR/pkg-build
for pkg in $PACKAGES; 
do
       if [ "$pkg" == "aws-deepracer-core" ];
       then
              echo -e "\n### Building aws-deepracer-core $VERSION ###\n"
              dpkg-deb -R src/aws-deepracer-core_*amd64.deb aws-deepracer-core
              cd aws-deepracer-core
              sed -i "s/Version: .*/Version: $VERSION/" DEBIAN/control
              sed -i '/Depends/ s/$/, gnupg, ros-foxy-ros-base, ros-foxy-std-msgs, ros-foxy-sensor-msgs, ros-foxy-image-transport, ros-foxy-compressed-image-transport, ros-foxy-cv-bridge/' DEBIAN/control
              rm -rf opt/aws/deepracer/lib/*
              cp $DIR/files/start_ros.sh opt/aws/deepracer
              cp -r $DIR/ws/install/* opt/aws/deepracer/lib/
              rm DEBIAN/preinst
              cd ..
              dpkg-deb --root-owner-group -b aws-deepracer-core
              dpkg-name -o aws-deepracer-core.deb 
              FILE=$(compgen -G aws-deepracer-core*.deb)
              mv $FILE $(echo $DIR/dist/$FILE | sed -e 's/\+/\-/')
       fi
done