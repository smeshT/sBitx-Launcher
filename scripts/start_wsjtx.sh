#!/bin/bash
/home/pi/my_launcher/scripts/start_desktop.sh
sudo systemctl stop freedvtnc2
sudo systemctl stop rnsd
export DISPLAY=:20
export XDG_RUNTIME_DIR=/run/user/$(id -u)
wsjtx >/tmp/my_launcher_wsjtx.log 2>&1 &
exit 0