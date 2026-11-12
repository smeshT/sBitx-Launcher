#!/bin/bash
# Stop GridTracker. Hardened 2026-06-23; regex updated 2026-09-04.
#
# GridTracker 2 launches as `/bin/bash /usr/bin/gridtracker2` (the
# wrapper, a bash script) which then execs `/opt/GridTracker2/gridtracker2.bin`.
# So `pgrep -f gridtracker2` matches the wrapper; we also want to match
# the .bin processes in case the wrapper is gone but a child survives.
# Drop the ^...$ anchors — procps pgrep -f matches against the full
# cmdline (space-joined), so anchored patterns don't match the actual
# wrapper invocations.
LIB=/home/pi/my_launcher/scripts/_lib_stop.sh
# shellcheck disable=SC1091
source "$LIB"
fail=0
stop_proc_tree "gridtracker2" || fail=1
[ "$fail" -eq 0 ] && echo "gridtracker stopped" || echo "gridtracker stop had errors"
exit $fail
