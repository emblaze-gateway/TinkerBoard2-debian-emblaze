#!/bin/bash

sleep 40s

systemctl disable --now hostapd
systemctl disable --now dhcpcd

systemctl disable bluetooth.service
systemctl enable bluetooth-mesh.service

systemctl enable emblaze-usb.service
systemctl enable rabbitmq.service
systemctl enable emblaze-gateway.service

systemctl disable ovpn.service

nmcli radio wifi off

crontab -l > mycron
echo "0 4 * * * logrotate /etc/logrotate.conf" >> mycron
crontab mycron
rm mycron

sleep 40s

echo "emblaze:emblaze" | chpasswd

sleep 1s

sync

reboot
