#!/bin/bash

log()
{
        logger -t "emblaze-usb" "$@"
}

# Skip 'emblaze-usb-autorun' when it is first boot
# Please note that '/etc/systemd/system/first-boot-initialization.service'
if [ $(systemctl is-active first-boot-initialization.service) == "active"]; then
        log "Not yet complete first boot."
        exit 0
fi

DEVICE="/dev/emblaze-usb"
MOUNT_POINT="/emblaze-usb-mount-point"

HASHSUM_FILE="/tmp/emblaze-usb.hash"
if [ ! -f "$HASHSUM_FILE" ]; then
        touch $HASHSUM_FILE
fi
HASHSUM=$(cat $HASHSUM_FILE)

RUN_COMMANDS="run.txt"


mkdir -p $MOUNT_POINT
export EMBLAZE_USB_DIRPATH="$(dirname $0)/emblaze-usb-autorun"

get_mount_point()
{
        sleep 1
        mounted=$(findmnt -n -M $MOUNT_POINT)
        echo $mounted
}

mount_emblaze_usb()
{
        if [ ! -z "$(get_mount_point)" ]; then
                log "error: Already mounted $MOUNT_POINT. Please check first."
                echo 0
        else
                mount $DEVICE $MOUNT_POINT
                if [ ! -z "$(get_mount_point)" ]; then
                        log "info: Success mount $DEVICE to $MOUNT_POINT."
                        echo 1
                else
                        log "error: Failed mount $DEVICE."
                        echo 0
                fi
        fi

}

unmount_emblaze_usb()
{
        if [ -z "$(get_mount_point)" ]; then
                log  "erro: Already unmounted $MOUNT_POINT. Please check first."
                echo 0
        else
                umount $MOUNT_POINT
                if [ -z "$(get_mount_point)" ]; then
                        log "info: Success unmount $MOUNT_POINT."
                        echo 1
                else
                        log "error: Failed unmount $MOUNT_POINT."
                        echo 0
                fi
        fi
}

run_command()
{
        mounted=$1
        commands=$2

        # Changing the order below commands NOT allowed while you do not want behavior to change.
        # # TODO: It skips for the moment because status keeps 'starting' when
        # # waiting systemd-time-wait-sync due to disconnected network.
        while [ $(systemctl is-system-running) != "running"]; do
                log "Waiting running"
                sleep 2s
        done

        # wifi setting
        if [ $(( $commands & 1 )) -gt 0 ]; then
                while [ $(systemctl is-active NetworkManager.service) != "active"]; do
                        log "Waiting NetworkManager"
                        sleep 2s
                done
                "$EMBLAZE_USB_DIRPATH/auto_wifi.sh" $mounted
                if [ "$?" -eq 0 ]; then
                    systemctl enable --now systemd-time-wait-sync.service
                fi
        fi

        # emblaze-gateway config setting
        if [ $(( $commands & 4 )) -gt 0 ]; then
                mkdir -p "/etc/emblaze"
                cp -f "$mounted/config.ini" "/etc/emblaze/gateway_config.ini"
                log "info: Set emblaze-gateway configuration"
                systemctl restart emblaze-gateway.service
        fi

        # ovpn setting
        if [ $(( $commands & 8 )) -gt 0 ]; then
                mkdir -p "/etc/emblaze"
                cp -f "$mounted/ovpn.conf" "/etc/emblaze/openvpn.conf"
                log "info: Set ovpn configuration"
                systemctl enable ovpn.service
                systemctl restart ovpn.service
        fi

        # run command
        if [ $(( $commands & 2 )) -gt 0 ]; then
                "$EMBLAZE_USB_DIRPATH/cmd.sh" $mounted
        fi
}

parse_commands()
{
        config_list=$("$EMBLAZE_USB_DIRPATH/read_lines.sh" "$MOUNT_POINT/$RUN_COMMANDS")
        commands=0
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
                                log "warning: Unknown Config: $line"
                                ;;
                esac
                i="$(expr $i + 1)"
        done
        echo $commands
}

event_handler()
{
        log "info: Connected Emblaze-USB: $DEVICE"
        mounted=$(mount_emblaze_usb)
        if [ "$mounted" -eq 1 ]; then
                curr_hashsum=$(find $MOUNT_POINT -type f -exec sha1sum {} \; | xargs echo)
                if [ "$HASHSUM" == "$curr_hashsum" ]; then
                        log "info: Already done previously on same hashsum USB."
                else
                        if [ ! -e "$MOUNT_POINT/$RUN_COMMANDS" ]; then
                                echo "error: Not found $RUN_COMMANDS"
                        else
                                commands=$(parse_commands)
                                log "info: Received commands - $commands"
                                run_command $MOUNT_POINT $commands
                        fi
                fi
                unmounted=$(unmount_emblaze_usb)                # finished
                if [ "$unmounted" -eq 1 ]; then
                        echo ${curr_hashsum} > ${HASHSUM_FILE}
                fi
        fi
        log "info: Finished Emblaze-USB autorun: $DEVICE"
}


cleanup() {
        log "warning: Get abnormal signal."
        unmount_emblaze_usb
        exit 0
}

trap "cleanup" SIGTERM
trap "cleanup" SIGABRT

event_handler
