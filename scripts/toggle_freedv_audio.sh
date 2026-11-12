#!/bin/bash
# toggle_freedv_audio.sh — Enable or disable the FreeDV audio modem in
# Reticulum on the sbitx box, without taking rnsd or reticulum-meshchat down.
#
# Behaviour:
#   * On  (was off): start freedvtnc2.service, set `enabled = true` for the
#                     [[freedvtnc2 Interface]] block, restart rnsd so it
#                     picks up the new interface config (~3s transport-path
#                     bounce, TCP peers re-establish automatically).
#                     Also pkill competing audio modems (js8call, wsjtx,
#                     fldigi) since they hold loopback subdevs.
#   * Off (was on):  stop freedvtnc2.service, set `enabled = false` for the
#                     [[freedvtnc2 Interface]] block, restart rnsd so it
#                     stops trying to TCP-connect to 127.0.0.1:8001.
#                     Loopback subdevs are released for other audio modems.
#
# rnsd 1.4.2 does not support SIGHUP config reload, so an rnsd restart is
# required for any config edit to take effect. meshchat has Requires=rnsd
# so it waits for rnsd to come back; no extra sequencing needed.
#
# Usage:  toggle_freedv_audio.sh on | off
#         (no arg = toggle based on current config state)
#
# Exit codes:
#   0 = success
#   1 = config parse / file edit failure
#   2 = systemctl operation failed
#   3 = bash internal error / missing argument

set -u

CONFIG="/home/pi/.reticulum/config"
RNSD="rnsd.service"
FREEDV="freedvtnc2.service"
PARSER="/home/pi/my_launcher/scripts/parse_freedv_block.awk"

die() { echo "toggle_freedv_audio: $*" >&2; exit "$2"; }

# Don't require root: we use sudo -n for privileged ops. The python config
# edit works as pi because the parent dir /home/pi/.reticulum/ is pi-owned
# and tmp.replace(p) is an atomic rename within that dir.
[ -f "$CONFIG" ] || die "$CONFIG not found" 1
[ -f "$PARSER" ] || die "$PARSER not found" 1

# Verify sudo -n works for systemctl without password.
if ! sudo -n true 2>/dev/null; then
    die "sudo -n unavailable; passwordless sudo required for this script" 3
fi

# ---------- find current state ----------
# Locate the FIRST non-comment "enabled = ..." line inside [[freedvtnc2 Interface]].
get_state() {
    awk -f "$PARSER" "$CONFIG"
}

current=$(get_state) || die "could not find enabled= inside [[freedvtnc2 Interface]] block" 1

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

# Find the [[freedvtnc2 Interface]] block boundaries (header may be indented).
m_start = re.search(r'^\s*\[\[freedvtnc2 Interface\]\]', text, re.MULTILINE)
if not m_start:
    sys.exit('block [[freedvtnc2 Interface]] not found')
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
    sys.exit('expected 1 enabled= in [[freedvtnc2 Interface]], found ' + str(n))

new_text = text[:start] + new_block + text[end:]
tmp = p.with_suffix('.config.toggle.tmp')
tmp.write_text(new_text)
tmp.replace(p)
print('config updated: ' + str(n) + ' replacement(s)')
PYEOF
[ $? -eq 0 ] || die "config edit failed" 1

# ---------- act on the new state ----------
if [ "$target" = "true" ]; then
    pkill js8call  2>/dev/null
    pkill wsjtx    2>/dev/null
    pkill fldigi   2>/dev/null
    pkill pavucontrol 2>/dev/null
    sleep 1
    if ! sudo -n systemctl start "$FREEDV"; then
        die "systemctl start $FREEDV failed" 2
    fi
else
    if ! sudo -n systemctl disable --now "$FREEDV"; then
        die "systemctl disable --now $FREEDV failed" 2
    fi
fi

# Always bounce rnsd so it picks up the config change.
# meshchat Requires=rnsd so it waits; auto-restart kicks in.
if ! sudo -n systemctl restart "$RNSD"; then
    die "systemctl restart $RNSD failed" 2
fi

echo "done: freedvtnc2 audio modem is now $([ "$target" = "true" ] && echo enabled || echo disabled) in Reticulum"
exit 0
