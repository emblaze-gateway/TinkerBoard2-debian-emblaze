#!/bin/bash

FILE_NAME="wifi.txt"

log()
{
        logger -t "emblaze-usb" "$@"
}

wifi_enable()
{
        log "info: wifi on"
        nmcli radio wifi on
        sleep 5s
}

wifi_disable()
{
        log "info: wifi off"
        nmcli radio wifi off
        sleep 5s
}

event_handler()
{
        log "info: setting wifi"

        if [ ! -e "$1/$FILE_NAME" ]; then
                log "error: Not found $FILE_NAME"
                return 1
        fi

        wifi_config=$("$EMBLAZE_USB_DIRPATH/read_lines.sh" "$1/$FILE_NAME")
        wifi_enabled="$(echo $(echo $wifi_config | cut -d '\' -f1))d"
        if [ "$(nmcli r wifi)" != "$wifi_enabled" ]; then
                if [ "$wifi_enabled" == "disabled" ]; then
                        wifi_disable
                elif [ "$wifi_enabled" == "enabled" ]; then
                        wifi_enable
                else
                        log "error: Wrong written $1/$FILE_NAME"
                        return 1
                fi
        fi

        if [ "$(nmcli r wifi)" != "enabled" ]; then
            log "info: wifi NOT enabled"
            return 0
        fi

        detected_wifi_names=$(nmcli dev wifi)
        wifi_name="$(echo $(echo $wifi_config | cut -d '\' -f2))"
        wifi_password="$(echo $(echo $wifi_config | cut -d '\' -f3))"
        if [ ! -z "${wifi_name}" ]; then
            is_wifi_exist=$(if echo "${detected_wifi_names}" | grep -q "${wifi_name}"; then echo "yes"; else echo "no"; fi)
            if [ "${is_wifi_exist}" = "yes" ]; then
                    if [ -z "${wifi_password}" ]; then
                            log "info: $(nmcli dev wifi connect ${wifi_name})"
                            # TODO: Error handling
                    else
                            log "info: $(nmcli dev wifi connect ${wifi_name} password ${wifi_password})"
                            # TODO: Error Handling
                    fi
            else
                    log "warning: NOT detected signal by ${wifi_name}"
            fi
        fi
        return 0
}

event_handler $1
