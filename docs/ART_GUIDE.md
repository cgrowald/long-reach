# Art guide: making the generated models yours

*Claude builds the low-poly models with Blender scripts. They will look "programmer-made" in predictable ways. This guide lists those tells and how you fix them in Blender, so the final look is yours. Share reference screenshots of games or art you like; they decide the palette and the mood.*

---

## 1. Why generated models look generated (the tells)

| Tell | Why it happens | What fixes it |
|---|---|---|
| **Perfect shapes** | Scripts make exact cubes, cylinders and spheres with perfectly straight edges | Nudge vertices, tilt, sag, dent things: real objects are worn and a little crooked |
| **Everything lines up** | Scripts place objects on a grid at clean angles | Rotate props a few degrees, shift them off-center, overlap a little: the room should look *used* |
| **Uniform colors** | One flat color per object | Color variation: darker in corners and crevices, lighter on edges, stains, a second tone |
| **Same size, same spacing** | Copies of the same object | Vary scale (90-110%), mix sizes, break repetition |
| **No story** | Scripts place what's on the list | Clutter that says who lives here: a kid's drawing taped up, a coffee ring, Pavel's jacket on a hook |
| **Random palette** | Colors picked one by one | A limited palette (8-16 colors) picked from your reference screenshots, used everywhere |
| **Flat lighting** | Default lights | One strong warm lamp + the cold laptop glow + dark corners. Lighting sells the mood more than the models do |

The good news: the last two are cheap, and they matter most. A fixed palette plus moody lighting makes simple shapes look deliberate.

---

## 2. Your first session in Blender (about an hour)

Claude will give you a `.blend` file next to each exported `.glb` in `art/`. Work on the `.blend`; Claude re-exports it, or you use File > Export > glTF 2.0.

**Controls you need:**
- Middle mouse: orbit. Shift + middle mouse: pan. Scroll wheel: zoom.
- Click an object to select it. `Tab` switches between Object mode and **Edit mode** (vertices).
- In Edit mode: `1` / `2` / `3` = select vertices / edges / faces.
- `G` move, `R` rotate, `S` scale. Type a number after it for an exact amount (e.g. `R` `5` = rotate 5 degrees). Press `X`/`Y`/`Z` to lock to an axis.
- `O` toggles **proportional editing**: dragging one vertex also drags its neighbors softly. This is the main "make it organic" tool; scroll the wheel while dragging to change how far it spreads.
- `Ctrl+Z` undo. `Ctrl+S` save.

**Exercise: make the workbench yours.**
1. Select the bench top, `Tab` into Edit mode, turn on proportional editing (`O`), grab a corner vertex and pull it down a few millimeters: a sagging, old bench.
2. Back in Object mode, rotate the toolbox `R` `Z` `7`. Move the mug off the grid.
3. Select a leg, `S` `Z` `0.97`: the bench now wobbles.
4. Look at it from the game camera's angle (Claude will add a camera named `GameView`; select it and press `Numpad 0`).

---

## 3. Color: vertex paint and the palette

- Claude will put a **palette image** in `art/palette.png`, built from your reference screenshots. Every material should only use those colors.
- **Vertex paint** (top-left mode menu > Vertex Paint) lets you paint color directly onto the model's corners.
  - Paint corners and undersides a step darker, top edges a step lighter. This is fake ambient occlusion, and it removes the flat look immediately.
  - Add a stain, a rust patch, a faded spot where hands touch.
- Keep it chunky: we render at low resolution with hard pixel edges, so small details vanish. Big, clear shapes and color blocks read best.

---

## 4. Silhouette and story

- Squint at the screen. If you can't tell what an object is from its dark outline, exaggerate its shape: a bigger handle, a fatter lamp shade.
- Every room tells who lives there. For the garage:
  - Lena's bike;
  - Mira's gardening gloves;
  - Pavel's box;
  - a calendar with the Marshal on it;
  - an oil stain;
  - the window to Bruno's house.

  Tell Claude the story bits and Claude adds rough versions for you to shape.

---

## 5. Lighting (in Godot, Claude sets it up; you judge it)

- One warm key light (the bench lamp), the laptop's cold blue glow, deep shadows elsewhere.
- Things to tell Claude after a screenshot: "warmer", "darker corners", "the lamp should flicker", "more fog". Lighting is easy to change and changes everything.

---

## 6. Sound (later)

We start with free CC0 sound packs (each download needs your OK).

Making your own is very doable:
- record with your phone: rain on a real window, a real keyboard, a door knock, a mug on a bench;
- clean them up in **Audacity** (free): trim, normalize, a little noise reduction.

When we get there, Claude will write you a step-by-step "record and clean up 10 sounds" session.
