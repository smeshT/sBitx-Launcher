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
first.** That image provides the sBitx application itself, the desktop
environment, and the common GUI apps at `/home/pi` under user `pi`.

**The image does not include everything.** The Reticulum stack
(`rns`, `lxmf`, `meshchatx`), freeDV TNC, and modem73 are installed
separately — see [Bootstrap](#bootstrap). This launcher is a launcher, not
a provisioner.

The upstream project is a volunteer effort (led by W9JES), not affiliated
with HF Signals. Its GitHub pages are periodically unavailable; if the
repo is down, wait for it to come back rather than substituting a stock
Raspberry Pi OS image, because then most buttons will have nothing to
launch.

Minimum confirmed base: Raspberry Pi 4, aarch64, Debian 12 bookworm,
Python 3 with Flask 2.2.

## Bootstrap

After flashing the drexjj image, these have to be installed before the
launcher is useful. All are plain pipx installs plus systemd units.

```bash
python3 -m pipx install rns
python3 -m pipx install lxmf
python3 -m pipx install reticulum-meshchatx
```

Then create `~/.reticulum/config`, and install the units for `rnsd`,
`lxmd` and `meshchatx` under `/etc/systemd/system/`. The units are
distro-side, not launcher-side — they are not in this repo.

### modem73 must be 2.4.8 or newer

**The modem73 that ships with sBitx toolboxes does not work.** Versions
before v2.4.8 predate the audio-backend release and the CSMA fixes, and
fail against sBitx audio. Build from
[RFnexus/modem73](https://github.com/RFnexus/modem73) at **v2.4.8+**:

```bash
git clone https://github.com/RFnexus/modem73.git
cd modem73 && git checkout v2.4.8
make -j4 && sudo make install
```

Confirm the build by checking `make` reports `BASE_VERSION` 2.4.8 or
higher before installing. Older builds report `MODEM73 build <date>` with
no `--audio-backend` option.

**One binary, multiple configs.** v2.4.8+ takes `--config FILE` and loads
key=value settings from that file, with explicit command-line flags
winning over the file. So a single `modem73` binary serves every setup —
point each launcher row at a different config instead of shipping
separately built binaries:

```bash
modem73 --config ~/.config/modem73/settings
modem73 --config ~/.config/modem73-digirig/settings \
        --port 8003 --control-port 8074
```

Omitting the argument to `--config` falls back to
`~/.config/modem73/settings`. Do not maintain per-device binaries; keep
one install and one config file per rig.

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
  defaults target the built-in audio. 

## Prerequisites

The drexjj image provides the sBitx application, desktop and common GUI
apps. Everything else in this table is installed separately — see
[Bootstrap](#bootstrap). Items marked **optional** are not needed for the
core launcher rows.

| Category | Expected on disk | Source |
|---|---|---|
| sBitx itself | `/home/pi/sbitx` (includes `web/scripts/start_novnc_proxy.sh`) | image |
| desktop / VNC | `x11vnc`, `websockify`, `Xvfb`, `openbox`, `~/.vnc/passwd` | image |
| GUI apps | `lxterminal`, `fldigi`, `js8call`, `wsjtx`, `pavucontrol` | image |
| Python | `python3`, `flask` | image |
| Reticulum | `/home/pi/.reticulum/config`, `rnsd` | pipx |
| LXMF | `lxmd` | pipx |
| meshchatx | `meshchatx` | pipx |
| freeDV TNC | `/home/pi/.freedvtnc2.conf`, `/home/pi/freedata` | **verify on your box** |
| patmenu | `/home/pi/patmenu2` | **verify on your box** |
| modem73 | `/usr/local/bin/modem73` | build **v2.4.8+** |
| GridTracker | `gridtracker` on `PATH` | **optional** |

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
