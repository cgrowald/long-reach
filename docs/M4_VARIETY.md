# M4: variety (plan, 2026-11-24)

The user, 2026-11-23: *"I fear the game is boring. The combat part is great so far. It needs a variety of maps and targets, and reasons to hit them, to start being fun."* Agreed order (2026-11-24): variety right after D. The user doesn't want to play until more of this section is in.

## 1. The sweep: everything said about it so far
- **Targets** (GAME_DESIGN 0): generated places on the overworld map: government offices (data, dirt), gun stores (weapons), a metal refinery (parts), police posts, roadblocks, officials, radio towers, depots. "Different loot gives different upgrades, so you choose targets by what you want to upgrade."
- **The first fights are small guerrilla work** (RUNDOWN 8): the bar where a politician drinks; a daytime checkpoint ambush (the user's reference: *The Devil's Own*). The bar was picked as the easy first mission (2026-11-22). COMBAT_SLICE 11: an easier first mission (a couple of guards, no Bureau); the police officer beat (befriend or exploit a cop, steal his keys, rob the police station: your first real guns).
- **One AI for any place** (COMBAT_SLICE 11): trenches, roads, houses, gas stations, bars; the doctrine and cover can't be built only for corridors. The scenario decides: a cheap shotgun wins up close; a small roadblock on foot is winnable, an army squad on a road is not.
- **Generated buildings** (DEPOT_SLICE R1, G3; LOOP_RUNDOWN Q14): a new building every time, generated from the target type (bar, depot, office, police station); hand-made maps for milestones. Every depot raid different (guards, stores, rooms). After a raid the place adapts: it covers the exploits you used (R3); ROADMAP M4 "an enemy that learns".
- **Op types** (LOOP_RUNDOWN Q5 f): raid, ambush a convoy, sabotage, rescue, assassination, propaganda (film it for Nod).
- **Open world** (user 2026-11-23): Schedule I style; things take time and pop up (contacts, jobs, targets, deliveries); no gates. **The overworld map** of what we hold and what they hold, Paper Mario style (wanted soon; M6 look decided: painted town, flat cut-outs, real 3D light).
- **Groups who buy** (Running Thoughts): weapons groups want weapons intel, reporters want dirt, hackers want data; Tarkov-trader-like quests later.
- **Nobody is just a target** (GAME_DESIGN pillar 4): guards, clerks and conscripts are people.
- **Multi-floor moves** (Operator clip 7): stairs, the landing above, under the stairs; windows as recon (clip 1).
- **Code that exists:** the town roster of hackable places (office, depot, shop, clinic, police; data/v2/hacking.json), four depot kinds by bench (parcel, bulk, cold, linen; data/v2/depot_runs.json), the person generator, the depot kit, level.gd building from a room/door list, the whole C combat (overview, orders, doctrine, wounds, leave card), coming home.

## 2. Gap questions (asked in chat 2026-11-24; answers go in section 3)
Q1 where targets come from; Q2 which op types first; Q3 how buildings are generated; Q4 outdoor fights now or later; Q5 reasons to hit (rewards); Q6 the enemy that learns; Q7 the easier first mission; Q8 how many targets and how often; Q9 the map now or later; Q10 people who aren't fighters; Q11 planning before going in.

## 3. Answers (user, 2026-11-25)
- **Q1 d:** targets come from everywhere: the town roster (hacking one scouts it), tips that pop up, all shown on the map.
- **Q2 all of them:** generated building raids, the bar hit, the roadblock ambush, rescue, sabotage, convoy ambush, propaganda. (Build order below.)
- **Q3 a:** a generator per building type. *"Not just long hallways, really vary it up, you know what building layouts are like."* Real floor plans: open rooms, rooms through rooms, L shapes, back rooms, a yard, two ways in.
- **Q3b i:** single floor now; multi-storey planned for later.
- **Q4 (outdoor):** not answered on its own, but the roadblock answer needs it: the fight engine works outside (cover objects, a street).
- **Q5 d:** loot by type + a district shift on the map + groups who buy and give jobs.
- **Q6 d:** the enemy that learns waits (later).
- **Q7 c, as one scripted first mission:** the roadblock and the bar are right next to each other. A shabby roadblock, about 5 men, and a politician we knew would come through. You chase someone (the politician) into the bar: script the AI to run into the bar. Some soldiers at the roadblock take cover. **Use this mission to teach our AI and theirs cover and bounding.** The enemy never pushes forward while people are alive and shooting at them. **Design rule: the enemy AI is always worse than ours but comes in large numbers, so you must prepare well.**
- **Q8 c:** a mix. The ones always there are harder and need you to know the game; you can keep them on the map and watch them until you're ready. More pop up from intel.
- **Q9 b:** the full Paper Mario map now: *"this will look awesome"*. It is both the **overworld map** and the **night outing map** (it replaces the current curfew map, which looks janky).
- **Q10 a:** civilians (bar patrons, clerks) hide or flee; hurting them costs district mood and recruits.
- **Q11 a + b:** pick the way in (front, back, window) and the hour (shift change, fewer guards).

