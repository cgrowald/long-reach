# Polish pass (LATER: do not work from this yet)

*User, 2026-11-22: "This is notes for future passes from GPT, because the art direction obviously helps you. BUT REMEMBER DON'T WORK OFF THIS YET, IT'S FOR LATER WHEN WE NEED TO POLISH." The user will keep feeding ChatGPT screenshots of the game to make closer renderings. Reference sheets are in `docs/refs/polish/`.*

## The reference sheets (2026-11-22)
- **garage_touchup_study:** the desk (beige CRT turned slightly with tape on the casing, a taped photo beside it, a worn keyboard, a coffee ring, the box with one odd knob, a cable taped down), the benches (pegboard with tools at uneven heights, a solder scorch, a cloth on the gun bench, a hanging amber lamp), and the repairs (tape, the mug ring, a wooden shim under a bench leg).
- **hearth_os_sheet:** the OS as it is now, plus: a "BACKUP FRIDAY" sticky note on the login screen, a "Wrong password. Please try again." box, a mail toast ("Mail (1 new) from: neighbor"), a mail count badge on the Mail icon, a desktop "parts list" note, and the palette swatches.
- **workshop_materials:** the electronics bench (green board on an olive mat, a "FIT COMPONENT" callout with corner brackets, a parts tray, a solder spool and iron in its stand, the laptop) and the gun bench ("INSPECT" mode with corner brackets, the rifle on a cloth, an oil can, a parts tray, a note); material swatches: worn metal, matte polymer, cloth.
- **market_rig_01:** the shopping-bag rig: the striped woven market bag on the gear bench with a dashed "CUT PANEL" outline, scissors, webbing, buckles, thread; the finished rig (three pouches, crossed straps, buckles, a red pull loop); front, back and worn on a man in a beanie; close-ups of the weave and salvaged straps.
- **medical_bench:** cloth prep (both hands tearing cloth on a mat, a frayed edge with a "snap" spark) and treatment (a FIELD WASH bottle, a basin of grey water, folded cloth, a red-cross box); raw cloth > prepared strips > packed rolls > a pouch.

## ChatGPT's environment notes for the garage (the user's paste)
Give the existing garage a restrained environment-art pass. Preserve its layout, interaction positions, chunky geometry, pixel rendering and dithering.
- **Wear where use causes it:** a chipped desk edge near the keyboard, a worn spacebar, a coffee ring beside the mug, a solder scorch at the electronics bench.
- **A few deliberate repairs:** tape on the CRT casing, one replacement radio knob, a wooden shim under a bench leg.
- **Break alignment subtly:** turn the monitor slightly, overlap two papers, hang tools at unequal heights. Keep placement fixed between visits.
- **One personal detail:** a small taped photograph beside the monitor.
- **Group clutter around tasks.** Keep the keyboard and crafting surfaces open, with clickable objects clearly separated.
- **Distinct material colours:** yellowed beige plastic, dull olive metal, worn brown wood. Keep grime localized.
- **Localized amber light** at the desk and workbench, with dim corners and a small green terminal accent. Preserve readable silhouettes.
- **Order:** lighting first, then wear, then a handful of props. Match the reference's details while keeping the garage's current darkness.

## How hard each would be (Claude's estimate, for when we get there)
- **Easy (a Blender script pass plus Godot materials):** garage lighting and props, the tape, shim, mug ring and photo; the OS sticky note, toast and badge; the bench mats, trays and iron stand.
- **Medium:** woven, worn-metal and polymer material looks (a texture or shader each); the cut-panel dashed outline and the "inspect" corner brackets as bench UI.
- **Bigger:** the market-bag rig as a modelled object with straps, buckles and pouches worn on a fighter (it ties into the rig grid); two-handed tearing in the bench hands.

