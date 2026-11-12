#!/bin/bash
# Stop FLDigi. Hardened 2026-06-23.
LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"
fail=0
stop_proc_tree "^(/usr/bin/fldigi|fldigi)$" || fail=1
[ "$fail" -eq 0 ] && echo "fldigi stopped" || echo "fldigi stop had errors"
exit $fail
