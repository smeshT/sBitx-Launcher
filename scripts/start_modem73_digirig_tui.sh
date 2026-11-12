#!/bin/bash
# start_modem73_digirig_tui.sh — open lxterminal running upstream modem73 v2.4.2
# in TUI mode on the sbitx shared desktop (:20), using the digirig config.

set -e

export DISPLAY=:20
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Ensure CM119 AGC is enabled before modem73 opens the device
amixer -c 5 set "Auto Gain Control" on 2>/dev/null || true

# Idempotency check
for p in $(pgrep -x lxterminal 2>/dev/null); do
    if cat /proc/$p/cmdline 2>/dev/null | tr "\0" " " | grep -q "--title=modem73-digirig"; then
        wmctrl -a "modem73-digirig" 2>/dev/null || true
        exit 0
    fi
done

lxterminal --title="modem73-digirig" \
    -e bash -c "echo \"=== modem73 Digirig TUI starting ===\"; \
                 exec /usr/local/bin/modem73-digirig --config /home/pi/.config/modem73-digirig/settings --port 8003 --control-port 8074" \
    >/dev/null 2>&1 &

exit 0
