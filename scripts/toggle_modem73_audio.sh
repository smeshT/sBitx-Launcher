#!/bin/bash
# toggle_modem73_audio.sh — Enable or disable the Modem73 OFDM modem in
# Reticulum on the sbitx box, without taking rnsd or reticulum-meshchat
# down.
#
# Behaviour:
#   * On  (was off): set `enabled = true` for the [[Modem73]] block in
#                     /home/pi/.reticulum/config, start modem73 loopback
#                     (which exposes its KISS TCP port per
#                     ~/.config/modem73/settings), restart rnsd so it
#                     picks up the new interface config (~3s transport-
#                     path bounce, TCP peers re-establish automatically).
#                     Also pkill competing audio modems (js8call, wsjtx,
#                     fldigi) since they may hold loopback subdevs.
#   * Off (was on):  stop modem73 loopback, set `enabled = false` for the
#                     [[Modem73]] block, restart rnsd so it stops trying
#                     to TCP-connect to the modem73 KISS port.
#                     Loopback subdevs are released for other audio modems.
#
# rnsd 1.4.2 does not support SIGHUP config reload, so an rnsd restart is
# required for any config edit to take effect. meshchat has Requires=rnsd
# so it waits for rnsd to come back; no extra sequencing needed.
#
# Pattern source: toggle_freedv_audio.sh — identical except it drives the
# modem73 binary instead of freedvtnc2.service. modem73 is launched as
# a detached subprocess (no systemd unit), not as a service.
#
# Usage:  toggle_modem73_audio.sh on | off
#         (no arg = toggle based on current config state)
#
# Exit codes:
#   0 = success
#   1 = config parse / file edit failure
#   2 = modem73 launch / kill / rnsd restart failure
#   3 = bash internal error / missing argument

set -u

CONFIG="/home/pi/.reticulum/config"
RNSD="rnsd.service"
PARSER="/home/pi/my_launcher/scripts/parse_modem73_block.awk"
START_SCRIPT="/home/pi/my_launcher/scripts/start_modem73_loopback.sh"
STOP_SCRIPT="/home/pi/my_launcher/scripts/stop_modem73_loopback.sh"

die() { echo "toggle_modem73_audio: $*" >&2; exit "$2"; }

# Verify sudo -n works for systemctl without password.
if ! sudo -n true 2>/dev/null; then
    die "sudo -n unavailable; passwordless sudo required for this script" 3
fi

[ -f "$CONFIG" ]  || die "$CONFIG not found" 1
[ -f "$PARSER" ]  || die "$PARSER not found" 1
[ -x "$START_SCRIPT" ] || die "$START_SCRIPT not executable" 3
[ -x "$STOP_SCRIPT" ]  || die "$STOP_SCRIPT not executable" 3

# ---------- find current state ----------
get_state() {
    awk -f "$PARSER" "$CONFIG"
}

current=$(get_state) || die "could not find enabled= inside [[Modem73]] block" 1

# ---------- determine target state ----------
target="${1:-}"
case "$target" in
    on|true|1)  target=true ;;
    off|false|0) target=false ;;
    "")
        if [ "$current" = "true" ]; then target=false; else target=true; fi
        ;;
    *) die "unknown argument: $target (use: on | off)" 3 ;;
esac

echo "current: enabled = $current"
echo "target:  enabled = $target"

# ---------- edit the config atomically ----------
python3 - "$CONFIG" "$target" <<'PYEOF'
import sys, re, pathlib
cfg_path, new_val = sys.argv[1], sys.argv[2]
p = pathlib.Path(cfg_path)
text = p.read_text()

# Find the [[Modem73]] block boundaries (header may be indented).
m_start = re.search(r'^\s*\[\[Modem73\]\]', text, re.MULTILINE)
if not m_start:
    sys.exit('block [[Modem73]] not found')
start = m_start.start()
rest = text[m_start.end():]
m_nxt = re.search(r'\n\s*\[\[', rest)
end = m_start.end() + (m_nxt.start() if m_nxt else len(rest))

# Inside the block, replace the first non-comment 'enabled = ...' line.
block = text[start:end]
new_block, n = re.subn(
    r'(?m)^(\s*)#.*$|^(\s*)enabled\s*=[^\n]*',
    lambda mm: (mm.group(0) if mm.group(2) is None
                else mm.group(2) + 'enabled = ' + new_val),
    block,
    count=1,
)
if n != 1:
    sys.exit('expected 1 enabled= in [[Modem73]], found ' + str(n))

new_text = text[:start] + new_block + text[end:]
tmp = p.with_suffix('.config.toggle.tmp')
tmp.write_text(new_text)
tmp.replace(p)
print('config updated: ' + str(n) + ' replacement(s)')
PYEOF
[ $? -eq 0 ] || die "config edit failed" 1

# ---------- act on the new state ----------
if [ "$target" = "true" ]; then
    # Kill competing audio modems that might hold the loopback ALSA device.
    pkill js8call  2>/dev/null
    pkill wsjtx    2>/dev/null
    pkill fldigi   2>/dev/null
    pkill pavucontrol 2>/dev/null
    sleep 1
    # Start modem73 loopback. The script reads its port from
    # ~/.config/modem73/settings (no CLI port args).
    "$START_SCRIPT" || die "start_modem73_loopback.sh failed" 2
else
    "$STOP_SCRIPT" || die "stop_modem73_loopback.sh failed" 2
fi

# Always bounce rnsd so it picks up the config change.
# meshchat Requires=rnsd so it waits; auto-restart kicks in.
if ! sudo -n systemctl restart "$RNSD"; then
    die "systemctl restart $RNSD failed" 2
fi

echo "done: modem73 interface is now $([ "$target" = "true" ] && echo enabled || echo disabled) in Reticulum"
exit 0
