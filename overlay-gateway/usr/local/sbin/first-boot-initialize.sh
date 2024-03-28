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


/usr/local/sbin/force-timesync.sh

# Waiting system running
while [ $(systemctl is-system-running) != "running" ]; do
        log "Waiting system running."
        sleep 3s
done

sync

reboot
