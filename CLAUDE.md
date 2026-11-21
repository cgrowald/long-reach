# Uprising (working title; repo "long-reach") - notes for Claude

Underground resistance game: a reluctant parent in a generated country builds a movement from nothing (laptop, workbench, cells) into an army that storms the capital. **Read `docs/GAME_DESIGN.md` first** (source of truth; update its Decisions Log on every user decision). Also: `docs/COMBAT_PROTOTYPE.md` (watch-and-decide plan, next build), `docs/PROOF_AND_INTEL.md` (the 4-path need template + the Annex hacking lab), `docs/STORY_PREMISE.md` (cast, arc, scenes the user writes), `docs/FIRST_WEEK.md` (paper playtest of the opening), `docs/TERMINAL.md` (the laptop OS). The old counter-terror game (M0-M7) is archived in `docs/archive/`; its code stays and gets reused.

## Working with the user
- The user does not write code. They direct, playtest, and make design calls. Claude writes all code.
- Do as much as possible without asking, BUT before each milestone **list the gaps you will run into and ask** (user request 2026-11-20): things an LLM tends to gloss over (saves, pacing, tone limits, audio/art sourcing, what "fun" means minute to minute).
- Plan before building: the user wants the full picture first. Every milestone ends playable; tell the user exactly what to try.
- Cybersecurity in the game is fully gamified: fun toys and learnable "angles", never real procedures. Same for weapon building (stylized minigames).
- Old counter-terror code: delete each part once its replacement exists (user 2026-11-20).
- Art: Claude makes Blender models, the user tweaks them (docs/ART_GUIDE.md). Ask the user for reference screenshots before deciding a look.
- The user writes some of the story text (docs/WRITING_GUIDE.md): keep all text in data/ JSON, never overwrite user-written text without asking, check `git log` on data files before rewriting them.
- Shared brain: the user's Obsidian vault `C:\Users\Chandler\Documents\Obsidian\Second Brain`, folder `05 Projects/Uprising Game/`. Append the user's new ideas to `Uprising - Running Thoughts.md` (dated, short bullets, no em/en dashes) and refresh the README's status and space-usage line.
- Downloads need explicit user permission. Never kill the user's Godot editor. Warn before long silent runs.

## Tech
- Godot 4.7, GDScript, Forward+. Project root = repo root. Main scene: `res://terminal/terminal.tscn` (T1 prototype).
- Godot exe: `C:\Users\Chandler\Tools\Godot\Godot_v4.7.2-stable_win64.exe` (`_console` variant for headless runs).
- Blender 5.3 for generated low-poly models: `C:\Program Files\Blender Foundation\Blender 5.3\blender.exe --background --factory-startup --python <script.py>`.
- How to test (smoke runs, behaviour scripts, screenshots): see the `godot-verify` skill in `.claude/skills/`.
- Saves: tests MUST point save paths (`Campaign.save_path`, `TerminalState` save path) at test files, never the user's `user://` saves.
- PowerShell 5.1 mangles UTF-8 with Get-Content/Set-Content: use Write/Edit tools. Bash heredocs with apostrophes fail in this harness: write scratch files with the Write tool.

## Architecture rules
1. **Simulation separate from presentation.** Rules and state in `sim/` (no nodes/meshes); UI in scenes.
2. **Data-driven.** Content (days, messages, sites, files, rules, events) in `data/` JSON, never hard-coded.
3. **One tactical engine** for every mission type.
4. **Everything persistent is serializable.**
5. **Debug overlays/keys** for hidden state (exposure, flags).

## Code style
- Statically typed GDScript (`var x: int`, `-> void`), tabs.
- `preload` consts for script types instead of `class_name`.
- Small focused scripts. Commit `*.gd.uid` files (generate with `--headless --import`).

## Git
- Repo https://github.com/cgrowald/long-reach (private), branch `main`. Repo-local identity `cgrowald` + noreply email; never the personal email.

## Layout
```
docs/        GAME_DESIGN.md, FIRST_WEEK.md, TERMINAL.md, archive/ (counter-terror docs + old notes)
terminal/    the garage + laptop: terminal.gd (flow, HUD, OS viewport), room3d.gd (3D garage, views, picking), desktop, window frame, apps/*
art/         garage.glb (loaded) + audio/; art/src/ (.gdignore) holds make_garage.py and garage.blend
sim/         terminal_state.gd (laptop/game state), lab_state.gd (hacking lab engine), loot.gd (rarity drops), plus old counter-terror rules (network.gd to invert later)
data/terminal/  T1 content: days, contacts/conversations, sites, files, shell
people/ hq/ world/ tactical/   old counter-terror code (portraits, roster, map drawing, tactical engine) to reuse
```

## Gotchas
- A Control whose parent is a CanvasLayer is NOT sized by full-rect anchors; size it from get_viewport_rect().
- Simulated mouse input (root.push_input) only maps correctly in a windowed run, not --headless.
- In test scripts count time with _physics_process (60/s).

## Status
- 2026-11-20: game switched to the uprising design; planning done for the opening. Building **T1: the terminal on its own** (docs/TERMINAL.md section 6). Old counter-terror screens are no longer the main scene.
- T2a built: 3D garage around the laptop (placeholder Blender models, four views, clickable objects, lean in/out). Godot has Blender import disabled; .blend files live in art/src/ which Godot ignores.
- T3 built: the Annex hacking lab in the Probe app (data/labs/annex.json, data/loot.json). Unlocked on night 4 via kettle's forum thread. The night clock pauses during labs; each command costs minutes.
- 2026-11-20 late: design core rewritten (GAME_DESIGN section 0: op loop, three ways to run an op, watch-and-decide combat, op report, two economies, named legends + numbers, multiple win paths). Next build: the combat prototype (docs/COMBAT_PROTOTYPE.md), after the user answers its gap questions. The old tactical engine is NOT dead: it gets reused for this.
