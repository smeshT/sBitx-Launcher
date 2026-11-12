# Parse [[Modem73]] block in /home/pi/.reticulum/config and emit the
# value of the first non-comment `enabled = ...` line.
#
# Pattern source: parse_freedv_block.awk — identical except for the
# block-name regex (Modem73 vs freedvtnc2 Interface).
#
# Exit codes:
#   0 = parsed successfully, printed value (true / false)
#   1 = [[Modem73]] block not found
#   2 = no enabled= line found inside the block
/^[[:space:]]*\[\[Modem73\]\]/ { inblock = 1; next }
inblock && /^[[:space:]]*#/         { next }
inblock && /^[[:space:]]*enabled[[:space:]]*=/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    sub(/^enabled[[:space:]]*=[[:space:]]*/, "", $0)
    print tolower($0)
    exit
}
inblock && /^[[:space:]]*\[\[/ { exit 1 }
