#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ ! -e $TARGET_ROOTFS_DIR ]; then
	echo -e "\033[36m Run mk-rootfs-buster.sh first \033[0m"
	exit -1
fi

finish() {
	sudo umount $TARGET_ROOTFS_DIR/dev
	exit -1
}

# overlay-gateway folder
sudo cp -rf overlay-gateway/* $TARGET_ROOTFS_DIR/

# bluemesh / gateway folder
if [ -e "modules/bluemesh" ]; then
    sudo rm -rf $TARGET_ROOTFS_DIR/bluemesh
    sudo mkdir $TARGET_ROOTFS_DIR/bluemesh
    sudo cp -rf modules/bluemesh/* $TARGET_ROOTFS_DIR/bluemesh
else
	echo -e "\033[36m No has bluemesh module. \033[0m"
    exit -1
fi

if [ -e "modules/gateway" ]; then
    sudo rm -rf $TARGET_ROOTFS_DIR/gateway
    sudo mkdir $TARGET_ROOTFS_DIR/gateway
    sudo cp -rf modules/gateway/* $TARGET_ROOTFS_DIR/gateway
else
	echo -e "\033[36m No has gateway module. \033[0m"
    exit -1
fi

if [ -e "modules/led-control" ]; then
    sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/led-control
    sudo mkdir $TARGET_ROOTFS_DIR/usr/local/share/led-control
    sudo cp -rf modules/led-control/* $TARGET_ROOTFS_DIR/usr/local/share/led-control
else
	echo -e "\033[36m No has led-control module. \033[0m"
    exit -1
fi

sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev
trap finish ERR

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR
while true; do
apt-get update
#######################################################
# Fill out additional commands
#######################################################


#-------------gateway---------------
cd /
# Install build packages
apt install -y build-essential libbz2-dev libdb-dev libreadline-dev libffi-dev libgdbm-dev liblzma-dev libncursesw5-dev \
libsqlite3-dev libssl-dev zlib1g-dev uuid-dev tk-dev || break
apt install -y libudev1 udev || break
apt install -y git make gcc wget bc libusb-dev libdbus-1-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev \
autoconf bison flex libssl-dev libtool automake || break

# Install DBus, Bluemesh, Gateway Application
apt install -y python3-systemd libsystemd-dev || break

python3 -m venv /venv
source /venv/bin/activate
chgrp -R gateway /venv
chmod -R g+w /venv

pip3 install wheel==0.37.1
pip3 install pycairo==1.25.1
pip3 install PyGObject==3.44.1

cd /bluemesh
pip3 install .[all]
chgrp -R gateway .
chmod -R g+w .
cd /

cd /gateway
pip3 install .[all]
chgrp -R gateway .
chmod -R g+w .
cd /

deactivate

# Setting USB Plug-in-play
cd /usr/local/sbin
chmod ug+x emblaze-usb-autorun.sh
chmod -R ug+x emblaze-usb-autorun
cd /

# First Boot Process
cd /usr/local/sbin
chmod ug+x first-boot-initialize.sh
cd /

# Rabbitmq runner
cd /usr/local/sbin
chmod ug+x rabbitmq.sh
cd /

# force severals after boot
cd /usr/local/sbin
chmod ug+x force-timesync.sh
chmod ug+x force-emblaze-usb.sh
cd /

# LED Controller
cd /usr/local/share/led-control
cmake .
make
make install
cd /
rm -rf /usr/local/share/led-control

#######################################################
echo $VERSION_NUMBER-$VERSION > /etc/version
echo "Finished"
break
done

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
