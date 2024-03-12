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

SHARE_DIR=/usr/local/share/

# Python
cd "overlay-library${SHARE_DIR}Python"
if [ ! -e Makefile ]; then
	./configure --enable-optimizations
	make -j4
fi
cd -

# json-c
cd "overlay-library${SHARE_DIR}json-c"
if [ ! -e Makefile ]; then
	./configure --prefix=/usr --disable-static
	make -j4
fi
cd -

# bluez
cd "overlay-library${SHARE_DIR}bluez"
if [ ! -e Makefile ]; then
	./bootstrap
	./configure --enable-mesh --disable-tools --prefix=/usr --mandir=/usr/share/man  --sysconfdir=/etc --localstatedir=/var
	make -j4
fi
cd -

# overlay-library folder
for module in Python json-c bluez; do
	if [ -e "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}" ]; then
        sudo rm -rf "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}"
	fi
    sudo cp -rf "overlay-library${SHARE_DIR}${module}" "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}"
done


# Python, json-c, ell, bluez library
# for module in Python json-c ell bluez; do
#	 if [ -e "modules/${module}" ]; then
#		 sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/${module}
#		 sudo mkdir $TARGET_ROOTFS_DIR/usr/local/share/${module}
#		 sudo cp -rf modules/${module}/* $TARGET_ROOTFS_DIR/usr/local/share/${module}
#	 else
#		 echo -e "\033[36m No has ${module} module. \033[0m"
#		 exit -1
#	 fi
# done

sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev
trap finish ERR

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR
while true; do
apt-get update
#######################################################
# ---------- Fill out additional commands ----------- #

#-------------gateway---------------
cd /
# Install build packages
apt install -y build-essential libbz2-dev libdb-dev libreadline-dev libffi-dev libgdbm-dev liblzma-dev libncursesw5-dev \
libsqlite3-dev libssl-dev zlib1g-dev uuid-dev tk-dev || break
apt install -y libudev1 udev || break
apt install -y git make gcc wget bc libusb-dev libdbus-1-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev \
autoconf bison flex libssl-dev libtool automake || break

# Install Python
cd /usr/local/share/Python
make install
cd /
rm -r /usr/local/share/Python


# Install json-c
cd /usr/local/share/json-c
make install
cd /
rm -rf /usr/local/share/json-c

# Install BlueZ
cd /usr/local/share/bluez
make install
cd /
rm -rf /usr/local/share/bluez

#######################################################
echo $VERSION_NUMBER-$VERSION >> /etc/version
echo "Finished"
break
done

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
