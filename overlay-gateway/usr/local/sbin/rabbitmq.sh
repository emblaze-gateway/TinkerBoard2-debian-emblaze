#!/bin/sh

systemd-notify --status="Starting"

docker image pull rabbitmq:3.11-management

systemd-notify --ready --status="Running"

docker run -t --rm --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.11-management

systemd-notify --stopping
