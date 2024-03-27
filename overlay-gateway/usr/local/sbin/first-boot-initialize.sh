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

dpkg --configure -a
sleep 5s
systemctl restart rockchip.service
sleep 5s
systemctl reset-failed
sleep 5s

echo "emblaze:emblaze" | chpasswd

sleep 10s

/usr/local/sbin/force-timesync.sh

sync

reboot
