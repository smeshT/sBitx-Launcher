# Using the launcher

A plain-language guide. No Linux knowledge needed.

The launcher is a web page full of buttons. Each button starts or stops
one of the radio programs on your sBitx, so you don't have to type
anything into a terminal.

---

## Opening the launcher

### If the radio is on your home wifi

1. Turn on the sBitx. Give it a minute to boot.
2. On the phone, tablet, or laptop you want to use, connect to the
   **same wifi network** the radio is on.
3. Open a web browser.
4. In the address bar at the top, type:

   ```
   http://sbitx.local:8090
   ```

5. Press Enter. The launcher appears.

`sbitx.local` is the radio's name on the network. If that address
doesn't load after a couple of tries, use the fallback below.

### The fallback: finding the radio's IP address

Every device on a network has an "IP address" — four numbers separated
by dots, something like `192.168.1.196`. Some networks don't pass the
friendly `.local` name along, so you need the numbers instead.

**Easiest method — ask the router.** Almost every home router has a web
page listing everything connected to it.

1. Look at the sticker on the router, or the card that came with it. It
   will list an address like `192.168.1.1` or `192.168.0.1`, plus an
   admin username and password.
2. Type that address into your browser and log in.
3. Find the page called **Connected Devices**, **Client List**,
   **Attached Devices**, or **DHCP Clients** — the name varies by brand.
4. Look down the list for a device named **sbitx** or **raspberrypi**.
   The IP address is written next to it.
5. Type that address into your browser with the port on the end:

   ```
   http://192.168.1.196:8090
   ```

   (Replace the numbers with whatever your router showed.)

**Alternative — from a laptop already connected.** If you have a
Windows PC on the same wifi, open the Start menu and type `cmd`, then
press Enter. In the black window type `ping sbitx.local` and press
Enter. The reply shows the address it reached.

### If the radio is in access-point mode

The sBitx can broadcast its own wifi network, usually named something
like `sbitx` or `digipi`. Join that network from your phone or laptop.
Then the address is normally `http://10.3.141.1:8090`. If that doesn't
work, try `http://192.168.50.1:8090`.

### Once it works, save it

Bookmark the page. Typing the address every time is unnecessary — in
most browsers, tap the menu and choose **Add to Home Screen** or
**Bookmark**, and it becomes a one-tap icon.

---

## What the buttons do

The page has a row for each program. Rows look like this:

| Button | Colour | What it does |
|---|---|---|
| **Start** | blue | Starts the program in the background on the radio |
| **Stop** | red | Stops that program |
| **Open** | blue | Opens a new browser tab for that program |
| **Start** | green | Starts the FreeDV modem inside Reticulum (special case, see below) |

### The blue Start button — runs a program invisibly

Blue **Start** launches the program on the radio itself. Most of these
programs have no window of their own that you can see from your
browser — they just run. Once running, the status pill at the top of
the page changes from red *Stopped* to green *Running*.

### The blue Open button — opens the program's own page

Some programs have their own web page instead of a window. Blue
**Open** sends you straight to it in a new browser tab. These are:

| Program | Its own page |
|---|---|
| **freedvtnc2 Chat** | `http://<radio-address>:8091` |
| **Pat Menu** | `http://<radio-address>:5000` |
| **MeshChat** | `http://<radio-address>:8000` |
| **sBitx radio** | `https://<radio-address>:8443` — note **https**, and your browser will warn about the certificate. That warning is expected. Choose "Advanced" then "Proceed". |

`<radio-address>` means whatever address you typed to reach the
launcher — the same one, just with a different number on the end.

### The green Start button — the FreeDV modem

One row, **freedvtnc2 modem**, has a **green** Start button. It is not a
program window. It switches the FreeDV audio modem *on inside
Reticulum*, the radio's messaging system, and restarts Reticulum so the
change takes hold.

Green here means "changes the radio's network configuration" rather than
"starts an app". Pressing it takes about fifteen seconds and will stop
JS8Call, WSJT-X, and FLDigi if they are running, because those programs
and FreeDV cannot both use the sound card at the same time.

### The Open VNC Tab button — the radio's actual desktop

