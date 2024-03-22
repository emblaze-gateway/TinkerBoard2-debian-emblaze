#!/bin/bash

FILE_NAME="cmd.txt"

log()
{
        logger -t "emblaze-usb" "$@"
}

cmds()
{
        arg="$1"
        case $arg in
                "echo")
                        text="$@"
                        echo "EMBLAZE-USB: echo $text"
                        log "echo: $text"
                        ;;
                "reboot")
                        log "reboot"
                        sleep 3
                        sync
                        reboot
                        return 0
                        ;;
                "shutdown")
                        log "shutdown"
                        sleep 3
                        sync
                        shutdown now
                        return 0
                        ;;
                "enable")
                        shift 1
                        arg="$1"
                        log "info: enable $arg"
                        case $arg in
                                "ovpn")
                                        systemctl enable ovpn.service
                                        systemctl restart ovpn.service
                                        ;;
                                *)
                                        log "warning: Unknown enable service: $arg"
                                        ;;
                        esac
                        ;;
                "disable")
                        shift 1
                        arg="$1"
                        log "info: disable $arg"
                        case $arg in
                                "ovpn")
                                        systemctl stop ovpn.service
                                        systemctl disable ovpn.service
                                        ;;
                                *)
                                        log "warning: Unknown disable service: $arg"
                                        ;;
                        esac
                        ;;
                "restart")
                        shift 1
                        arg="$1"
                        log "info: restart $arg"
                        case $arg in
                                "gateway")
                                        systemctl restart emblaze-gateway.service
                                        ;;
                                "ovpn")
                                        systemctl restart ovpn.service
                                        ;;
                                "all")
                                        systemctl stop emblaze-gateway.service
                                        sleep 1s
                                        systemctl stop rabbitmq.service
                                        sleep 1s
                                        systemctl stop bluetooth-mesh.service
                                        sleep 1s
                                        systemctl stop ovpn.service
                                        sleep 1s
                                        systemctl start ovpn.service
                                        sleep 1s
                                        systemctl start bluetooth-mesh.service
                                        sleep 1s
                                        systemctl start rabbitmq.service
                                        sleep 1s
                                        systemctl start emblaze-gateway.service
                                        ;;
                                *)
                                        log "warning: Unknown restart service: $arg"
                                        ;;
                        esac
                        ;;
                # "apt")
                #         shift 1
                #         arg="$1"
                #         case $arg in
                #                 "update")
                #                         apt update
                #                         ;;
                #                 "install")
                #                         shift 1
                #                         apt install -y $@
                #                         apt install -f -y
                #                         ;;
                #         esac
                #         ;;
                "sleep")
                        shift 1
                        arg="$1"
                        log "sleep: $arg"
                        sleep "$arg"
                        ;;
                *)
                        log "warning: Unknown cmd: $arg"
                        ;;
        esac
}

event_handler()
{
        log "info: commands"

        if [ ! -e "$1/$FILE_NAME" ]; then
                log "warning: Not found $FILE_NAME"
                return 1
        fi

        cmd_list=$("$EMBLAZE_USB_DIRPATH/read_lines.sh" "$1/$FILE_NAME")

        i=1
        while true; do
                line="$(echo $(echo $cmd_list | cut -d '\' -f$i))"
                if [ -z "$line" ]; then
                        break
                fi
                cmds $line
                i="$(expr $i + 1)"
        done
}

event_handler $1