### Also asked (2026-11-25)
- **A character generator** from GPT's face sheets: model the faces in Blender as **parts** (eyes, nose, mouth, brows, ears, hair, jaw...), then a random generator assembles fresh people from them, on the models we already use. Put it on the roadmap.
- **Take open-source code when it fits** (GitHub etc.), plugging in our own assets: *"all games are the same, whether it be one thing that tethers them or all."* Don't hand-build what a proven open project already does; we bring the assets and the game around it.

## 4. Build plan (proposed 2026-11-25, waiting for the user's OK)
Each step ends with bot tests + screenshots, then commit and push. No playtest until the user asks (they want more of M4 in first).

| Step | What | Why first |
|---|---|---|
| **V1** | **Cover and bounding for any place**: cover points generated from any level (walls, crates, cars, sandbags), both sides use them; the enemy holds and returns fire, never pushes into live fire; large numbers, worse aim/discipline. Outdoor ground + street pieces in the kit. | The first mission needs it, and every later op type reuses it ("one AI for any place"). |
| **V2** | **The first mission: roadblock + bar**: hand-made street with a roadblock (~5 men, sandbags, a barrier, a car), the politician's car comes through, he runs into the bar next door (scripted), patrons hide or flee (Q10), you follow him in. Pick the way in + the hour (Q11). Reward: the politician (the chair) + guns + a district shift. | The easy first mission, and it teaches everything. |
| **V3** | **The building generator**: footprints per type (bar, office, clinic, gun shop, police post, depot), split into real floor plans (public front, back rooms, rooms through rooms, a yard, two or three ways in), dressed from the kits, guards + civilians placed by type. Single floor. The depot raid moves onto it. | Every raid becomes a new building. |
| **V4** | **Targets and rewards**: the roster places become raid targets (hacking scouts the plan); a few hard fixed ones you can watch, more popping up from tips; loot by type; groups who buy (reporters, weapons people, hackers) and give jobs. | The reasons to hit. |
| **V5** | **The Paper Mario map**: painted town, flat cut-out buildings, real 3D light; districts with who holds them; targets, tips and the groups on it. It is also the night outing map (replaces the curfew dash look). | The place it all comes together. |
| **V6** | **More op types on the same engine**: rescue (holding cells -> recruits), sabotage (radio mast, transformer), convoy ambush, propaganda (film it for Nod). | Each reuses V1-V5. |
| **V7** | **The character generator** (could move earlier, see question G2). | Many fresh faces for civilians, guards, recruits. |
| later | Enemy that learns (Q6 d), multi-storey (Q3b). | User: later. |

### Picks for the plan questions (user 2026-11-25: "Yes, your picks")
- **G1:** the order above (V1 cover first, then the roadblock + bar, the generator, targets, the map, more op types, the character generator).
- **G2:** portraits become renders of each person's 3D head (one face everywhere).
- **G3:** download Millennium Junction Character Creator (MIT) to borrow its mix-and-match code; our parts are modeled from GPT's faces.
- **G4:** outdoor fights are in now.