## The combat screen: "UPRISING / FIELD LINK" (user, 2026-11-22: for the combat face-lift, not before)
*Arrived inline only (not saved as a file; drop it in `docs/refs/polish/` if you want it kept).* A full-screen command layout in our pixel style, warm beige-on-charcoal panels with thin rules and pixel type:
- **Top bar:** "UPRISING / FIELD LINK", the objective in amber with a diamond ("RECOVER SHIPPING MANIFESTS / Dispatch office"), a pause button, ELAPSED 00:23:41.
- **Main feed** (big, left): "02 / ADA LIND — BREACHER", signal bars, "FAIR", a red REC dot. Over-the-shoulder helmet cam down a grimy green hallway: chunky low-poly fighters in tan helmets and plate carriers, one with a red-cross med pouch; vignette and dither. Radio subtitles bottom left: "VIKTOR: Room clear." (yellow), "IVO: Moving." (red).
- **OPS MAP / RECON** (top right): a paper blueprint ("Rev. B", north arrow, ~25 m scale): rooms in grey, numbered squad circles 1-3, the objective diamond in the OFFICE, a red dashed "?" room = last report; legend SQUAD / OBJECTIVE / LAST REPORT; "Updated 00:18 ago" (the map is reports, not live).
- **SQUAD panel:** a row per fighter: number box, a helmet portrait, name, signal bars, state (STEADY in teal, "+ BLEEDING" in red); the selected one framed amber; FOCUS: ALL dropdown and a RADIO button.
- **Feed strip** (bottom): five thumbnails: 1 VIKTOR, 2 ADA (selected, amber), 3 IVO (red dot = hurt), CCTV 07 and CCTV 08 in green night tint, each captioned with its place (Hallway (W), Storage A, Dispatch Anteroom).
- **Key hints:** 1-3 Helmet cams, Tab Next feed, Space Pause, Esc Back.
- *Read:* our feed wall + ops board + squad list, reorganised into one calm screen: one big feed, the map as stale paper intel, states as words, CCTV as equal feeds. Medium job when we get there (layout and styling; the parts mostly exist).

## HEARTH OS concept sheets (user via GPT, 2026-11-22: use NOW with the hacking build, not later)
*Arrived inline only.* Five screens: desktop (Files and Mail windows, a "Kettle. Fuses. Bandages." sticky, parts_list.txt, a "Job updated: Dispatch records" toast), login ("LOCAL SESSION", a pixel portrait, "citizen / Workshop account", SIGN IN in copper, DISPLAY/LOCAL DISK/RADIO status ticks, "ONE HEARTH. ONE PEOPLE."), PATCHBAY, WATCHLINE, SPOOL (all described in docs/HACKING.md section 2).
- **Palette:** dark petrol desktop with a faint factory line drawing bottom right, warm ivory windows, copper for selection and primary buttons, sage green for "ready" chips, dark petrol panel headers with ivory caps.
- **Frame:** a top bar (HEARTH, Applications, Files, Session ... OFFLINE, 18:30), a left dock of big labelled icons (Files, Mail, Jobs, Tools, Field), a bottom taskbar of window tabs; windows with a petrol title, square min/max/close.
- **Type:** a clean monospace, caps for headers. GPT's notes: one consistent icon set and window controls; each app has one clear job.

## The gun bench, done properly (user, 2026-11-22: a design change for later, not just polish)
*"This is more what I meant for this bench, not the three holes we make now, which makes no sense."* The reference is a ChatGPT sheet titled "ENGINE WORKSHOP" (it called the gun an engine to get past ChatGPT's rules):
- a first-person view at a green **drill press / mill**: the part clamped in a vise on a cross-slide table;
- your hand on the big handwheel, chips falling into a tray;
- a "SHAPE HOUSING" progress bar and a callout on the part;
- a **PARTS BIN** panel of bearings, pulleys, belts and casings with counts, some locked;
- on the bench: an oily rag, a brush, a lamp, a pegboard of wrenches, small drawers.

Read as: the bench is machining a part into shape by hand-feeding a tool, then assembling it from a parts bin of made and bought pieces. **Early game:** a slow hand drill (what we have, made meaningful). **The upgrade:** the press/mill view. Weapons stay stylised (CLAUDE.md): gamified "shape the housing" actions, never real machining steps for real guns. Image not saved as a file (it arrived inline only).
