#!/bin/bash
# Stop the Reticulum stack: meshchat FIRST (so announces stop promptly),
# then rnsd, then freedvtnc2. Hardened 2026-06-23: SIGKILL fallback if
# systemctl stop hangs (which can happen with rnsd).
# Updated 2026-06-25: also stop reticulum-meshchat (was not previously in
# the stop list — it was started via its own systemd unit and was sending
# announces even when the rest of the stack was down).
fail=0

stop_service() {
    local svc="$1"
    if systemctl is-active --quiet "$svc"; then
        echo "Stopping $svc..."
        if ! sudo systemctl stop "$svc"; then
            echo "  systemctl stop failed for $svc, escalating"
            sudo systemctl kill -s SIGKILL "$svc" 2>/dev/null || true
            fail=1
        fi
        # Verify it actually stopped
        for _ in 1 2 3 4 5; do
            sleep 1
            systemctl is-active --quiet "$svc" || break
        done
        if systemctl is-active --quiet "$svc"; then
            echo "  FAILED: $svc still active"
            sudo systemctl kill -s SIGKILL "$svc" 2>/dev/null || true
            fail=1
        else
            echo "  $svc stopped"
        fi
    else
        echo "$svc was not running"
    fi
}

# Order matters: stop meshchat FIRST so it stops broadcasting announces
# before we tear down rnsd underneath it.
stop_service reticulum-meshchat
stop_service rnsd
stop_service freedvtnc2

[ "$fail" -eq 0 ] && echo "reticulum stopped" || echo "reticulum stop had errors"
exit $fail
