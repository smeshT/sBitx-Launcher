#!/bin/bash
# Read whether [[freedvtnc2 Interface]] is enabled in ~/.reticulum/config.
# Output: "true" | "false" | "missing"
# Used by my_launcher/app.py to drive the status pill.

CONFIG="/home/pi/.reticulum/config"
PARSER="/home/pi/my_launcher/scripts/parse_freedv_block.awk"

if [ ! -f "$CONFIG" ]; then
    echo "missing"
    exit 0
fi

state=$(awk -f "$PARSER" "$CONFIG" 2>/dev/null)
case "$state" in
    true|false) echo "$state" ;;
    "") echo "missing" ;;
    *) echo "$state" ;;
esac
