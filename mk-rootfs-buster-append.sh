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
# mkdir -p overlay-library${SHARE_DIR}
# if [ ! -e "overlay_library${SHARE_DIR}Python" ]; then
#     git clone https://github.com/python/cpython.git -b v3.11.7 --single-branch --depth 1 Python
# fi


for module in Python json-c ell bluez; do
	if [ ! -e "${TARGET_ROOTFS_DIR}${SHARE_DIR}${PYTHON_DIR}" ]; then
		sudo cp -rf "overlay-library${SHARE_DIR}${module}" "${TARGET_ROOTFS_DIR}${SHARE_DIR}${module}"
	fi
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
if [ ! -e Makefile ]; then
	./configure --enable-optimizations
	make -j4
fi
cp -r /usr/local/share/Python /Python
cd /Python
make install
cd /
rm -r /Python


# Install json-c
cd /usr/local/share/json-c
if [ ! -e Makefile ]; then
	./configure --prefix=/usr --disable-static
	make -j4
fi
cp -r /usr/local/share/json-c /json-c
cd /json-c
make install
cd /
rm -rf /json-c

# Install BlueZ
cd /usr/local/share/bluez
if [ ! -e Makefile ]; then
	./bootstrap
	./configure --enable-mesh --disable-tools --prefix=/usr --mandir=/usr/share/man  --sysconfdir=/etc --localstatedir=/var
	make -j4
fi
cp -r /usr/local/share/ell /ell
cp -r /usr/local/share/bluez /bluez
cd /bluez
make install
cd /
rm -rf /ell
rm -rf /bluez

#######################################################
echo $VERSION_NUMBER-$VERSION >> /etc/version
echo "Finished"
break
done

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
