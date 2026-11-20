# Long Reach

Covert counter-terror tactics and strategy. Built with Godot 4.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full design.

## Running
1. Install Godot 4 (Standard edition, not .NET): https://godotengine.org/download/windows/
2. Open Godot → **Import** → select `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (or the ▶ button top-right) to run.

## Controls (M3.5)
Only seeing and shooting are automatic. Everything else is an order you give.

| Input | Action |
|---|---|
| Left click / drag box | Select operators (Shift adds) |
| Right click ground | Move (Shift = queue waypoint, Ctrl = move and wait for GO) |
| Right **drag** | Move, then face the drag direction |
| Right click a **door** | Door wheel: Open, Kick, Breach charge, Open + flash, Kick + flash, Stack up (open doors: Flash in, Frag in). Hold Ctrl to do it on GO, Shift to queue it |
| Right click a **soldier** | Soldier wheel: Crouch/Stand, Walk/Run, Hold fire/Weapons free, Flashbang, Frag, Stop |
| Alt + right click | Look toward a point |
| Enter | GO: waiting soldiers continue, armed breach charges blow |
| Space | Pause (plan everything while paused) |
| - / = | Game speed 0.25x to 2x |
| P | Pixel look on/off |
| WASD, Q/E, wheel, middle-drag | Camera |
| F / Tab / double-click | Follow a soldier |
| 1-4 | Select soldier |
| Esc | Cancel / clear selection |
| R | Restart mission |

Soldiers stop at closed doors until you order the door opened. Classes decide the options:
Assaulter (rifle, flashbangs, frag), Breacher (shotgun, breach charges), Marksman (long rifle, no kicking).