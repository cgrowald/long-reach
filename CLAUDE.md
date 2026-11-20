# Uprising (working title; repo still "long-reach") - notes for Claude

Underground resistance strategy game: start from nothing in a generated country, build cells, grow into an army, storm the capital (Antistasi-like, with a terminal, HOI-style map + text events, and missions where they matter). The counter-terror version (M0-M7) is archived in `docs/archive/`; its code is being reused. **Read `docs/GAME_DESIGN.md` first**: it is the source of truth for what the game is, the design pillars, and the milestone roadmap. Update its Decisions Log when the user makes a design decision.

## Working with the user
- The user does not write code. They direct, playtest, and make design calls. Claude writes all code.
- Do as much as possible without asking. Bring the user in only for playtesting feedback, design decisions, and things that need their accounts.
- Every milestone must end playable. Tell the user exactly what to try when testing.

## Tech
- Godot 4.7, GDScript, Forward+ renderer. Project root = repo root.
- Start scene: `res://world/campaign_map.tscn` (campaign map; HQ `res://hq/hq.tscn` is reached from it). Mission scene: `res://tactical/main.tscn` (runs standalone with a test squad when nothing is deployed).
- Autoload `Campaign` (people/campaign.gd) owns the roster + save (`user://campaign.json`). TESTS MUST set `Campaign.save_path` to a test file before writing, never touch the user's save.
- Godot exe (use the `_console` one for headless runs):
  `C:\Users\Chandler\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`
- Smoke test: `<godot> --headless --path . --quit-after 120` and check output for `ERROR` / `SCRIPT ERROR`.
  For behaviour checks, write a throwaway `extends SceneTree` script and run it with `--script <path>`.
