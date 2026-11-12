from flask import Flask, render_template, redirect, url_for, request
import subprocess

app = Flask(__name__)

SCRIPTS = "/home/pi/my_launcher/scripts"

def is_running(cmd):
    return subprocess.run(
        ["pgrep", "-f", cmd],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    ).returncode == 0

def service_active(name):
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    ).returncode == 0

def get_freedvtnc2_mode():
    """Read freedvtnc2's current TX mode.

    Returns a tuple (display, css_class) where:
        * display is e.g. "freedvtnc2: DATAC4" or "freedvtnc2: DATAC1 (override)"
        * css_class is 'mode' (normal) or 'mode-override' (cmdline
          --mode X differs from the config file)
        * returns (None, None) if the mode can't be determined.

    The mode is the live TX mode, in this order of precedence:
        1. The running freedvtnc2 process's --mode flag (if any).
        2. ~/.freedvtnc2.conf (which freedvtnc2 reads on start, and the
           CLI also writes back to on exit).
    """
    import re
    cfg_kv = {}
    try:
        with open("/home/pi/.freedvtnc2.conf") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or line.startswith(";"):
                    continue
                m = re.match(r"^([A-Za-z0-9_.\-]+)\s*=\s*(.*?)\s*$", line)
                if m:
                    cfg_kv[m.group(1).lower()] = m.group(2)
    except OSError:
        pass
    cfg_mode = cfg_kv.get("mode")

    # Look for a --mode X flag on the running freedvtnc2 process. Use
    # systemd's ExecMainPID to identify it; pgrep self-matches against
    # the launcher's own command line.
    cli_mode = None
    if service_active("freedvtnc2"):
        try:
            pid_str = subprocess.check_output(
                ["systemctl", "show", "freedvtnc2", "-p", "ExecMainPID", "--value"],
                stderr=subprocess.DEVNULL,
            ).decode("utf-8", "replace").strip()
        except subprocess.CalledProcessError:
            pid_str = ""
        if pid_str and pid_str.isdigit() and int(pid_str) > 0:
            try:
                with open(f"/proc/{pid_str}/cmdline", "rb") as f:
                    cmdline = f.read().replace(b"\x00", b" ").decode(
                        "utf-8", "replace")
            except OSError:
                cmdline = ""
            mm = re.search(r"--mode[=\s]+(DATAC[134])", cmdline)
            if mm:
                cli_mode = mm.group(1)

    effective = cli_mode or cfg_mode
    if not effective:
        return None, None
    if cli_mode and cli_mode != cfg_mode:
        return f"freedvtnc2: {cli_mode} (override)", "mode-override"
    return f"freedvtnc2: {effective}", "mode"


