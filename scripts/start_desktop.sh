#!/bin/bash

DISPLAY_NUM=20
VNC_PORT=5920
WS_PORT=6100

if pgrep -f "Xvfb :$DISPLAY_NUM" >/dev/null; then
    exit 0
fi

Xvfb :$DISPLAY_NUM -screen 0 1600x1200x16 &
sleep 1

DISPLAY=:$DISPLAY_NUM openbox >/tmp/my_launcher_openbox.log 2>&1 &

x11vnc -display :$DISPLAY_NUM -rfbport $VNC_PORT -rfbauth /home/pi/.vnc/passwd -shared -forever -o /tmp/my_launcher_x11vnc.log &

/home/pi/sbitx/web/scripts/start_novnc_proxy.sh $VNC_PORT $WS_PORT

exit 0