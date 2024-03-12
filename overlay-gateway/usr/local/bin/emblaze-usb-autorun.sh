#!/bin/bash
EVT_FILE=/tmp/emblaze-usb.evt

touch $EVT_FILE 2> /dev/null

export EMBLAZE_USB_DIRPATH="$(dirname $0)/emblaze-usb-autorun"

get_mount_point()
{
        sleep 1
        mounted=$(mount | grep "$1" | cut -d " " -f3)
        echo $mounted
}

mount_emblaze_usb()
{
        ssid=$1
        if [ ! -z "$(get_mount_point /mnt/neostack-$ssid)" ]; then
                echo "EMBLAZE-USB: umount unmounted /mnt/neostack-$ssid"
                umount "/mnt/neostack-$ssid"
        fi
        if [ ! -d "/mnt/neostack-$ssid" ]; then
                mkdir -p "/mnt/neostack-$ssid" 2> /dev/null
        fi
        echo "EMBLAZE-USB: mount /mnt/neostack-$ssid"
        mount -U $ssid "/mnt/neostack-$ssid"

}

unmount_emblaze_usb()
{
        ssid=$1
        echo "EMBLAZE-USB: umount /mnt/neostack-$ssid"
        umount "/mnt/neostack-$ssid"
        rmdir "/mnt/neostack-$ssid"
}

FILE_NAME="run.txt"

run_command()
{
        mounted=$1
        commands=$2

        # Changing the order below commands NOT allowed

        # wifi setting
        if [ $(( $commands & 1 )) -gt 0 ]; then
                "$EMBLAZE_USB_DIRPATH/auto_wifi.sh" $mounted
        fi

        # emblaze-gateway config setting
        if [ $(( $commands & 4 )) -gt 0 ]; then
                mkdir -p "/etc/emblaze"
                cp -f "$mounted/config.ini" "/etc/emblaze/gateway_config.ini"
                echo "EMBLAZE-USB: Set emblaze-gateway configuration"
                systemctl restart emblaze-gateway.service
        fi

        # ovpn setting
        if [ $(( $commands & 8 )) -gt 0 ]; then
                mkdir -p "/etc/emblaze"
                cp -f "$mounted/ovpn.conf" "/etc/emblaze/openvpn.conf"
                echo "EMBLAZE-USB: Set ovpn configuration"
                systemctl enable ovpn.service
                systemctl restart ovpn.service
        fi

        # run command
        if [ $(( $commands & 2 )) -gt 0 ]; then
                "$EMBLAZE_USB_DIRPATH/cmd.sh" $mounted
        fi
}

event_handler()
{
        dev=$(cat $EVT_FILE | cut -d " " -f1)
        ssid=$(cat $EVT_FILE | cut -d " " -f2)
        echo "EMBLAZE-USB: Connected Emblaze-USB: $dev" > /dev/kmsg
        echo "EMBLAZE-USB: Connected Emblaze-USB: $dev"
        mounted="$(get_mount_point $dev)"
        if [ -z "$mounted" ]; then
                mount_emblaze_usb $ssid
                mounted="$(get_mount_point $dev)"
        fi
        commands=0
        if [ ! -z "$mounted" ]; then
                if [ ! -e "$mounted/$FILE_NAME" ]; then
                        echo "EMBLAZE-USB: Not found $FILE_NAME"
                else
                        config_list=$("$EMBLAZE_USB_DIRPATH/read_lines.sh" "$mounted/$FILE_NAME")
                        i=1
                        while true; do
                                line="$(echo $(echo $config_list | cut -d '\' -f $i))"
                                if [ -z "$line" ]; then
                                        break
                                fi
                                case "$line" in
                                        "wifi")
                                                commands=$(( $commands + $(( 1 - ($commands & 1) )) ))
                                                ;;
                                        "cmd")
                                                commands=$(( $commands + $(( 2 - ($commands & 2) )) ))
                                                ;;
                                        "config")
                                                commands=$(( $commands + $(( 4 - ($commands & 4) )) ))
                                                ;;
                                        "ovpn")
                                                commands=$(( $commands + $(( 8 - ($commands & 8) )) ))
                                                ;;
                                        *)
                                                echo "EMBLAZE-USB: Unknown Config: $line"
                                                ;;
                                esac
                                i="$(expr $i + 1)"
                        done
                        run_command $mounted $commands
                fi
                unmount_emblaze_usb $ssid       # finished
        fi
        echo "EMBLAZE-USB: Finished Emblaze-USB autorun: $dev" > /dev/kmsg
        echo "EMBLAZE-USB: Finished Emblaze-USB autorun: $dev"
}

sleep 20s &     # Delay Bootup
wait $!


cleanup() {
        systemd-notify STOPPING=1
        exit 0
}


if [ -z $WATCHDOG_PID ] || [ -z $WATCHDOG_USEC ] || [ -z $NOTIFY_SOCKET ]; then
        # NOT to use systemd watchdog
        while inotifywait -q -e modify $EVT_FILE; do
                event_handler
        done
else
        # Use systemd watchdog
        systemd-notify --status="Starting Emblaze-USB..."
        systemd-notify READY=1

        trap "cleanup" SIGTERM
        trap "cleanup" SIGABRT

        while true; do
                systemd-notify WATCHDOG=1
                systemd-notify --status="Waiting to insert Emblaze-USB"
                while inotifywait -q -t 60 -e modify $EVT_FILE; do
                        systemd-notify --status="Running auto-run"
                        event_handler
                done
        done
fi