def set_freedvtnc2_mode(new_mode):
    """Set the freedvtnc2 TX mode by writing ~/.freedvtnc2.conf and
    restarting the systemd service so the change takes effect.

    Returns (ok, message). On failure, message is human-readable and
    the config file is left unchanged.
    """
    if new_mode not in ("DATAC1", "DATAC3", "DATAC4"):
        return False, f"invalid mode: {new_mode}"

    # Read existing config so we preserve every other key/value/comment.
    config_path = "/home/pi/.freedvtnc2.conf"
    try:
        with open(config_path) as f:
            original = f.read()
    except OSError as e:
        return False, f"cannot read {config_path}: {e}"

    import re
    new_line = f"mode = {new_mode}\n"
    new_contents, n = re.subn(
        r"(?m)^[ \t]*mode[ \t]*=.*$",
        new_line.rstrip("\n"),
        original,
        count=1,
    )
    if n == 0:
        # No existing mode = line; append.
        if not original.endswith("\n"):
            new_contents = original + "\n"
        else:
            new_contents = original
        new_contents += new_line

    try:
        with open(config_path, "w") as f:
            f.write(new_contents)
    except OSError as e:
        return False, f"cannot write {config_path}: {e}"

    # Restart freedvtnc2 so it picks up the new mode. Use sudo -n so this
    # works non-interactively from the launcher systemd unit.
    proc = subprocess.run(
        ["sudo", "/home/pi/my_launcher/scripts/restart-sbitx-reticulum.sh" "freedvtnc2"],
        capture_output=True,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", "replace").strip() or \
              proc.stdout.decode("utf-8", "replace").strip()
        return False, f"wrote config but restart failed: {err}"
    return True, f"set mode to {new_mode}"

def run_script(name, args=None):
    cmd = [f"{SCRIPTS}/{name}"]
    if args:
        cmd.extend(args)
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

@app.route("/")
def index():
    run_script("start_desktop.sh")

    status = {
        # Always-on pills first (top of the status bar). If any of these
        # shows "Stopped" on a healthy box, it's a red flag. Order is
        # what the operator requested 2026-09-04:
        #   Shared Desktop -> sBitx radio -> RNSD -> MeshChat
        "Shared Desktop": is_running("Xvfb :20"),
        "sBitx radio": is_running("^/home/pi/sbitx/sbitx$"),
        "RNSD": service_active("rnsd"),
        "MeshChat": service_active("meshchatx"),
        # On-demand apps / mode pills. These come after the always-on
        # block; expect Stopped on a fresh boot until the operator
        # clicks Start.
        "Pavucontrol": is_running("pavucontrol"),
        "JS8Call": is_running("js8call"),
#        "GridTracker": is_running("gridtracker2"),
        "FLDigi": is_running("fldigi"),
        "WSJT-X": is_running("wsjtx"),
        "freedvtnc2 Chat": (is_running(r"tmux.*-s freedvtnc2") and is_running(r"/local/bin/freedvtnc2")),
        "Modem73 TUI": is_running(r"lxterminal.*--title=modem73[^-]"),
        "freedvtnc2 interface": freedvtnc2_in_reticulum(),
        "Modem73 interface": modem73_in_reticulum(),
        "Pat Menu": is_running("Pat Menu"),
    }
    
    freedv_pill_text, freedv_pill_class = get_freedvtnc2_mode()
    if freedv_pill_text is None:
        # Config unreadable AND service not running; the existing
        # FreeDV TNC2: Running/Stopped pill in the status bar already
        # tells the user that freedvtnc2 is down, so don't pile on
        # another "unknown" pill.
        return render_template(
            "index.html",
            status=status,
            host=request.host.split(":")[0],
            freedv_pill_text=None,
            freedv_pill_class=None,
            active_mode=None,
        )
    # Extract the bare mode name (DATAC1/3/4) for the active highlight.
    import re as _re
    mm = _re.search(r"DATAC[134]", freedv_pill_text)
    active_mode = mm.group(0) if mm else None
    return render_template(
        "index.html",
        status=status,
        host=request.host.split(":")[0],
        freedv_pill_text=freedv_pill_text,
        freedv_pill_class=freedv_pill_class,
        active_mode=active_mode,
    )

@app.route("/start-desktop", methods=["POST"])
def start_desktop():
    run_script("start_desktop.sh")
    return redirect(url_for("index"))

@app.route("/stop-desktop", methods=["POST"])
def stop_desktop():
    run_script("stop_desktop.sh")
    return redirect(url_for("index"))

@app.route("/start-js8call", methods=["POST"])
def start_js8call():
    run_script("start_js8call.sh")
    return redirect(url_for("index"))

@app.route("/stop-js8call", methods=["POST"])
def stop_js8call():
    run_script("stop_js8call.sh")
    return redirect(url_for("index"))

@app.route("/start-gridtracker", methods=["POST"])
def start_gridtracker():
    run_script("start_gridtracker.sh")
    return redirect(url_for("index"))

@app.route("/stop-gridtracker", methods=["POST"])
def stop_gridtracker():
    run_script("stop_gridtracker.sh")
    return redirect(url_for("index"))


@app.route("/start-sbitx", methods=["POST"])
def start_sbitx():
    """Start the sBitx radio binary if not already running.

    Sets DISPLAY=:0 because sbitx is a GTK app and needs an X display.
    The LXDE desktop on the box is :0 (lxsession at tty7). my_launcher
    runs as a user service without a default DISPLAY, so we have to set
    it explicitly here.
    """
    if is_running("^/home/pi/sbitx/sbitx$"):
        return redirect(url_for("index"))
    subprocess.Popen(
        ["/home/pi/sbitx/sbitx"],
        cwd="/home/pi/sbitx",
        env={"DISPLAY": ":0", "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOME": "/home/pi"},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))