## 5. Built: V1, cover and bounding anywhere (2026-11-25)
- **v2/combat/cover.gd** (new): cover pieces from level data `cover: [{kind, pos, turn, len}]` (sandbags, barrier, car, crate, barrel, low_wall, booth). Each blocks walking, stops rounds (low pieces on physics layer 2: eyes see over, rounds stop; the booth on layer 1 like a wall) and makes cover spots round itself. `best(who, threat, reach, toward)` = the usual cover-shooter pick (the piece between you and the threat, near, not crowded, forward when bounding). Walking grid = Godot's stock **AStarGrid2D** with string-pulling, so people route round cover outside.
- **level.gd:** rooms can be `outdoor` (no walls of their own, no roof, a road floor, an apron of ground); `path(a, b)`, `is_outdoor`; doors refresh the grid when they open.
- **actor.gd:** `suppress` (rounds at you; you shoot worse and keep your head down), `ducked` (behind cover: unseen, can't shoot), `preaim` (up from cover already pointed where they last saw you), misses into cover puff on it, poorer troops via `acc_mult` / `slow` in the enemy data.
- **enemy_ai.gd:** in contact each one runs to cover, peeks and ducks (longer down than ours), hears gunfire 45 m outside, sees 30 m in daylight; **never moves up while your people are shooting**: only after 7 s of quiet, one at a time. A hit in cover shakes them half as much.
- **squad_ai.gd:** in contact anyone not busy with the doctrine takes cover and peeks/ducks; a MOVE to a point outside under fire (or a walk that gets shot at) becomes **bounding**: half runs to the next cover forward ("Moving!"), half shoots, "Set!", swap. A level can turn the room-by-room doctrine off (`doctrine: false`).
- **fight.gd / orders.gd / title:** the fight loads any level (`Game` meta `fight_level`); daylight levels get a sun and sky light; right-click "Move here" outside = that spot. Title: **Combat: roadblock (cover test)** (data/v2/combat/roadblock_test.json: Kessel Road, 5 conscripts, the bar's wall).
- Bot test (scratchpad bot_v1.gd): contact, both sides in cover, ducking, no enemy advance under fire, bounding swaps halves, fight over in ~40 s. Indoor depot tests re-run unchanged.
- Not done here (V2): the real first mission (politician, the bar chase, civilians, pick the way in and the hour), real models for the cover pieces, tuning.

## 6. Built: V2, the first mission: Kessel Road (2026-11-25)
- **data/v2/combat/kessel_road.json**: a shabby roadblock (5 conscripts, poor aim) on Kessel Road; Deputy Aurel Vass and his bodyguard; the Copper Kettle next door (bar, back room, kitchen, back door to an alley, a side passage); a friend's shuttered shop across the road. Names and the brief are **placeholders for the user to rewrite**.
- **The plan sheet** (v2/combat/plan_screen.gd, Q11 a + b): pick WHEN (10:00 he comes through: Vass at the barrier, all five on the road / 13:00 lunch: Vass eating in the Kettle, two conscripts inside with him, the bar full) and WAY IN (up the road / the alley to the kitchen door / through the shop). The level's `plan` block; fight.gd `_apply_plan` moves people per hour (`at`, `hours`), sets the start and unlocks the friend's door.
- **The deputy** (enemy_ai `_vip`): unarmed; when it goes loud (or he sees you) he runs for the back room, kicking doors open on the way (you can see which way he went), cowers, and gives up when one of yours gets close. Nobody shoots him unless told. Captured = "WE HAVE THE DEPUTY"; dead = "THE DEPUTY IS DEAD" (squad_ai `_capture_check`, then they bound out).
- **People who aren't fighters** (v2/combat/civ_ai.gd, Q10 a): patrons, the barman, a passer-by. Startled by gunfire: they get down with their hands up or run out the nearest door. Stray rounds that miss can hit someone near the line of fire. The report counts them ("the district will remember"; the district effect itself waits for the map, V5).
- **Street kit models** (art/src/make_street_kit.py -> art/street_kit.glb): sandbags, jersey barrier, old saloon car, guard booth, oil drum, brick wall, big crate; cover.gd scales them to the level's sizes.
- Fixes found on the way: the walking grid now uses a wider body (people stuck on sandbag corners), a blocked walker re-routes instead of skipping waypoints, walking out onto open ground ends room-clearing ("We're out on the road. Your call."), a MOVE to a spot behind a shut door stacks on the door.
- Bot runs (scratchpad bot_v2.gd): all four plans end with the deputy taken. Up the road in the open cost one of ours in one run; the alley and the shop got everyone home. A passer-by sometimes gets hit.
- **Not yet:** it runs from the title screen only (no garage link or rewards until the targets step, V4); Vass doesn't go to the chair yet; no district effect yet (V5); the bar's look (signs, windows) and the bar's interior dressing are basic.
