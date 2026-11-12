#!/bin/bash
# Stop a separate (non-launcher) desktop stack. The launcher itself is
# excluded so this script does not kill the webserver you are using to
# invoke it. Hardened 2026-06-23.

# IMPORTANT: set STOP_EXCLUDE_PIDS BEFORE sourcing the lib, because the lib
# reads it once at sourcing time.
LAUNCHER_PIDS=""
for cmd in "my_launcher/app.py" "Xvfb :20" "x11vnc.*5920" "websockify.*6100" "openbox.*DISPLAY=:20"; do
    for p in $(pgrep -f "$cmd" 2>/dev/null); do
        LAUNCHER_PIDS="$LAUNCHER_PIDS,$p"
    done
done
LAUNCHER_PIDS="${LAUNCHER_PIDS#,}"
export STOP_EXCLUDE_PIDS="$LAUNCHER_PIDS"

LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"

echo "Protected (excluded) PIDs:$LAUNCHER_PIDS"

fail=0
stop_proc "Xvfb :20"               || fail=1
stop_proc "x11vnc.*5920"           || fail=1
stop_proc "websockify.*6100"       || fail=1
stop_pidfile /tmp/xfwm4_20.pid "xfwm4 :20" || true

[ "$fail" -eq 0 ] && echo "desktop stopped" || echo "desktop stop had errors"
exit $fail
