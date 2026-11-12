#!/bin/bash
# Stop JS8Call — kills js8call parent and /usr/bin/js8 child.
# Hardened 2026-06-23: was using SIGTERM which Qt apps ignore.
LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"
fail=0
stop_proc_tree "^(/usr/bin/js8call|js8call)$" || fail=1
stop_proc_tree "/usr/bin/js8 -s JS8Call"      || fail=1
[ "$fail" -eq 0 ] && echo "js8call stopped" || echo "js8call stop had errors"
exit $fail
