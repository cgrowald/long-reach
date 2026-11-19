# Long Reach â€” notes for Claude

Covert counter-terror tactics + strategy game. **Read `docs/GAME_DESIGN.md` first**: it is the source of truth for what the game is, the design pillars, and the milestone roadmap. Update its Decisions Log when the user makes a design decision.

## Working with the user
- The user does not write code. They direct, playtest, and make design calls. Claude writes all code.
- Do as much as possible without asking. Bring the user in only for playtesting feedback, design decisions, and things that need their accounts.
- Every milestone must end playable. Tell the user exactly what to try when testing.

## Tech
- Godot 4 (4.5+), GDScript, Forward+ renderer. Project root = repo root.
- Main scene: `res://tactical/main.tscn`.
- Run headless smoke test (Godot must be on PATH or use full exe path):
  `godot --headless --path . --quit-after 120` and check the output for `ERROR` / `SCRIPT ERROR`.

## Architecture rules (from the design doc â€” don't break these)
1. **Simulation separate from presentation.** Rules (ballistics, AI, world sim) live in `sim/` and must not depend on meshes/animations.
2. **Data-driven.** Weapons, materials, calibers, agencies, templates go in `data/` (JSON or `.tres`), never hard-coded in scripts.
3. **One tactical engine** for every mission type (raid, rescue, covert are configurations).
4. **Everything persistent is serializable** (roster, world, network).
5. **Debug overlays** for LOS, exposure, penetration, AI state.

## Code style
- Statically typed GDScript (`var x: int`, `-> void`). Tabs for indentation.
- Use `preload` consts for script types (`const Operator := preload(...)`) instead of relying on `class_name` cache.
- Small focused scripts; one responsibility each.

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
- M0 (setup, gray-box map, free cam + lock-on, pause) â€” built, awaiting first run.