- Blender 5.3 (scriptable, for generating/converting low-poly models; export `.glb` into `art/`):
  `C:\Program Files\Blender Foundation\Blender 5.3\blender.exe --background --factory-startup --python <script.py>`
  Blender 5.2 LTS is also installed (the user's own); use 5.3.
- PowerShell 5.1 gotcha: `Get-Content`/`Set-Content` mangle UTF-8. Use the Write/Edit tools or `[IO.File]` APIs for file edits.

## Architecture rules (from the design doc - don't break these)
1. **Simulation separate from presentation.** Rules (ballistics, AI, world sim) live in `sim/` and must not depend on meshes/animations.
2. **Data-driven.** Weapons, materials, calibers, agencies, templates go in `data/` (JSON or `.tres`), never hard-coded in scripts.
3. **One tactical engine** for every mission type (raid, rescue, covert are configurations).
4. **Everything persistent is serializable** (roster, world, network).
5. **Debug overlays** for LOS, exposure, penetration, AI state.

## Code style
- Statically typed GDScript (`var x: int`, `-> void`). Tabs for indentation.
- Use `preload` consts for script types (`const Operator := preload(...)`) instead of relying on `class_name` cache.
- Small focused scripts; one responsibility each.

## Git
- Repo: https://github.com/cgrowald/long-reach (private). Branch `main`.
- Commit identity is repo-local (`cgrowald` + GitHub noreply email). Never use the user's personal email.

## Layout
```
data/                 game data: materials, weapons, unit_types (JSON)
docs/                 design doc
sim/                  pure rules: game_data.gd (JSON loader), combat_rules.gd, world_sim.gd (campaign map state + weekly enemy phase), network.gd (enemy people/cells graph, intel, raids)
tactical/main.gd      mission orchestration, HUD, win/lose
tactical/level/       test_map.gd (gray-box map + spawns), nav_builder.gd (runtime navmesh bake)
tactical/units/       unit.gd (both teams: pathing, spotting, shooting, damage)
tactical/control/     selection_controller.gd (select, box select, move orders)
tactical/camera/      camera_rig.gd
tactical/ui/          squad_panel, path_overlay, selection_box
tactical/fx/          tracers, move markers
people/               research (projects, status, effects), operator_record, recruiter, roster (calendar + save), portrait (procedural pixel faces), campaign (autoload: deploy, results, AAR data)
hq/                   hq.gd (roster, detail, memorial, recruit, squad + deploy), aar.gd (after-action report)
world/                network_board.gd (org chart of the enemy), campaign_end.gd (victory/defeat screen),
                      world/                campaign_map.gd (main screen), map_view.gd (vector map: zoom/pan, glow coasts, badges, carrier, clicks), map_geo.gd (smoothed coastlines, regions = areas clipped to coast, Miller projection), ui_theme.gd (Bahnschrift font + button styles for map/HQ/AAR)
```

## Testing
- Commit Godot's `*.gd.uid` files alongside scripts.
- Units are not physics bodies; LOS raycasts use collision layer 1 (walls/cover only).
- Battle regression: script that instantiates main.tscn, selects all friendlies, issues moves via
  `_selection._issue_move(...)`, runs at `Engine.time_scale = 4`, reports `mission_over` / survivors.
- Screenshots: run Godot *without* `--headless` plus `--resolution 1600x900`, save
  `root.get_viewport().get_texture().get_image()` to the scratchpad, then view it.

## Status
- M0 done (user playtested 2026-11-19, all working).
- M1 done (user playtested 2026-11-19).
- User wants realistic CQB mechanics fully right before anything else (see design doc M2-M3c).
- M2, M3 done. User: tactical only needs to be good enough; real interest is characters, research, campaign map.
- MOUSE RULE (user decision): LEFT = feet (move, draw routes, select), RIGHT = eyes (look, watch points; Shift+right = pie with dotted line + pie icon), right click on door/soldier = action wheel.
- CONTROL RULE: only seeing and shooting are automatic. Every other action is an explicit order (action wheel). Never add automatic door opening, crouching, pie-slicing etc.
- M3.5 classes + action wheel; M3.6 freehand route drawing + focus points along routes; M3.7 pie maneuver (Shift+left-click ground: arc around a corner, weapon up) + raised/low-ready rifle poses - built and tested, awaiting user playtest. 
- UI gotcha: a Control whose parent is a CanvasLayer is NOT sized by full-rect anchors; set position/size from get_viewport_rect() or it gets zero size and no mouse input.
- Simulated mouse input (root.push_input) only maps correctly in a windowed run, not --headless.
- In test scripts count time with _physics_process (60/s game time); _process frame counts depend on FPS.
- M4 characters (first slice) built and tested: persistent roster, HQ, memorial, deploy, stats affect missions, AAR with wounds/permanent injuries/growth/traits/service record. Awaiting user playtest.
- M5 research (first slice) built and tested: funding (weekly budget, success bonus, recruit cost), research tab, one lab project at a time, Stand down 1 week, tech effects in missions (optics, plates, suppressors = shot noise, frame charges, trauma kits, heartbeat sensor with through-wall blips + HEARTBEAT tags). Data: data/research.json. Logic: people/research.gd.
- M6 campaign map (first slice) built and tested, awaiting user playtest: see design doc 4.4 "as built". Data: data/regions.json (regions, sea zones, theaters, cell types, tuning rules), data/world_land.json (hand-drawn coastline polygons, must stay non-self-intersecting), data/region_areas.json (region border areas + city positions). User declined downloading Natural Earth data; geography is hand-authored. Campaign autoload holds `world` + `current_op` (saved in the same JSON; old saves get a fresh map). Balance was tuned with a headless 52-week simulation (idle vs. active player); rerun something similar after changing the rules.
- M7 enemy network (first slice) built and tested 2026-11-20, awaiting user playtest: see design doc 5 "M7 first slice as built". Data: data/network.json. User said the game is "not fun" yet and asked for more content before giving detailed feedback: keep adding systems, then ask what feels wrong. Campaign win (Emir down) / loss (threat 90+ for 4 weeks) are provisional. Old saves keep the roster but get a fresh map. Balance sim: idle vs. bot player, rerun after rule changes.
- 2026-11-20 GAME SWITCHED (user): see the new docs/GAME_DESIGN.md. Everything above this line describes the old counter-terror build; its code is reusable (tactical engine, people, portraits, network sim to invert, map drawing). PLANNING PHASE: the user wants the full design settled before any milestone starts; do not start U1 until they say so. U1 = you and your world (character creation, circle, the room, day loop). Old counter-terror screens get replaced as U-milestones land.
- Long silent runs (battle regressions, screenshots): tell the user first, or run in background.