The first row on the page is **Open VNC Tab**. This one is different
from the others, and it is the one people find most confusing, so:

**Open VNC Tab opens a window showing the radio's own computer
desktop.** Not a web page built by the program — the real desktop, the
same thing you would see if you plugged a monitor into the Raspberry Pi.
You can click icons on it, drag windows around, and type into it.

This matters because **several of the programs in the list below have
no web page of their own**. JS8Call, FLDigi, WSJT-X, GridTracker,
Pavucontrol, and the Modem73 configuration screen are ordinary desktop
programs. They have no address to browse to.

So the workflow for those is two steps:

1. Click blue **Start** on the program's row. The program launches on
   the radio's desktop.
2. Click blue **Open** on the **Open VNC Tab** row. A new browser window
   appears showing that desktop — and your program is sitting there,
   ready to use.

If you click Open VNC Tab and see an empty desktop, it means the program
hasn't been started yet. Go back to the launcher tab and press Start
first.

Keep the VNC window open while you use those programs. Closing it does
not stop them, but you won't be able to see or control them until you
open it again.

### Rows that are always running

A few things should always be running and don't need starting:

- **sBitx radio** — the radio software itself. Everything else assumes
  it is running. If audio stops or the radio stops responding, press
  **Restart** on this row and wait about ten seconds.
- **MeshChat / Reticulum** — the messaging stack. **Restart** here
  bounces the whole thing, including the FreeDV modem.
- **Modem73** — the OFDM data modem. Press **Start** to open its
  configuration screen on the VNC desktop. **Reset Audio** is the
  repair button: use it if you have unplugged or moved a USB sound
  device and the modem can no longer find its sound card.

### Reboot Pi

The last row restarts the whole computer. It asks for confirmation
first, because it disconnects everything — the launcher, VNC, and any
radio session in progress. Give it a full minute before trying to
reconnect.

---

## The status pills at the top

The strip across the top shows the state of each thing:

| Colour | Meaning |
|---|---|
| Green | Running |
| Red | Stopped |
| Amber | Running but not fully ready (for example, FreeDV is up but no mode is selected) |

On a freshly booted radio, several pills are red. That is normal —
those programs start on demand when you press their Start button.

---

## Things that surprise people

**Two programs can't share the sound card.** JS8Call, WSJT-X, FLDigi,
and the FreeDV modem all want the same audio device. Starting one while
another is running usually results in silence or an error. Stop the one
you were using first.

**Nothing happens when I press Start.** Give it a few seconds and
reload the page — the pill at the top is the real answer, not whether a
window appeared. Several programs take ten seconds to come up.

**The page loads but buttons don't work.** You are probably looking at
an older copy of the page. Reload it with Ctrl+F5 on a laptop, or pull
down to refresh on a phone.

**The launcher is on port 8090.** If you can reach `http://sbitx.local`
but the page doesn't appear, you probably left the `:8090` off the end.
Ports are the number after the colon — the address alone goes somewhere
else.

**It works on the laptop but not the phone.** Both devices must be on
the same wifi. A phone on mobile data cannot reach the radio.

---

## Quick reference

| What you want | What to do |
|---|---|
| Open the launcher | `http://sbitx.local:8090` |
| Can't find the radio | Log into your router, look for **sbitx** in its device list |
| Start JS8Call, FLDigi, WSJT-X, GridTracker, Pavucontrol, Modem73 | Blue **Start**, then **Open** on the **Open VNC Tab** row |
| FreeDV chat | Blue **Start** on **freedvtnc2 modem**, then blue **Open** on **freedvtnc2 Chat** |
| MeshChat / radio messaging | Blue **Open** on **MeshChat** (`:8000`) |
| Winlink / Pat | Blue **Start** on **Pat Menu**, then **Open** (`:5000`) |
| The radio's own control page | Blue **Open** on **sBitx radio** (`https://…:8443`) |
| Sound has stopped working | **Restart** on **sBitx radio** |
| Modem can't find its sound device | **Reset Audio** on the **Modem73** row |
| Start completely fresh | **Reboot Pi**, wait one minute |
