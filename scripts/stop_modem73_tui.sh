#!/bin/bash
# Stop the modem73 TUI window AND kill pipewire-pulse so JJ fork can run
pkill -f "lxterminal.*--title=modem73" 2>/dev/null || true
pkill -f "pipewire-pulse" 2>/dev/null || true