@app.route("/restart-sbitx", methods=["POST"])
def restart_sbitx():
    """Hard restart of the sBitx binary.

    SIGKILL the running instance (if any), wait 1s, then launch fresh
    with DISPLAY=:0. Audio is interrupted for ~10s while sbitx re-inits.
    """
    subprocess.run(
        ["pkill", "-9", "-f", "^/home/pi/sbitx/sbitx$"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    import time as _t; _t.sleep(1)
    subprocess.Popen(
        ["/home/pi/sbitx/sbitx"],
        cwd="/home/pi/sbitx",
        env={"DISPLAY": ":0", "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOME": "/home/pi"},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

def freedvtnc2_in_reticulum():
    """Return True iff the [[freedvtnc2 Interface]] block in
    ~/.reticulum/config has enabled = true. Drives the FreeDV Audio
    In Reticulum status pill."""
    import subprocess
    try:
        out = subprocess.check_output(
            ["/home/pi/my_launcher/scripts/check_freedv_in_reticulum.sh"],
            stderr=subprocess.DEVNULL, timeout=2,
        ).decode().strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return False
    return out == "true"


def modem73_in_reticulum():
    """Return True iff the [[Modem73]] block in
    ~/.reticulum/config has enabled = true. Drives the Modem73
    interface status pill.

    Pattern source: freedvtnc2_in_reticulum(). The check runs an
    external helper script (check_modem73_in_reticulum.sh) which
    invokes an AWK parser (parse_modem73_block.awk) — same
    pattern as the freedvtnc2 pair, just for the Modem73 block.
    """
    import subprocess
    try:
        out = subprocess.check_output(
            ["/home/pi/my_launcher/scripts/check_modem73_in_reticulum.sh"],
            stderr=subprocess.DEVNULL, timeout=2,
        ).decode().strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return False
    return out == "true"

@app.route("/start-pavucontrol", methods=["POST"])
def start_pavucontrol():
    run_script("start_pavucontrol.sh")
    return redirect(url_for("index"))

@app.route("/stop-pavucontrol", methods=["POST"])
def stop_pavucontrol():
    run_script("stop_pavucontrol.sh")
    return redirect(url_for("index"))

@app.route("/start-reticulum", methods=["POST"])
def start_reticulum():
    """Enable FreeDV (audio modem) in Reticulum.

    As of the 2026-08-21 refactor: rnsd + reticulum-meshchat are always-on
    transport services. This button toggles the [[freedvtnc2 Interface]]
    block in ~/.reticulum/config (enabled=true|false) and starts/stops
    freedvtnc2.service. rnsd is bounced so it picks up the config edit
    (~3s transport-path bounce; TCP peers re-establish automatically).
    """
    run_script("toggle_freedv_audio.sh", args=["on"])
    return redirect(url_for("index"))

@app.route("/stop-reticulum", methods=["POST"])
def stop_reticulum():
    """Disable FreeDV (audio modem) in Reticulum.

    Frees the ALSA loopback subdevs for js8call/wsjtx/fldigi/modem73.
    See start_reticulum docstring for context.
    """
    run_script("toggle_freedv_audio.sh", args=["off"])
    return redirect(url_for("index"))

@app.route("/reset-modem73-audio", methods=["POST"])
def reset_modem73_audio():
    """Reset modem73 audio device to default (audio_input=0, audio_output=0).

    Use when modem73 fails to start because the saved audio device index
    no longer matches any available hardware (e.g. operator moved the
    digirig between boxes / swapped USB ports, and the ALSA / PipeWire
    card numbering shifted).

    Writes audio_input=0 + audio_output=0 to ~/.config/modem73/settings
    (atomically), then kills + restarts the modem73 loopback subprocess
    so the new settings take effect. Does NOT touch callsign, port,
    modulation, CSMA, tx_drive, or the Reticulum [[Modem73]] block.

    Pattern source: g90's freedvtnc2 Reset Audio Devices button (which
    is heavier — stops the whole stack and bounces noVNC). This button
    is intentionally narrower because modem73's audio reset is much
    more targeted (settings file + process restart only)."""
    run_script("reset_modem73_audio.sh")
    return redirect(url_for("index"))


@app.route("/start-modem73-tui", methods=["POST"])
def start_modem73_tui():
    """Open the modem73 TUI in an lxterminal inside the sbitx box's
    Xvfb :20 desktop (visible in the noVNC tab). The TUI runs
    modem73 in interactive mode (no --headless) against the
    AudioInjector HAT directly.

    Pattern source: g90 box's freedv_tui.sh. NOT the sbitx
    freedvtnc2 TUI pattern (ttyd-shim + tmux + systemd Conflicts=
    unit graph — that approach has known issues and the operator
    didn't want to duplicate it).

    Conflict story: modem73 in TUI mode opens the AudioInjector HAT;
    the modem73 Loopback instance uses plughw:Loopback so they
    don't directly share a device, but they're the same binary
    and likely share config files. Operator's responsibility to
    not run both at once — no systemd Conflicts= enforced."""
    run_script("start_modem73_tui.sh")
    return redirect(url_for("index"))

@app.route("/stop-modem73-tui", methods=["POST"])
def stop_modem73_tui():
    """Close the modem73 TUI lxterminal. Kills any lxterminal
    whose title is "modem73" (the script sets --title=modem73).
    Using pkill on the title pattern is more reliable than pkill
    on the binary name alone, which would also match other
    lxterminals the user has open."""
    run_script("stop_modem73_tui.sh")
    return redirect(url_for("index"))
@app.route("/restart-reticulum", methods=["POST"])
def restart_reticulum_and_meshchatx():
    """Restart rnsd + meshchatx + lxmd in order. Bounces freedvtnc2 too.

    Order: stop lxmd, restart rnsd, wait, restart meshchatx+lxmd.
    Redirect returns immediately so the UI does not hang."""
    subprocess.Popen(
        ["sudo", "/home/pi/my_launcher/scripts/restart-sbitx-reticulum.sh"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/start-patmenu", methods=["POST"])
def start_patmenu():
    """Start the patmenu2 yad menu on DISPLAY=:20.

    The yad menu appears in the noVNC tab. Inside it, the user
    clicks "Start/Stop Modem" to bring up piardopc + piARDOP_GUI
    (which also open on the same desktop, also visible via noVNC).
    Idempotent: clicking Start again while the menu is already
    open is a no-op (see start_patmenu.sh).
    """
    run_script("start_patmenu.sh")
    return redirect(url_for("index"))

@app.route("/stop-patmenu", methods=["POST"])
def stop_patmenu():
    """Stop the patmenu2 yad menu. Does NOT stop piardopc /
    piARDOP_GUI — those are managed by the yad menu's own
    "Start/Stop Modem" button (or by closing the lxterminal
    in the noVNC tab)."""
    run_script("stop_patmenu.sh")
    return redirect(url_for("index"))

@app.route("/start-freedata", methods=["POST"])
def start_freedata():
    """Start the freedata server (FastAPI/uvicorn) on :5001.

    Idempotent: if freedata is already listening on :5001, this
    is a no-op (see start_freedata.sh).

    The freedata web UI is at http://<host>:5001/gui — open it in
    a browser to compose/send ARQ messages. Does NOT need the Xvfb
    desktop; only the browser is required.
    """
    run_script("start_freedata.sh")
    return redirect(url_for("index"))

@app.route("/stop-freedata", methods=["POST"])
def stop_freedata():
    """Stop the freedata server.

    Sends SIGTERM (not SIGKILL — a hard kill on a sqlite3 process
    can corrupt the database). If the server is wedged and SIGTERM
    doesn't take, manual intervention is required (check the log
    in /tmp/my_launcher_freedata.log).
    """
    run_script("stop_freedata.sh")
    return redirect(url_for("index"))

@app.route("/reboot-pi", methods=["POST"])
def reboot_pi():
    """Reboot the sbitx box. This disconnects SSH, VNC, the launcher,
    and any active QSOs / Reticulum sessions. The launcher page has
    a JS confirm() to prevent accidental clicks."""
    subprocess.Popen(
        ["sudo", "-n", "systemctl", "reboot"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return ("<h1>Rebooting...</h1>"
            "<p>The sbitx box is rebooting. This page will go down in a few seconds. "
            "Give it ~60s before reconnecting.</p>")

@app.route("/set-mode/<mode>", methods=["POST"])
def set_mode(mode):
    """Switch freedvtnc2 to a new TX mode.

    Writes ~/.freedvtnc2.conf and restarts the freedvtnc2 systemd
    service. The KISS socket drops for ~3 seconds while freedvtnc2
    restarts; meshchat auto-reconnects.
    """
    ok, msg = set_freedvtnc2_mode(mode)
    return redirect(url_for("index"))

@app.route("/start-fldigi", methods=["POST"])
def start_fldigi():
    run_script("start_fldigi.sh")
    return redirect(url_for("index"))

@app.route("/stop-fldigi", methods=["POST"])
def stop_fldigi():
    run_script("stop_fldigi.sh")
    return redirect(url_for("index"))

@app.route("/start-wsjtx", methods=["POST"])
def start_wsjtx():
    run_script("start_wsjtx.sh")
    return redirect(url_for("index"))

@app.route("/stop-wsjtx", methods=["POST"])
def stop_wsjtx():
    run_script("stop_wsjtx.sh")
    return redirect(url_for("index"))

@app.route("/start-freedvtnc2-web", methods=["POST"])
def start_freedvtnc2_web():
    """Start the freedvtnc2-web sidecar (Flask UI on :8091).

    Implemented inline (not via a start_*.sh script) because it does not
    need desktop/audio setup, just a plain `systemctl start`. Patterned
    after /restart-meshchat.
    """
    subprocess.Popen(
        ["sudo", "-n", "systemctl", "start", "freedvtnc2-web"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/stop-freedvtnc2-web", methods=["POST"])
def stop_freedvtnc2_web():
    subprocess.Popen(
        ["sudo", "-n", "systemctl", "stop", "freedvtnc2-web"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/restart-freedvtnc2-web", methods=["POST"])
def restart_freedvtnc2_web():
    subprocess.Popen(
        ["sudo", "/home/pi/my_launcher/scripts/restart-sbitx-reticulum.sh" "freedvtnc2-web"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/start-ttyd", methods=["POST"])
def start_ttyd():
    """Start the ttyd-freedvtnc2 sidecar (browser terminal on :8092).

    Stops the freedvtnc2 daemon first (audio device is single-tenant),
    then starts ttyd. Patterned after /start-freedvtnc2-web.
    """
    if service_active("freedvtnc2"):
        subprocess.Popen(
            ["sudo", "-n", "systemctl", "stop", "freedvtnc2"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    subprocess.Popen(
        ["sudo", "-n", "systemctl", "start", "ttyd-freedvtnc2"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/stop-ttyd", methods=["POST"])
def stop_ttyd():
    subprocess.Popen(
        ["tmux", "kill-session", "-t", "freedvtnc2"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

@app.route("/start-freedvtnc2-daemon", methods=["POST"])
def start_freedvtnc2_daemon():
    """Stop the TUI (frees audio device) and start the freedvtnc2 daemon
    for Reticulum / meshchat use."""
    if service_active("ttyd-freedvtnc2"):
        subprocess.Popen(
            ["sudo", "-n", "systemctl", "stop", "ttyd-freedvtnc2"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        import time as _t; _t.sleep(1)
    subprocess.Popen(
        ["sudo", "-n", "systemctl", "start", "freedvtnc2"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return redirect(url_for("index"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8090)
