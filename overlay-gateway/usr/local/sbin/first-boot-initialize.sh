#!/bin/sh

echo 1 | tee /sys/class/leds/pwr-led/brightness
echo 0 | tee /sys/class/leds/act-led/brightness
echo 1 | tee /sys/class/leds/act-led/brightness
echo 1 | tee /sys/class/leds/rsv-led/brightness

while [ "$(systemctl is-enabled resize-helper)" != "disabled" ]; do
    sleep 2s
done

systemctl disable --now vncserver

systemctl disable --now emblaze-gateway.service

systemctl disable bluetooth.service
systemctl enable bluetooth-mesh.service

systemctl enable rabbitmq.service

systemctl disable --now ovpn.service

echo "emblaze:emblaze" | chpasswd

while [ "$(systemctl is-failed rockchip.service)" != "inactive" ]; do
    if [ "$(systemctl is-failed rockchip.service)" = "failed" ]; then
        dpkg --configure -a
        systemctl restart rockchip.service
    fi
done

sleep 30s

touch /var/emblaze-usb.hash

systemctl disable first-boot-initialization.service

sync

sleep 5s

reboot
