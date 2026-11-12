#!/bin/bash
# Persistent variant of start_desktop.sh — backgrounds children and stays alive.
# Used by my-launcher-desktop.service.

DISPLAY_NUM=20
VNC_PORT=5920
WS_PORT=6100

if pgrep -f "^/usr/bin/Xvfb :$DISPLAY_NUM\b" >/dev/null; then
    echo "Xvfb :$DISPLAY_NUM already running, exiting"
    exit 0
fi

# Use setsid so children fully detach from any controlling terminal
setsid /usr/bin/Xvfb :$DISPLAY_NUM -screen 0 1600x1200x16 > /dev/null 2>&1 < /dev/null &
sleep 1

setsid /usr/bin/env DISPLAY=:$DISPLAY_NUM openbox > /tmp/my_launcher_openbox.log 2>&1 < /dev/null &
sleep 1

setsid /usr/bin/x11vnc -display :$DISPLAY_NUM -rfbport $VNC_PORT -rfbauth /home/pi/.vnc/passwd -shared -forever -o /tmp/my_launcher_x11vnc.log > /dev/null 2>&1 < /dev/null &
sleep 1

/home/pi/sbitx/web/scripts/start_novnc_proxy.sh $VNC_PORT $WS_PORT

# Hold the script open so systemd / session parents dont reap us
echo "Launcher desktop stack started on :$DISPLAY_NUM (Xvfb, openbox, x11vnc, websockify)"
echo "Holding session open... (kill this process to stop the stack)"
wait
