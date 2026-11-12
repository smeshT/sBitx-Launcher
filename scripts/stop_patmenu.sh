#!/bin/bash
# stop_patmenu.sh — stop the patmenu2 yad menu.
#
# Pat menu's "Start/Stop Modem" button manages piardopc and
# piARDOP_GUI, so we only kill the yad menu here. The user
# stops the modem with the same button (or via the existing
# lxterminal in the noVNC tab).
#
# Hardened 2026-07-04: uses _lib_stop.sh like the other stop
# scripts (consistent with the 2026-06-23 launcher stop-script
# hardening).

LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"

fail=0

# The yad process whose command line includes the patmenu title.
# The full command line for patmenu2 includes the literal string
# "Pat Menu" (in --title=Pat Menu). pgrep -f matches against the
# full command line, so this is reliable.
stop_proc "yad.*--title=Pat Menu" || fail=1

# Belt-and-suspenders: if the user clicked "Start/Stop Modem" then
# quit the yad menu without stopping the modem, the lxterminal
# running piardopc may still be alive. We don't kill it here
# intentionally — it's the modem terminal and the user may want
# to keep it open to monitor traffic. If they want it gone, they
# close the lxterminal window or stop it from within the yad menu
# (which they can re-launch via the launcher).

[ "$fail" -eq 0 ] && echo "patmenu stopped" || echo "patmenu stop had errors"
exit $fail
