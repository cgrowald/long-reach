# Uprising (working title; repo "long-reach") - notes for Claude

Underground resistance game: a reluctant parent in a generated country builds a movement from nothing (laptop, workbench, cells) into an army that storms the capital. **Read `docs/HISTORY.md` and `docs/CORE_LOOP.md` first (the current loop, 2026-11-21 restart), then `docs/RESTART.md`; `docs/GAME_DESIGN.md` (source of truth; update its Decisions Log on every user decision). Also: `docs/OPEN_PC_AND_ECONOMY.md` (the open PC, market, gadgets, benches, heat, economy, gaps: NEXT BUILD), `docs/COMBAT_PROTOTYPE.md` (watch-and-decide), `docs/PROOF_AND_INTEL.md` (the 4-path need template + the Annex hacking lab), `docs/STORY_PREMISE.md` (cast, arc, scenes the user writes), `docs/FIRST_WEEK.md` (paper playtest of the opening), `docs/TERMINAL.md` (the laptop OS). The old counter-terror game (M0-M7) is archived in `docs/archive/`; its code stays and gets reused.

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
- Godot 4.7, GDScript, Forward+. Project root = repo root. Main scene: `res://v2/title.tscn` (v2 debug shell, see docs/SHELL.md). The old build (terminal/, tactical/watch/, etc.) is tagged `v1-final`; copy pieces into v2/ only when they fit.
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
tactical/watch/   watch-and-decide combat prototype (room_graph, squad_brain, breach_panel, watch_cams, watch_main); data/watch/skills.json
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
- Combat prototype built (tactical/watch/, title screen button). Controls v2: select + right-click door = stack, breach plan panel, right-click ground = move. Garage and drone have depth of field.
- Step 1 of the PC rebuild DONE (docs/OPEN_PC_AND_ECONOMY.md section 9): sandbox mode (New game), generated town (sim/world_gen.gd), systemic messages, Market, Workshop, Nod, Map, generated web pages, drab HEARTH GNU/State look. Data in data/os/. The scripted T1 week (story mode) stays only for the old tests.
- NEXT steps: 2 = hours-per-day time + going out (town map POIs, short hands-on scenes); 3 = bench minigames (hacking table first: assemble, solder, flash); 4 = Nod followers payoffs + Bureau levels, warnings, raid scramble.
- 2026-11-21 later: **debug shell built** (docs/SHELL.md). Main scene is now `res://v2/title.tscn`. Autoload `Game` (v2/game.gd) holds state, settings, saves (user://saves_v2, 3 slots + autosave), sound, fades. The garage hub (v2/garage.gd + v2/world/garage_world.gd, art/garage_v2.glb from art/src/make_garage_v2.py) with stations in v2/stations/, data in data/v2/. Everything opens; nothing pushes the game forward yet. Tests: set `save_store.gd` `dir` and `settings.gd` `path` to scratch first.
- 2026-11-22: **bench engine built** (docs/DRIVE.md design, docs/SHELL.md "Build 2"). 3D hands-on verbs in v2/world/verbs.gd, rules in v2/sim/crafting.gd, recipes in data/v2/recipes.json, stash in GameState (materials, tools, items, mastery). Next per DRIVE section 9: the rig grid, then a one-room auto-battle toy.
- 2026-11-21: RESTART (v2). docs/MARKET_RESEARCH.md + docs/RESTART.md. Two hacking minigame toys in v2/ (Packet Pit = Ball x Pit style, Breach Hand = Balatro style), sim in v2/sim/, shared pixel CRT + hack rig UI in v2/ui/. The user PLAYED both toys (2026-11-21) and rejected each as is: the hack became a card + network + combo design (RESTART section 6), then one "job" engine for every path (CORE_LOOP). Full story: docs/HISTORY.md. Do not ask the user to play the toys again.
- 2026-11-22: **HEARTH OS built** (docs/HEARTH_OS.md): the PC is a real Linux/ReactOS/Unity-style desktop in `v2/os/` (boot, login, windows, taskbar, start menu search, Files, Terminal, StateNet, Mail, Notes, Software, Monitor, Preferences), content in data/v2/os.json, saved in GameState.os. The PC costs no time. User decisions 2026-11-22: mouse first with a commands note, the desk hack machine = the external box upgrades plug into, hacking = programs launched on the PC with minigames (next). Build is tagged `v2-base` (benches).
- 2026-11-22: **hacking job built** (docs/HEARTH_OS.md "Build 4"): Jobs app on the PC (v2/os/apps/jobs.gd, job.gd), rules in v2/sim/hack_job.gd (scan sonar, crack dials from the owner's life, siphon files vs one trace bar), targets in data/v2/os.json. The desk rig is now **the box** (v2/stations/box.gd): drag gadgets into SCAN/CRACK/NET slots, saved in GameState.os.box; gadgets come from the hacking bench (port scanner, wordlist drive, signal damper). Old rig card stub deleted. Combat direction recorded in docs/COMBAT_ANGLES.md section 6 ("the view is gear", named fighters with visible gear, call-ins are things you built).
- 2026-11-22: **combat slice designed** (docs/COMBAT_SLICE.md: gear = stats Tarkov-lite, finite ammo/meds, auto battle with your focus, "the view is gear", call-ins from real drone/mortar research; first op = Dobrev Freight depot, 4 named fighters, you fly the FPV). **Look test built:** `v2/combat/` (soldier.gd = segmented low-poly rig + 2-bone IK + camo painted per face from art/soldier.glb made by art/src/make_soldier.py; look_test.gd = corridor, helmet cams 1-4, CCTV 5, F fire; feedcam.gdshader; grime.gdshader). Title screen button "Combat look test". Reference images in docs/refs/combat/.
- 2026-11-22: **first fight built** (title > Combat: depot raid; docs/COMBAT_SLICE.md "Build: the first fight"): v2/combat/{rules, level, actor, squad_ai, enemy_ai, combat_audio, fight}.gd, data/v2/combat/depot.json. Doctrine auto-battle + shout wheel + feed wall + op report. Next: drones (FPV you fly, recon), loadout from the stash, link to the depot hack, real sounds, animations. User: keep the pace slow; real time with a pause that may become optional; no slow-mo; you're in the van for now.
- 2026-11-22: **commanding from the van** (docs/COMBAT_SLICE.md section 9 + "Build: commanding"): ops board (v2/combat/ops_board.gd), danger read + pushback (B = their way, same order again = overrule), drag-to-look, CCTV spotting, fluid split stacks, right-of-way movement, lights on/off by situation, slower doctrine (hold every room ~3.5 s). Polish refs for LATER only: docs/POLISH.md (do not work from them until the user says).
- 2026-11-22: **gear on your people built** (docs/RUNDOWN.md sections 8-9): data/v2/gear.json, v2/sim/loadout.gd (people, kit, rig grid, to_fighter, apply_op), GameState people/supplies, v2/stations/cage.gd (Shelves > Gear cage, 3D fighter preview), new soldier pieces (bolt action, pump shotgun, market-bag rig, chest rig, beanie, street clothes). The cage's "Send them" runs the raid with your people and returns results to the garage. Game rundown + 8 design decisions in docs/RUNDOWN.md.
- 2026-11-22: **economy core built** (docs/ECONOMY.md, sections 8-10): v2/sim/materials.gd (graded materials), v2/sim/economy.gd + data/v2/economy.json (3 random job offers, morning steal choice + suspicion/audit/fired, night actions replace hours, wages, upkeep, loyalty). The morning card in v2/ui/overlays.gd hosts the job pick and the steal choice. GameState gained job/suspicion/actions/mat_grades/etc. NEXT: hacking pass (own module), then the garage face-lift (docs/POLISH.md, user wants it soon), the easy first mission, lockpicking, people exploitation, the fixer/black market. The user's Operator clip (how he clears) was read frame by frame through Blender (no ffmpeg needed): notes in COMBAT_SLICE section 10, built with the bar mission.
- 2026-11-22 late: **text readable everywhere**: v2/ui/pixel_view.gd now renders the 3D world low-res but all UI at full resolution (UI_SCALE 2.5 units; convert clicks/markers with PixelView.to_3d / to_ui when touching a 3D camera). One font for the whole game: art/fonts/DejaVuSansMono (Pal.font(), Pal.bold()). Day-job pick = three cards (v2/ui/job_cards.gd, photos in art/jobs/). Hacking redesign in docs/HACKING.md (research, GPT's PATCHBAY/WATCHLINE/SPOOL, in-person air gaps, inject minigames A-F waiting for the user's pick); then build it with the OS face-lift (GPT's petrol/ivory/copper look). Git push works again.
- 2026-11-22 late: user picked hacking = CONNECT (PATCHBAY) + INJECT (code chain), on-site TUNE, dirt password shortcut; faces = 2D layered pixel portraits; order: hacking, then the face-lift, then bench by bench. **Built + bot-tested (no UI yet):** v2/sim/hack.gd (targets from the town, patchbay, code chain, tune, payoffs, cut-out locks, crates overnight), v2/sim/intel_market.gd (sell to the fixer / post on Nod), data/v2/hacking.json. Then built: the OS face-lift, the PATCHBAY app (v2/os/apps/patchbay.gd), DEAD DROP (v2/os/apps/drop.gd), the drop-stick recipe (docs/HACKING.md section 8). NEXT after the user plays it: the mission face-lift (FIELD LINK + procedural faces), then bench by bench.
