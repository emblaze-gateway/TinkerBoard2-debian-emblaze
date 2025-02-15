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

# overlay-library folder
SHARE_DIR=/usr/local/share/

for module in Python json-c ell bluez; do
	if [ ! -e "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}" ]; then
		sudo cp -rf "overlay-library${SHARE_DIR}${module}" "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}"
	fi
done

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

# Install json-c
cd /usr/local/share/json-c
autoreconf -f -i
./configure --prefix=/usr --disable-static || break
make || break
make install
cd /
rm -rf /usr/local/share/json-c

# Install Python
cd /usr/local/share/Python
./configure --enable-optimizations || break
make -j4 || break
make install
cd /
rm -r /usr/local/share/Python

# Install BlueZ
cd /usr/local/share/bluez
./bootstrap || break
./configure --enable-mesh --disable-tools --prefix=/usr --mandir=/usr/share/man  --sysconfdir=/etc --localstatedir=/var || break
make -j4 || break
make install
cd /
rm -rf /usr/local/share/ell
rm -rf /usr/local/share/bluez

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
DRY_RUN=1 sh ./get-docker.sh
sh get-docker.sh


#######################################################
echo $VERSION_NUMBER-$VERSION >> /etc/version
echo "Finished"
break
done

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
