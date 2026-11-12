#!/bin/bash
set -e

# Don't let reset-failed's non-zero exit (missing service) abort the script
sudo systemctl reset-failed freedvtnc2.service rnsd.service \
    meshchatx.service lxmd.service 2>/dev/null || true

sudo systemctl stop meshchatx.service lxmd.service 2>/dev/null || true

# pkill catches meshchatx instances that forked outside systemd's control
pkill -f meshchatx || true
pkill -f lxmd || true

sudo systemctl restart rnsd.service
until sudo systemctl is-active --quiet rnsd.service; do sleep 0.2; done

sleep 2
sudo systemctl start meshchatx.service
sleep 1
sudo systemctl start lxmd.service

echo "OK"
