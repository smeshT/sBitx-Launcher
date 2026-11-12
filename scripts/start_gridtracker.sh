#!/bin/bash
/home/pi/my_launcher/scripts/start_desktop.sh
export DISPLAY=:20
export XDG_RUNTIME_DIR=/run/user/$(id -u)
gridtracker2 >/tmp/my_launcher_gridtracker.log 2>&1 &
exit 0