#!/bin/bash
# Start the Reticulum stack: freedvtnc2 (modem) -> rnsd (network daemon) -> meshchat (UI)
# Order matters: meshchat crashes-loops without rnsd, and rnsd warns without
# freedvtnc2 in many configs.

pkill js8call 2>/dev/null
pkill fldigi 2>/dev/null
pkill wsjtx 2>/dev/null
pkill pavucontrol 2>/dev/null

sleep 1

sudo systemctl start freedvtnc2 || exit 1
sudo systemctl start rnsd || exit 1
sudo systemctl start reticulum-meshchat || exit 1

exit 0
