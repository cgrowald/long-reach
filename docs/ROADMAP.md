# Roadmap (agreed process, 2026-11-23)

> **START HERE (next chat, written 2026-11-23 late):**
> - **M0** (play the backlog): round-1 fixes done; not signed off yet.
> - **M1** (the depot raid): almost done, not played yet. Done this session (all bot-tested, screenshots approved):
>   - combat screen clean-up: one chosen feed, no bottom tiles, ammo + health on the squad rows, CAMERAS list under the squad, ops map wheel zoom / drag pan / double-click fit. Helmet cams stay as the main feed (1-4 or a squad row).
>   - gun swap: a dry fighter takes a downed guard's SMG (v2/combat/squad_ai.gd `_gun_swap`), it comes home in their rig.
>   - stick carrier: pack the drop stick into one fighter's rig in the cage (tech 1+; v2/sim/loadout.gd `stick_carrier`).
>   - the vault: 3D room (v2/combat/vault_room.gd), command hack in a small draggable terminal popup (v2/sim/vault_hack.gd, v2/ui/popup_win.gd): you tell the carrier what to type, the typing takes the time, they're out of the fight meanwhile. Then a vault-camera popup: click a door. User: "exactly what I wanted".
> - **Done 2026-11-23 (later):** the plan file as a Bureau SERVICE FORM and the prisoner ID (people's laminated card, or a guard's black Bureau card) as paper (v2/ui/paper.gd; Shelves > Read, cage > Plan file, the interrogation chair); the plan shows tonight's real guards (DepotRun.seed_for). The gear cage rebuilt like bible 17. Fixed: a crew of 3 crashed the fight's main feed (CAM 04).
> - **Now: M1b, the bench face-lift** (user 2026-11-24: "continue on the M list"). Bench 1 = the sewing table (docs/BENCH_SEWING.md section 4): models, the top-down table view, both rig jobs, and wear/tears + mending are built; next = table upgrades (improved, upgraded), then the playtest of the sewing table. GPT drew all four benches (described there). The catalog idea is parked (Parking lot); its faces step is done.
> - **User after M1 (2026-11-23, decisions log in GAME_DESIGN 20):** judge fun on the whole game, not pieces; no more Krall questions; Schedule I style open world (time, not gates or currency; things pop up); the overworld territory map (Paper Mario) soon; GPT gear catalogs in docs/refs/catalog/ to model from, with material sources, ideas bought off people, blueprints = regime tech; smoother fighter models. Answers: next = items from the catalogs (every tile its own item); ideas come from sellers, recruits' old jobs and StateNet; gates give way to things popping up over time.
> - **Then ask the user (do not decide alone):** the user fears the game is boring; combat is great, but it needs a variety of maps, targets and reasons to hit them. Offer to move map/target variety (M4: generated buildings, more op types) ahead of M1b (benches). Also parked: things to do while an op or hack runs (maybe watch the op as a feed on your PC at night); blood splatter and ragdolls.
> - **Process (user 2026-11-23):** small fixes = screenshots in chat, no playtests; full playtests only after big slices. Keep chats short to save usage: one milestone chunk per chat.
> - **Look target:** docs/ART_BIBLE.md. **Design of record:** docs/DEPOT_SLICE.md (section 8 = this session's answers), docs/LOOK_BIBLE.md, docs/LOOP_RUNDOWN.md.

The user asked for this to stop us creating more and more new work before finishing what we were talking about.

## How we work
**The look target is docs/ART_BIBLE.md** (user: "the game HAS TO LOOK LIKE THIS AT SOME POINT OR WE ARE FAILING"). Every playtest asks: does it look like the bible yet?

1. **One milestone at a time, in this order.** Claude builds the whole milestone.
2. **Claude checks it** with bot tests and screenshots.
3. **Claude hands over a playtest work list** (numbered steps: what to try, what should happen) **and opens the game.**
4. **The user plays** and sends notes.
5. **Claude fixes** them, and steps 3-4 repeat until the user **signs off**.
6. **Then the next milestone, exactly as planned here.** Changing the order is the user's call.
7. **New ideas go to the Parking lot** (bottom), not into the current build. They get a milestone when the user says so.
8. Before each milestone, Claude asks its open questions **in the chat**, with options.

---

## M0. Play what's already built (the backlog)
**Status: in playtest since 2026-11-23** (work list: docs/PLAYTEST_M0.md).

**Playtest notes, round 1 (user, 2026-11-23):**
- **Fixed:**
  - Lockpick: W/S did nothing. Tension is now held on E/Q (W/S work too). Holding left pushes the pin up steadily. The pin and lock shake near the sweet spot, and rattle when the tension is too high.
  - Hacking: the program codes were pushed under THE BOX by the long buffer (moved back into the middle). New sounds: tiles thunk and click, picks rise in pitch, a run of notes when a program runs or the link comes up, a low pulse at 50, 75 and 90% trace.
  - The gadget case lid was turned the wrong way on its hinge.
  - The roller door now shows your fixer trust out of 5, and the F1 shortcut.
- **For the bench face-lift** (see the Parking lot):
  - the sewing table's fabric blocks the view, and it needs crisp animations (the user will find games to copy);
  - the gun bench parts are hard to pick up (broken since day one);
  - the code chain needs to make more sense.
Nothing new is built. The user plays the unplayed builds, then Claude fixes bugs until sign-off:
- markets (ShopNet, Lantern, the Tram Yard curfew dash, barter, stings);
- lockpicking (the yard gate and the title toy);
- the tutorial hacks (post office, town hall);
- the bench lamps and the new models;
- the garage, mission and OS face-lifts;
- the hacking build.

## M1. The depot raid, the whole loop (the proof the game is playable). One big build.
**Status: started 2026-11-23, in parallel with M0 fixes (user's request).** **In playtest** (work list: docs/PLAYTEST_M1.md).
- **Built:** pieces 1-8, 10-16. Piece 9: the stores are limited by rig space. Piece 17: guard uniforms and patched clothes with the red stripes.
- **User notes 2026-11-23 (not played yet: "polish first"):**
  - The combat screen is too cluttered during combat.
  - The combat (ops) map needs zoom in and out.
  - Drop the bottom camera tiles and keep the operator list. You only see the one camera angle you've chosen (click an operator, or a CCTV entry, to switch).
- **Still to do in M1:**
  - ~~The combat screen clean-up above~~ (done 2026-11-23).
  - ~~the gun swap mid-fight~~ (done 2026-11-23);
  - ~~the stick carrier, picked in the cage by tech~~ (done 2026-11-23);
  - ~~the vault room: three doors, cables, command-hack terminal popup, vault-cam popup~~ (done 2026-11-23);
  - ~~the plan file and ID drawn as documents~~ (done 2026-11-23: v2/ui/paper.gd);
  - ~~the art bible cage layout~~ (done 2026-11-23: v2/stations/cage.gd).
  - **Handed to the user for the real M1 playtest (docs/PLAYTEST_M1.md).**
Design is in docs/DEPOT_SLICE.md (sections 1, 4, 5, 8).

| # | Piece | Done when |
|---|---|---|
| 1 | **Person generator** | Guards, prisoners and recruits get a name, a face, a background, a motive, a tech level and traits. |
| 2 | **Depot run generation** | One hand-made layout, but every raid rolls the depot type (one per bench), the guards (count, posts, patrols, poor weapons, infinite ammo with reloads) and the stores behind the doors. |
| 3 | **Intel before the raid** | Hacking the depot gives a plan file (layout and guard rotation drawn on the ops board); more hacking can hint what's behind each vault door. EYES gives the cameras. |
| 4 | **EYES in the fight** | Camera tiles show enemies your squad can't see. A ping only alerts the squad; the shout wheel makes them target it. |
| 5 | **The vault** | Three locked doors in the secure section, time to open one. Dungeon Crawler Carl loot: mostly junk, sometimes great (blueprints, bench upgrades with quirks, rare gear). Your team escorts it out. |
| 6 | **The backup timer** | Reinforcements arrive when it runs out. Upgrades push it back. You can fight out with meds, good guns, good people and good gear. |
| 7 | **The stick carrier** | A fighter with enough tech asks "Boss, PC here, hit it?". Yes = the squad hunkers down, and either you hack it (a quick hack from the van) or their auto-hacker grabs some, half or all of it by quality. The time costs backup timer. |
| 8 | **Squad AI self-preservation** | A priority list: their lives first, even against your orders. |
| 9 | **Loot by carrying** | Tarkov grids. Pick up what fits, swap your gun for a guard's SMG (low ammo). |
| 10 | **Health and injury** | Bandages heal HP in the raid; the report turns missing HP into injury days; heavy wounds, scars; better meds heal fully. |
| 11 | **Items by name** | "Ada used your dressing (★★★, day 2)" in the report; gear history. |
| 12 | **The prisoner** | From the depot's holding cells, or a captured guard, brought to the garage. Interrogation (pressure, bluff, bargain, leverage), then let go (raises the hunt), kill (off-screen; loyalty drops) or recruit (a risk). |
| 13 | **Krall's ladder** | A corkboard clock. Anyone you've been near is questioned, then a delivery is intercepted, then the garage is searched. Each op moves it; destroying evidence pushes it back. |
| 14 | **The depot recruit** | An ex-worker on Nod ("hey, we're hitting the old warehouse"), or the prisoner. |
| 15 | **After the raid** | The depot locks behind a reset timer and remembers how you won (just recorded for now; the learning is M4). |
| 16 | **Mastery count** | 5 handmade crafts before an item can be made in lots (lots themselves are M5). |
| 17 | **The look of this milestone** (face-lift piece) | Our people's clothes (Wolverines mismatch plus the movement colour), the guards' uniforms, the plan file and the prisoner's ID as documents. |

**Playtest question at sign-off:** what did you make, who used it, what did you learn on the PC that changed the raid, and what will you do tomorrow because of Krall?

## M1b. The bench face-lift (decided C6: right after M1)
Each bench redone step by step, with defining questions before building. Repairs with sound, worn and mended states, colourful patches and armbands (art bible 06, 12, 14, 19). Crisp animations from games the user finds. Fixes: the sewing table's fabric blocking the view, the gun bench parts hard to pick up. Better models, with a Blender walkthrough together and GPT decals ("stickers").

## M2. Your people grow
Recruits from Nod, prisoners and coworkers; motives and loyalty reacting to your choices; leaders (after N ops, when your organisation can support a new squad); your own squad always stays yours.

## M3. The week
Hana and cell needs with deadlines, a real rule of the day (blackout, ration week, checkpoint), ration cards. Money always a little short.

## M4. More hits, and an enemy that learns
Generated buildings (a new one every time), more op types, and the enemy covering the exploits you used last time.

## M5. Production at scale
Lots after mastery, lot-size upgrades, upkeep that climbs the chain of command (person, squad, platoon, company, battalion).

## M6. Going out
**Look decided (user 2026-11-23):** the night trips (the curfew dash, getting to and from places) are 2D: a painted town like art bible 09, with you and the guards as flat cut-outs standing up on it (Paper Mario), and real 3D lights, shadows and effects over it. "Cute charm". Going somewhere on your own to hack or break in is full 3D.
A town map with destinations: contacts, on-site hacks, leaflets, the Tram Yard.

## M7. Districts and the war room
District companies under your leaders; the army meter toward 1000.

## M8. Vehicles and targets outside town.

## M9. The capital.

## M10. The campaign wrapper
New country each run, unlocks after a campaign (cosmetics, starting classes).

The face-lift goes piece by piece inside each milestone, using docs/LOOK_BIBLE.md.

---

## Parking lot (ideas waiting for a milestone; not built until scheduled)
- **The catalog (was "M1c", parked 2026-11-24: the user wants the M list in order).** Faces already done; the rest waits for a milestone (fits the bench face-lift and the face-lift stages):
  GPT's sheets in docs/refs/catalog/ (16 so far, more coming). Every tile is its own named item. Order:
  1. ~~**Faces**~~ (done 2026-11-23: 4 sheets, 100 faces drawn from art/faces/, picked by name in v2/sim/portraits.gd, tags in data/v2/faces.json; ages follow the face; prisoners from the bruised sheet; the hurt get tape on their own face; regime-collar tiles kept for officers): everyone uses them (people, recruits, prisoners, guards, ID cards, the cage). The hurt/scarred sheet for the injured.
  2. **Item data:** one entry per tile in data/v2/ (name, family, slot, warmth, weather, pockets/carry, blend-in vs stand-out, toughness, wear), and where its materials come from (day job, markets, depots, scavenging).
  3. **Ideas:** how you learn to make the handmade ones: bought off people, your recruits' old jobs, StateNet pages. Blueprints are regime tech, taken in raids.
  4. **Model kits:** one smooth Blender generator per family (jacket, coat, parka, bag, pouch, rig, hat, glove, boot), each tile a mix of parts and colours; icons rendered from the models for the stash.
  5. **People:** the outfit sheets dress townsfolk and recruits and set the regime ranks; the fighter body gets rebuilt smoother toward them.
  6. **Things pop up over time** (Schedule I) instead of gates: sellers message you with ideas, deliveries arrive after a wait.
  Not decided yet (ask before that step): how stats show in the cage, what happens to night actions and Krall's countdown.
- **Bench mechanics and face-lift (needs a slot on the roadmap).** Redo each bench step by step, with defining questions about what each step does. Crisp animations from reference games the user finds. The sewing table's fabric blocks the view; the gun bench parts are hard to pick up.
- **Better models:** walk through Blender together to line things up; GPT-made 2D images used as "stickers" (decals) on the 3D models for detail.
- **The code chain to make more sense** (questions asked 2026-11-23).
- Leaders asking for promotion themselves (from G6).
- More vault doors via unlocks (from R2).
- A deeper health system, limb by limb (from G10).
- Garage moments, morale items, bonds (docs/RESEARCH_IDEAS.md D).
- Repair at the bench, Pacific Drive style; gear that remembers its history in full (RESEARCH_IDEAS A).
- Files as readable documents about people you recognise (RESEARCH_IDEAS B).
- Propaganda clips from helmet cams (RESEARCH_IDEAS I).
- The fixer as a character with commissions.
- The man who made the vault doors teaches you to pick them, for a price (its own hit) (V1).
- Explosives to open all three vault doors (late game, V1).
- Designing your own garments, with the stripe (L1).
- Vehicles from somewhere other than depots.
- **Hit and death feedback in fights (user 2026-11-23):** you can see a bullet hit (blood splatter), and the dead ragdoll (a set of random canned ragdolls is fine, whichever is cheaper).
- **Things to do while an op or hack runs (user 2026-11-23):** maybe the op plays as a feed on your PC while you work on other stuff at night. For now the fight stays the big thing.
- **Variety is the fun (user 2026-11-23):** "I fear the game is boring." Combat is great; it needs a variety of maps and targets, and reasons to hit them. Candidate to move M4 (generated buildings, more op types) up: ask the user after M1.
