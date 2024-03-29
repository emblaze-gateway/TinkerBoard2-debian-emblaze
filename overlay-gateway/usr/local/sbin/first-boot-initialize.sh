#!/bin/sh

echo 1 | tee /sys/class/leds/pwr-led/brightness
echo 0 | tee /sys/class/leds/act-led/brightness
echo 1 | tee /sys/class/leds/act-led/brightness
echo 1 | tee /sys/class/leds/rsv-led/brightness

sleep 40s

systemctl disable --now vncserver

systemctl disable --now emblaze-gateway.service

systemctl disable bluetooth.service
systemctl enable bluetooth-mesh.service

systemctl enable rabbitmq.service

systemctl disable --now ovpn.service

echo "emblaze:emblaze" | chpasswd

sleep 30s

while [ $(systemctl is-failed rockchip.service) != "inactive" ]; do
    if [ $(systemctl is-failed rockchip.service) == "failed" ]; then
        dpkg --configure -a
        systemctl restart rockchip.service
    fi
done


touch /var/emblaze-usb.hash
/usr/local/sbin/force-timesync.sh

sync

sleep 5s

reboot
