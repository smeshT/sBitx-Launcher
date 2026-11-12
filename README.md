# sbitx-launcher

**Work in progress. Take it or leave it.**

A Flask control panel for the [sBitx](https://github.com/afarhan/sbitx) HF
radio. It gives you one web page with buttons to launch and stop the
apps you actually use — fldigi, JS8Call, WSJTX, GridTracker, freeDV,
Reticulum/meshchatx, modem73, patmenu, and the shared VNC desktop.

This is a thin launcher, not a distro. It does **not** install anything
and it does **not** set up the apps it launches. It drives an sBitx box
that is already configured.

## Intended base system

**Install the [drexjj 64-bit sBitx image](https://github.com/drexjj/sbitx)
first.** That image ships the sBitx application, the desktop environment,
and most of the apps these buttons launch, already configured at
`/home/pi` under user `pi`. This launcher is layered on top of it and
assumes it is there.

The upstream project is a volunteer effort (led by W9JES), not affiliated
with HF Signals. Its GitHub pages are periodically unavailable; if the
repo is down, wait for it to come back rather than substituting a stock
Raspberry Pi OS image, because then most buttons will have nothing to
launch.

Minimum confirmed base: Raspberry Pi 4, aarch64, Debian 12 bookworm,
Python 3 with Flask 2.2.

## Status

Extracted from a working sbitx unit on 2026-11-11. It runs. It is not
packaged, not parameterised, and not tested on any box other than the one
it came off.

Known deliberate omissions:

- **Assumes `/home/pi` and user `pi`.** That is the sbitx default. Paths
  are hardcoded and there are no env-var overrides.
- **Assumes a `sudo` setup.** The scripts run `sudo systemctl ...`.
  The reference box used the stock Raspberry Pi OS
  `pi ALL=(ALL) NOPASSWD: ALL` via `/etc/sudoers.d/010_pi-nopasswd`.
  Narrowing that to a per-command allowlist is left as an exercise.
- **Audio is out of scope.** Card indices and device names vary by
  hardware. sBitx is designed not to need an external interface, so the
  defaults target the built-in audio. The modem73 Digirig TUI row is
  kept for people experimenting with external interfaces; it assumes
  card 5 and you should expect to edit it.

## Prerequisites

The drexjj image provides most of this. Items marked **extra** are not
part of it and must be added separately if you want those buttons to work.

| Category | Expected on disk | Provided by image |
|---|---|---|
| sBitx itself | `/home/pi/sbitx` (includes `web/scripts/start_novnc_proxy.sh`) | yes |
| Reticulum | `/home/pi/.reticulum/config`, `rnsd`, `lxmd`, `meshchatx` | yes |
| freeDV | `/home/pi/.freedvtnc2.conf`, `/home/pi/freedata` | yes |
| patmenu | `/home/pi/patmenu2` | yes |
| VNC desktop | `x11vnc`, `websockify`, `Xvfb`, `openbox`, `~/.vnc/passwd` | yes |
| GUI apps | `lxterminal`, `fldigi`, `js8call`, `wsjtx`, `pavucontrol` | yes |
| Python | `python3`, `flask` | yes |
| modem73 | `/usr/local/bin/modem73`, `~/.config/modem73/settings` | **extra** |
| GridTracker | `gridtracker` on `PATH` | **extra** |

Every `sudo systemctl <verb> <unit>` call assumes the corresponding unit
exists. The launcher restarts, starts and stops units; it never creates
them. Units referenced: `rnsd`, `lxmd`, `meshchatx`, `freedvtnc2`.

Buttons whose app is missing fail on press rather than at load time — the
launcher does not probe for dependencies.

## Install

```bash
sudo apt install python3-flask
git clone https://github.com/smeshT/sbitx-launcher.git /home/pi/my_launcher
sudo cp /home/pi/my_launcher/systemd/my-launcher.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now my-launcher.service
```

Then browse to `http://<box>:8090/`.

The optional shared desktop unit is `systemd/my-launcher-desktop.service`.
It expects `Xvfb`, `openbox`, `x11vnc` and `websockify`.

## Design notes

- **Buttons are POST routes that shell out**, then redirect so the UI
  never hangs on a slow start. Restarts are fired with `Popen` and
  detached.
- **Stop scripts are idempotent.** They read a pidfile and no-op when the
  app is already down.
- **`restart-sbitx-reticulum.sh` orders things deliberately:** stop
  meshchatx and lxmd, bounce rnsd, wait for it to be active, then start
  meshchatx and lxmd in sequence. Clients attach to rnsd; restarting
  everything in parallel races. It also `pkill`s stragglers that escaped
  systemd's cgroup tracking.
- **`_lib_stop.sh`** is the shared helper the stop scripts source. It
  must stay in `scripts/`.

## Not included

- The apps themselves.
- Reticulum interface configuration.
- Any credentials, callsigns, frequencies or network IDs.
- Historical `.bak` files from the source box.

## License

No license file yet. Treat as all-rights-reserved until one is added.
