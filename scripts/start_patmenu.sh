#!/bin/bash
# start_patmenu.sh — start the patmenu2 yad menu on DISPLAY=:20.
#
# The yad menu itself contains the "Start/Stop Modem" button which
# launches piardopc + piARDOP_GUI. We only need to put the yad menu
# on the desktop; the user clicks the modem button when they want
# the modem up.
#
# Idempotent: if a patmenu yad is already running, we don't start
# a second one. (Two overlapping yad menus is more confusing than
# useful — the user closes the first one to interact with the second.)
#
# Created 2026-07-04 to add the "Pat Menu" row to my_launcher.

# Start the shared desktop (Xvfb :20 + openbox + x11vnc + noVNC).
# start_desktop.sh is a no-op if it's already up.
/home/pi/my_launcher/scripts/start_desktop.sh

# Audio: piardopc opens plughw:1,1 / plughw:2,0 (per patmenu2/config).
# If something else has those devices, the user must stop it first
# (e.g. start-js8call does `sudo systemctl stop freedvtnc2 && sudo
# systemctl stop rnsd` to free the audio path). patmenu's own
# "Start Modem" path runs a similar check via pidof. We don't preempt
# here — the yad menu itself is fine to run with the audio held by
# another app; it only fails when the user actually tries to start
# the modem.

export DISPLAY=:20
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Idempotency: if a yad process whose command line mentions
# "Pat Menu" is already alive, just focus the existing window
# (best-effort) and exit.
if pgrep -f 'yad.*Pat Menu' >/dev/null 2>&1; then
    exit 0
fi

# Run the menu in the background so the launcher's HTTP request
# returns immediately. The menu blocks (it yad-waits for a button
# click) so wrapping with & plus redirecting stdio is essential.
nohup /home/pi/patmenu2/./patmenu \
    >/tmp/my_launcher_patmenu.log 2>&1 &

exit 0
