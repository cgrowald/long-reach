# M1b, bench 1: the sewing table (design, 2026-11-24)

The first bench of the bench face-lift (docs/ROADMAP.md M1b). User answers 2026-11-24:
- **Sewing table first.**
- **Feel:** ReStroy (the user's clip) for handling things in 3D, a simple version: every item you touch is fully modelled, with detail on every side and in every nook. Plus Assemble With Care (pick up, turn, snap into place with a click).
- **Wear:** gear wears SLOWLY with each op, but mostly from getting hurt: bullets (and environmental damage, if we add it). The tear is where the hit was.
- **Art:** GPT draws it, Claude follows the drawing (it has worked best). No Blender session together.

## 1. What the GPT sheets show (2026-11-24; they arrived inline only, not saved as files)
- **The table, three stages:**
  - STARTER: a plank top on two sawhorses; a VESKA crate (blue, stencilled) full of coloured scraps (mustard, blue, red); a stack of folded cloth; a patched runner; a pincushion, a spool, black scissors; a copper desk lamp.
  - IMPROVED: a sturdy olive-green frame with bolts and a lower shelf; a mint-green sewing machine; a small wooden drawer cabinet.
  - UPGRADED: a pegboard back with a shelf (spools, boxes, folded cloth), hanging tools (tape measure, scissors, brush), fabric rolls under the table (blue, mustard), a cream cutting extension on the right with a jacket laid out on it.
- **Mending (INSPECT, FIT, MENDED):** a field jacket on the table (name tape "KELMOR", red stripe on the shoulder) with a ragged tear on the sleeve. Your low-poly hands. FIT: one hand holds a blue patch over the tear, the other pins it (a small ring marks where). MENDED: the patch sits there with big cream stitches all round.
- **Making a rig (LAY OUT, FIT, EQUIPPED):** the parts laid out on the table (the cut bag body, two olive straps with box-X stitching, a flap pocket, a blue patch); FIT: hands press the pocket onto the body; EQUIPPED: the fighter in the gear cage wearing it. A second sheet does the same for a chest rig: body, a row of three pouches, buckles, a webbing roll; FIT shows a **dashed amber outline** where the pouch row goes.
- **Other benches drawn the same way (for later in M1b):** hacking bench (VELTIN radio: SETUP, FIT the knob, TEST with a green light; starter/improved/upgraded from a wooden desk to a hutch with drawers and a meter), med table (NEMRA tins, folded dressings: SORT, PACK into the wrapper, READY; metal table, then shelves), gun bench (a blocky stylised pistol on a felt mat: INSPECT, FIT the side panel, FINISHED; sawhorse table, then drawers, then pegboard and shelves).

## 2. What ReStroy does (frames read from the user's clip)
- A **top-down camera** over a cutting mat on a desk. One item, big, in the middle.
- **Taking it apart lays every part out in neat rows** on the mat (shell, battery, board, screws), each on its own line.
- You **pick one piece up and turn it** freely in 3D (a flip phone opened, a cassette tilted), then put it down or into its place.
- A **checklist** top-left (the job's steps); a parts box and a bin at the edges; a paper job ticket at the side.
- Parts and tools are bought on an in-game PC shop.
- **A score at the end** ("8 GREAT").

## 3. The sewing table, as it will play
1. **Lean in.** The camera goes top-down over the table (fixes the old view where the fabric blocked everything). The checklist is top-left, the VESKA scrap crate and the tools sit around the edge, and the lamp pools light in the middle.
2. **Pick a job from the side ticket:** make a recipe (market-bag rig, chest rig), or **mend** something torn.
3. **Lay out:** the parts drop onto the table in rows (body, straps, pocket, patches), every one a real 3D model.
4. **Pick up and turn:** click a part to lift it; move the mouse to turn it (every side is modelled). Its target shows as a **dashed amber outline** on the body.
5. **Fit:** drop it on the outline; it snaps with a click when it's close, and how close it was feeds the quality.
6. **Stitch:** small rings appear round the edge; click them in order (or hold on the sewing machine once you have it). Clean stitches = better stars.
7. **Done:** a score card (stars), and the item goes to the shelves; then it shows on the fighter in the cage, the way it was made (EQUIPPED).

**Mending:**
- **Wear comes mostly from hits:** a bullet or a graze leaves a tear where it hit (sleeve, chest, back); every op also adds a little wear.
- Torn gear works a bit worse (a torn rig can lose a pouch cell; a torn coat is colder) and looks it on the fighter.
- **INSPECT:** the item lies on the table; turn it to find the tears. **FIT:** pick a scrap colour from the VESKA crate, lay it over the tear, pin it. **MENDED:** stitch round it.
- The patch stays: you see it on the fighter in the cage and in the fight (bible 06, 14). The colour you picked is the colour they wear.

**Time, not gates** (user 2026-11-23): a job takes in-game hours, with no action points or costs beyond the materials.

## 4. Build order (one bench, start to finish)
1. Models from the sheets (Blender): the table in three stages; the scrap crate, pincushion, spool, scissors, lamp; the bag rig and chest rig parts; a field jacket with a tear and patch spots; low-poly hands.
2. The top-down table view with lift, turn, outline and snap (one shared "hands-on" engine for every bench, ReStroy-style).
3. Make jobs (the two rigs) on it.
4. Wear and tears from hits in the fight; mending jobs; patches shown on the fighter.
5. Table upgrades (improved, upgraded) as bench upgrades.
6. Screenshots to the user at each step; a playtest list at the end.

## 5. Defaults I'll use unless the user says otherwise
- Mouse only: left-click to lift or drop, move to turn, wheel to turn the other way, right-click to put it back.
- Stitching is click-the-rings by hand; the sewing machine (improved table) turns it into a hold-and-guide.
- The score card uses stars like the rest of the game (no "GREAT" text, or a quiet one).
