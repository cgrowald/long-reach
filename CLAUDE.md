# Long Reach - notes for Claude

Covert counter-terror tactics + strategy game. **Read `docs/GAME_DESIGN.md` first**: it is the source of truth for what the game is, the design pillars, and the milestone roadmap. Update its Decisions Log when the user makes a design decision.

## Working with the user
- The user does not write code. They direct, playtest, and make design calls. Claude writes all code.
- Do as much as possible without asking. Bring the user in only for playtesting feedback, design decisions, and things that need their accounts.
- Every milestone must end playable. Tell the user exactly what to try when testing.

## Tech
- Godot 4.7, GDScript, Forward+ renderer. Project root = repo root.
- Main scene: `res://tactical/main.tscn`.
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
sim/                  pure rules: game_data.gd (JSON loader), combat_rules.gd
tactical/main.gd      mission orchestration, HUD, win/lose
tactical/level/       test_map.gd (gray-box map + spawns), nav_builder.gd (runtime navmesh bake)
tactical/units/       unit.gd (both teams: pathing, spotting, shooting, damage)
tactical/control/     selection_controller.gd (select, box select, move orders)
tactical/camera/      camera_rig.gd
tactical/ui/          squad_panel, path_overlay, selection_box
tactical/fx/          tracers, move markers
world/ people/        (later milestones)
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
- M1 (move orders, pathfinding, auto-combat, squad panel, win/lose, restart) - built, battle-tested headless, awaiting user playtest.
