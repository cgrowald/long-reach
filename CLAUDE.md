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
data/       game data (materials.json, ...)
docs/       design doc
tactical/   3D mission layer (main scene, camera/, units/)
sim/        (M2+) pure rules
world/      (M7+) strategic layer
people/     (M6+) roster, training
ui/         shared UI
```

## Status
- M0 (setup, gray-box map, free cam + lock-on, pause) - built, passes headless smoke test, awaiting user playtest.
