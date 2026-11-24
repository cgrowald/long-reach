# The debug shell (v2 build 1, 2026-11-21)

*The whole barebones game, in the v2 look, where every place opens and every control works, but nothing pushes the game forward yet. We build the feel first, then drop the real systems in one at a time.*

## Decided (user, 2026-11-21)
- **Look:** v2 (White Knuckle): low-poly Blender garage, low resolution, dithered, one hard light per area.
- **Approach:** the garage is the hub. You sit in a swivel chair, turn between four walls, and lean into stations.
- **Sound:** placeholders (the Kenney interface clicks already in the repo, plus a generated room hum). Kenney Impact Sounds (CC0, art/audio/kenney_impact/, downloaded 2026-11-24 with the user's OK): footsteps on concrete and carpet in the garage, wood and metal knocks when you use a station (stations.json "touch"); its metal, plate, punch and soft impacts are there for readable hits in combat.
- **Late game:** the war room is in, as a placeholder. You reach it through a locked floor hatch or from the PC.
- **Saves:** real saves from day one: three slots plus an autosave every night.
- **Everything a normal game has:** title screen, settings, pause menu, save and load, transitions, a debug overlay.

## What's in it
| Place | Where | Placeholder behaviour |
|---|---|---|
| Title screen | 3D garage behind a pixel menu | Continue, New game, Load, Settings, Quit |
| Settings | Title + pause | Volumes, fullscreen, vsync, pixel size, mouse look, FOV, screen shake |
| Pause | Esc | Resume, Save, Load, Settings, Main menu, Quit |
| PC (HEARTH OS) | Desk | Mail, Market, Nod, Map, War room link (locked), all with dummy content |
| Hack rig | Desk | A job: a target network, a hand of dummy cards, CHIPS x MULT, the SEND lever, a loot card. Nothing is kept |
| Phone | Desk | Messages from people |
| Hacking bench | East wall | A short solder stub minigame |
| Gun bench, forgery desk | East / west | Locked: "buy the kit" |
| Corkboard (the hunt) | West wall | Inspector, suspect pool, pinned facts (debug values) |
| Clipboard | West wall | Today's rule, hours left, needs |
| Floor hatch | West floor | War room (locked; debug unlock): map table, squads, send-away, big op (combat prototype) |
| Roller door | South | "Going out" walled off with placeholder text |
| House door | South | Go inside: sleep, the night ledger, autosave, next morning |
| Events | Debug keys | Raid warning + scramble stub, prison / game over |

## Build 2: the bench engine (2026-11-22)
- **Four working benches:** med table (north wall, left of the desk), sewing table (south wall, between the doors), gun bench (tarp off), hacking bench. The forgery desk stays locked.
- **Recipes** are in `data/v2/recipes.json`:
  - tier 1: torn-shirt bandage, shopping-bag rig, rough upper (part), port scanner (gadget);
  - tier 2 (unlocks after a 3-star tier 1): field dressing, webbing chest rig.
- **Making one:** pick a recipe, and the camera glides down onto the bench top. You do each step by hand in 3D: drill, file, cut, sew, tear, pour, fit, solder (`v2/world/verbs.gd`). Each step scores. The result rolls up as STEPS x TOOL x MATERIAL = QUALITY, then the stars slam in, with perks and the rig grid.
- **Mastery:** 3 good crafts unlock Batch (your average quality, capped at 4 stars, half the hours).
- **The stash:** the shelves (west wall, by the corner) list materials, tools and everything you made. It all saves.
- **Debug (F1):** +5 materials, Master recipes.
- **Code:**
  - `v2/sim/crafting.gd`: the rules;
  - `v2/world/bench_work.gd`: the 3D work area;
  - `v2/stations/bench.gd`: the list, the craft flow and the result;
  - `v2/stations/stash.gd`.

## The day
Cover job ends at 18:00, so you have until 02:00 (8 hours). Every station action costs hours (in `data/v2/stations.json`). Out of hours = go to bed. Night = the ledger (dummy Bureau moves), autosave, next day's rule card.

## Code map
- `v2/game.gd` (autoload `Game`): state, settings, saves, sound, scene changes with fades.
- `v2/sim/`: game_state, save_store, settings, content (JSON loader). No nodes.
- `v2/world/`: the 3D garage (load the glb, grit materials, lights, camera, picking, dither).
- `v2/ui/`: pixel view, HUD, hands, menus, panels, debug overlay.
- `v2/stations/`: one script per station screen.
- `data/v2/`: stations, rules, ledger, cards, messages, apps, inspector.
- `art/src/make_garage_v2.py` makes `art/garage_v2.glb` and `art/src/garage_v2.blend`.
- The two old toys stay reachable from the debug overlay as reference.
