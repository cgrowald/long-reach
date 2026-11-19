# Long Reach

Covert counter-terror tactics and strategy. Built with Godot 4.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full design.

## Running
1. Install Godot 4 (Standard edition, not .NET): https://godotengine.org/download/windows/
2. Open Godot → **Import** → select `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (or the ▶ button top-right) to run.

## Controls (M2)
| Input | Action |
|---|---|
| Left click / drag box | Select operators (Shift adds) |
| Right click ground | Move selected (Shift queues a waypoint) |
| Right **drag** | Move, then face the drag direction on arrival |
| Alt + right click | Look toward that point (end of route if moving) |
| V | Toggle walk / run (walking slices the pie at doorways; running is fast but inaccurate) |
| H | Toggle hold fire |
| WASD / arrows | Pan camera |
| Q / E | Rotate camera |
| Middle mouse drag | Orbit / tilt |
| Mouse wheel | Zoom |
| Double-click / F | Follow selected operator |
| Tab | Cycle follow through operators |
| 1–4 | Select operator (Shift adds) |
| Esc | Release follow / deselect |
| Space | Pause / resume (orders work while paused) |
| R | Restart mission |

Operators fire automatically at any hostile inside their vision cone, once they have turned onto it.
Hostiles are hidden (fog of war) until one of your operators can see them.
