#!/bin/bash
# Read whether [[Modem73]] is enabled in ~/.reticulum/config.
# Output: "true" | "false" | "missing"
# Used by my_launcher/app.py to drive the status pill.
#
# Pattern source: check_freedv_in_reticulum.sh.

CONFIG="/home/pi/.reticulum/config"
PARSER="/home/pi/my_launcher/scripts/parse_modem73_block.awk"

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
