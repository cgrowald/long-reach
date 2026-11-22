# HEARTH OS (the PC as its own bench, 2026-11-22)

*The PC on the desk is a whole operating system that the whole country runs on: robust, everywhere, and full of bugs, bottlenecks, back doors and workarounds. It should feel like sitting at an actual PC, familiar and easy, but limited, with things you learn along the way. Everything on it serves the one goal: grow the movement.*

## Decided (user, 2026-11-22)
- **Look:** a mix of old Linux desktops (desktop icons), Ubuntu Unity (search-first app menu) and ReactOS / Windows 2000 (grey bevelled windows, Start bar, explorer), kept in our pixel style on the garage CRT. The user sent three reference screenshots.
- **Mouse first.** The terminal exists, but a few commands are always on a note you can pull up (the sticky note / Notes). Not for computer pros: you learn the PC, it stays familiar.
- **No time cost.** Using the PC is free. Only hacking missions (for dirt, data and so on) will cost time. The day timer itself is still undecided; balance later.
- **The internet** comes later and will be big: propaganda, stupid like GTA's internet, all nonsense, with easter eggs and hidden shortcuts to better gear and better contacts. This build has a handful of pages to set the tone.
- **The desk hack machine stays** as the physical box your hacking upgrades plug into. It's external, so HEARTH doesn't see it; it's how you get around the OS that blocks everything. Maybe the first thing you make in the tutorial.
- **Hacking** (next after this): programs you load and launch on the PC, each a short minigame; gadgets from the hacking bench plug into the box as multipliers.

## Build 3 (this build)
- **Boot:** BIOS text, the service list, then a login screen. The password is on the sticky note on the monitor. Boots once per session; click to skip.
- **Desktop:** wallpaper, icons (double-click to open), right-click menu, a taskbar with the HEARTH start button, quick launch, one button per window, and a tray (Notes, network, clock).
- **Windows:** drag by the title bar, double-click it to maximise, minimise / maximise / close buttons, resize from the corner. Click a window to bring it forward.
- **Start menu:** search box first (Unity), then every app; Enter launches the first match. Leave the PC from here or with Esc.
- **Apps:**
  - **Files:** back, up, home, an address bar, folders and files; text opens in Notes, pictures in the viewer.
  - **Notes:** a text editor. Your own files in /home/citizen save with the game. commands.txt is kettle's cheat sheet.
  - **Terminal:** ls, cd, cat, pwd, ps, kill, pkg, man, help, history and more. Up arrow for history, Tab to complete.
  - **StateNet:** the browser. A few state pages, the market, Nod, one hidden page.
  - **Mail:** an inbox with a reading pane.
  - **Software:** programs to install. Launching one says it needs the box (hacking comes next).
  - **Monitor:** CPU, memory and network graphs, and the process list (hearthd-telemetry eats your CPU).
  - **Preferences:** a control panel like reference 1. Appearance changes the wallpaper (saved); the rest are in-world jokes.
- **Saves:** wallpaper, installed programs and your edited files.
- **Code:** `v2/os/` (desktop, window, taskbar, start menu, icons, filesystem, apps/*), content in `data/v2/os.json`, hosted by `v2/stations/pc.gd`.

## Font (user, 2026-11-22)
- "Hard to read, a little too boxy": the OS now uses Tahoma 9 (the Windows 2000 UI font), crisp with no smoothing; the terminal and process list keep a monospace (Lucida Console). The garage HUD and benches still use the old Consolas font.

## Next build: the hacking job (decided, user 2026-11-22)
- **A short job, 3 programs,** about 3 to 5 minutes, one target (placeholder: the water office's billing server):
  1. **pscan** sweeps the target's network map for open doors.
  2. **crackle** picks a login like a lock.
  3. **grab** the files before the trace bar fills.
- **The box is 3D on the desk:** lean over, drag a gadget from the stash into a slot, a lamp lights. The programs show what's plugged in, and gadgets are the multipliers (the port scanner from the hacking bench boosts pscan).
- **Time:** a fixed number of hours per job, shown up front (e.g. 2 hours). The rest of the PC stays free.
- **Trace bar full:** you're cut out with what you grabbed so far, and the inspector gets a clue (a placeholder until the hunt is built).
