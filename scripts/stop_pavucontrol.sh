#!/bin/bash
# Stop pavucontrol. Hardened 2026-06-23.
LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"
fail=0
stop_proc_tree "pavucontrol" || fail=1
[ "$fail" -eq 0 ] && echo "pavucontrol stopped" || echo "pavucontrol stop had errors"
exit $fail
