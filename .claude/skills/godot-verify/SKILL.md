---
name: godot-verify
description: How to check Godot changes in this project - smoke test, headless behaviour scripts, windowed screenshots. Use after writing or changing GDScript/scenes and before telling the user something works.
---

# Verifying changes in this Godot project

Godot console exe (headless): `C:/Users/Chandler/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe`
Windowed exe (screenshots): `C:/Users/Chandler/Tools/Godot/Godot_v4.7.2-stable_win64.exe`
Write throwaway scripts into the session scratchpad, never into the repo.

## 1. New scripts: generate .uid files
`<console> --headless --path . --import` (then commit the new `*.gd.uid`).

## 2. Smoke test
`<console> --headless --path . --quit-after 120 2>&1 | grep -E "ERROR|SCRIPT ERROR|Parse Error" `
Also smoke a specific scene: add the scene path after `--path .`.
No output = clean.

## 3. Behaviour checks
Write an `extends SceneTree` script, run with `<console> --headless --path . --script <file>`.
- Do work in `_physics_process` (60 ticks/s game time) or `_process`; return `true` to quit.
- Change scenes with `change_scene_to_file`; grab `current_scene` a few frames later.
- Point every save path at a test file first (`Campaign.save_path`, TerminalState save path) and delete it at the end. Never touch the user's saves.
- Print clear PASS/FAIL lines and read them.

## 4. Screenshots (look at the result yourself)
Run the windowed exe with `--path . --resolution 1600x900 --script <file>`; after the UI settles (~20 frames)
`root.get_viewport().get_texture().get_image().save_png("<scratchpad>/name.png")`, then Read the PNG.
Simulated clicks (`root.push_input`) only map correctly in windowed runs.
Tell the user before long runs; run them in the background.

## 5. Before reporting
State what was verified and what was not (feel, fun and audio can only be judged by the user playing).
