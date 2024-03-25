#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ -e $TARGET_ROOTFS_DIR ]; then
	sudo rm -rf $TARGET_ROOTFS_DIR
fi

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36m please input is: armhf or arm64...... \033[0m"
fi

if [ ! $VERSION ]; then
	VERSION="debug"
fi

if [ ! -e linaro-buster-alip-$ARCH.tar.gz ]; then
	echo -e "\033[36m Run mk-base-debian.sh first \033[0m"
	exit -1
fi

finish() {
	sudo umount $TARGET_ROOTFS_DIR/dev
	exit -1
}
trap finish ERR

echo -e "\033[36m Extract image \033[0m"
sudo tar -xpf linaro-buster-alip-$ARCH.tar.gz

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# overlay folder
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/

# overlay-firmware folder
sudo cp -rf overlay-firmware/* $TARGET_ROOTFS_DIR/

# overlay-debug folder
# adb, video, camera  test file
if [ "$VERSION" == "debug" ] || [ "$VERSION" == "jenkins" ]; then
	sudo cp -rf overlay-debug/* $TARGET_ROOTFS_DIR/
fi

## hack the serial
sudo cp -f overlay/usr/lib/systemd/system/serial-getty@.service $TARGET_ROOTFS_DIR/lib/systemd/system/serial-getty@.service

# adb
if [ "$ARCH" == "armhf" ] && [ "$VERSION" == "debug" ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-32 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-64 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
fi

# bt/wifi firmware
if [ "$ARCH" == "armhf" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_32 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_32 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
elif [ "$ARCH" == "arm64" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi
sudo mkdir -p $TARGET_ROOTFS_DIR/system/lib/modules/
#sudo find ../kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | \
#    xargs -n1 -i sudo cp {} $TARGET_ROOTFS_DIR/system/lib/modules/
# ASUS: Change to copy all the kernel modules built from build.sh.
sudo cp -rf ../debian_new/lib_modules/lib/modules $TARGET_ROOTFS_DIR/lib/

# adb
if [ "$ARCH" == "armhf" ] && [ "$VERSION" == "debug" ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-32 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp -rf overlay-debug/usr/local/share/adb/adbd-64 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
fi

# gpio library
sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/gpio_lib_c_rk3399
sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/gpio_lib_python_rk3399
sudo cp -rf overlay-debug/usr/local/share/gpio_lib_c_rk3399 $TARGET_ROOTFS_DIR/usr/local/share/gpio_lib_c_rk3399
sudo cp -rf overlay-debug/usr/local/share/gpio_lib_python_rk3399 $TARGET_ROOTFS_DIR/usr/local/share/gpio_lib_python_rk3399

# mraa library
sudo rm -rf $TARGET_ROOTFS_DIR/usr/local/share/mraa
sudo cp -rf overlay-debug/usr/local/share/mraa $TARGET_ROOTFS_DIR/usr/local/share/mraa

echo -e "\033[36m Change root.....................\033[0m"
if [ "$ARCH" == "armhf" ]; then
	sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi
sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR

while true; do
apt-get update

chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
chmod +x /etc/rc.local

export APT_INSTALL="apt-get install -fy --allow-downgrades"

#---------------power management --------------
\${APT_INSTALL} busybox pm-utils triggerhappy || break
cp /etc/Powermanager/triggerhappy.service  /lib/systemd/system/triggerhappy.service

#---------------system--------------
apt-get install -y git fakeroot devscripts cmake binfmt-support dh-make dh-exec pkg-kde-tools device-tree-compiler \
bc cpio parted dosfstools mtools libssl-dev dpkg-dev isc-dhcp-client-ddns || break
apt-get install -f -y

#---------------tinker-power-management--------------
cd /usr/local/share/tinker-power-management
gcc tinker-power-management.c -o tinker-power-management -lncursesw
mv tinker-power-management /usr/bin
cd /

# mark package to hold
apt list --installed | grep -v oldstable | cut -d/ -f1 | xargs apt-mark hold

#---------------Custom Script--------------
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

#---------------gpio library --------------
# For gpio wiring c library
chmod a+x /usr/local/share/gpio_lib_c_rk3399
cd /usr/local/share/gpio_lib_c_rk3399
./build
# For gpio python library
cd /usr/local/share/gpio_lib_python_rk3399/
python setup.py install
python3 setup.py install
cd /

#---------------mraa library --------------
apt-get install -y swig3.0 || break
chmod a+x /usr/local/share/mraa
cd /usr/local/share/mraa
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr --BUILDARCH=aarch64 ..
make
make install
cd /

#---------------40 pin permission for user --------------

for groupname in gpiouser i2cuser spidevuser uartuser pwmuser; do
    groupadd \$groupname
    adduser emblaze \$groupname
    adduser linaro \$groupname
done

#-------------Others--------------
cp /etc/Powermanager/systemd-suspend.service  /lib/systemd/system/systemd-suspend.service

# Switching iptables/ip6tables to the legacy version
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

echo $VERSION_NUMBER-$VERSION > /etc/version
echo "ASUS TinkerBoard2" > /etc/boardname

#---------------Clean--------------
rm -rf /var/lib/apt/lists/*

echo "Finished"

break
done

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
