# The combat slice (design + build plan, 2026-11-22)

*The user: "The combat slice needs to HIT HARD. More than a quick pass: whatever it took to make the garage and the tables is what's needed here." Reference images are in `docs/refs/combat/`:*
- *01: a loose, unprofessional stack;*
- *02: a tight, clean stack in gas masks;*
- *03 to 05: ChatGPT renders of the target look:*
  - *faceted low-poly soldiers in a dark hallway, seen through a helmet cam with a fisheye vignette and weapon lights;*
  - *an overwatch drone over a field at dusk;*
  - *a "field notes" sheet (named fighters, gear, rifle with attachments, med bag, hacking kit, camera feeds).*

*The direction is decided (COMBAT_ANGLES section 6). This doc is how we build it.*

---

## 1. What a fight is
- **Auto battle, your focus.** Your people move, aim, shoot, reload, heal and cover each other on their own, following doctrine. You choose the **focus**:
  - which room is next, which door, how to breach it (kick, shotgun, charge);
  - hold, push, pull out;
  - the call-ins you built.
  - You never aim or walk anyone. ("Otherwise it'll be a rage fest.")
- **You watch through what you've got** ("the view is gear"):
  - helmet cams on your fighters;
  - cameras you hacked;
  - an HQ drone circling overhead;
  - later, close drones hovering around the fight.
  - It's always 3D in our look: never dots, never a pure top-down board. The gear has to show.
- **Everything is finite.** Each fighter carries the mags, meds, grenades and plates their rig has room for. They reload and patch themselves and each other automatically. Medics prioritise others. When it runs out, it's out.
- **Gear is the stats.** Everything a fighter wears or carries raises what they can do. Better gear lowers the enemy's time-to-kill on your people and raises yours on them.

## 2. Gear to stats (Tarkov-lite, all bundled in)
**A fighter's numbers = person (skill, fitness, fatigue, morale) + everything they carry.**

| Gear | Raises / changes |
|---|---|
| Weapon (receiver, barrel, the parts you made) | base accuracy, damage, rate of fire, recoil, reliability (jams) |
| Ammo type (we write our own stylised round types) | damage vs penetration, armor damage, recoil. E.g. a soft round hurts unarmored targets and does nothing to plates; a penetrator chews plates but wounds less |
| Attachments (stock, grip, optic, light, suppressor) | ergonomics: ADS speed (time to first shot), recoil control, how fast they tire, noise, light in the dark |
| Plates (class, from the benches or looted) | blocks hits below its class; wears down per hit |
| Helmet | head protection, mount for the helmet cam (cam star rating = feed quality) |
| Rig grid (the sewing table) | capacity: mags, meds, grenades, and whether plates fit at all. Cramped early, roomy late (the Tarkov constraint, decided) |
| Meds (the med table) | heal per use, bleed stop, time to apply; finite |

The numbers stay hidden in the fight. You see them on an **inspect card** in the loadout screen (the field-notes look) and feel them in the fight: faster first shots, fewer jams, someone walking away from a hit that would have dropped them.

## 3. Your people
- **Named,** with a one-line backstory (where they came from), a face, and barks.
- **Level up** from surviving: skill, steadier hands, faster reloads.
- **Death is permanent.** Their gear can be recovered or lost. You see a death on a feed, then in the report.
- **Doctrine comes from trainers.** Rookies stack loose (photo 01), trained teams stack tight (photo 02). Hiring trainers raises the whole cell's doctrine; old fighters can retire, become trainers or lead a cell (later).

## 4. Call-ins: the things you build that touch the fight
From what real militaries use today (research below), stylised for the game:

| Call-in | Real counterpart | In the game |
|---|---|---|
| **FPV drone** | Cheap racing-quad kamikaze drones; one Ukrainian regiment sends FPVs into buildings first to scout and strike | **You fly it** for a few seconds of battery: scout a room, or dive it into a target. One use. Built at the hacking or gun bench |
| **Bomber drone** | Heavy reusable drones dropping grenades, several sorties each | Hover over a spot and drop. Reusable until shot down. Later |
| **Recon micro-drone** | Pocket-size helicopter drones that scout indoors, no weapon | Peek into the next room before the stack goes in: reveals who's inside |
| **Commando mortar** | 60 mm mortar fired handheld by one person, roughly 100 m to 1.5 km | The Iron Nest moment: a spotter (helmet cam or drone) gives a position, you fire, the round is tracked, you hear it, the feed shows the hit. Late |
| **Loitering munition** | Tube-launched one-use drones carried by infantry | Late-game "tube drone" upgrade of the FPV |
| **Ground robot** | UGVs that haul ammo and evacuate the wounded | Late: drag a downed fighter out, bring a resupply crate in |
| **Breach** | Mechanical (ram), ballistic (shotgun), explosive (charges), thermal | Your per-door choice: slow and quiet versus fast and loud. Charges are made at the gun bench. Stylised, no real recipes |

Weapons stay stylised (CLAUDE.md): real-sounding categories and feel, never real procedures or specifications.

## 5. The views ("the view is gear")
- **Helmet cams:** low-res, fisheye, vignette, a timestamp and the fighter's name, a bit of shake and grain. The look of reference 03. Cam quality = stars of the helmet cam you made.
- **Hacked CCTV:** fixed corner cameras, greener, lower frame rate. Only in places you've hacked (the job you just built feeds this: hack the depot first and you get its cameras).
- **HQ overwatch drone:** circles high above outdoors (reference 04). The closest thing to a map, still 3D.
- **The feed wall:** small tiles of every feed plus one big main view; click a tile to swap. Commands go on the main view (doors and rooms are clickable in any feed).

## 6. The art pipeline (the biggest job)
- **Soldiers as low-poly segments, not skinned meshes.** Torso, pelvis, upper and lower arms and legs, hands, head, each a faceted chunk (reference 03 is literally this).
  - Gear pieces (helmet, plate carrier, pouches, rifle and attachments, bags, masks) are separate meshes clipped onto the segments, so **what you made literally appears on their body**.
  - Made by a Blender script like the garage, tweakable by the user.
- **Animation in code:** joint poses for idle, walk, run, stack (tight or loose), aim, fire with recoil, reload, crouch, flinch, go down, crawl, drag a downed fighter, apply a bandage. Blended procedurally. No animator needed, and it reads well at our resolution.
- **Lighting is half the look:** dark buildings, every weapon light a cone with dust in it, muzzle flash lighting the walls, the dither on top.

## 7. Build plan (each step ends playable)
1. **(BUILT 2026-11-22) Look test:** four geared soldiers in a dark hallway, through helmet cams and a hacked CCTV, in our dither (title screen: Combat look test; `v2/combat/`, `art/src/make_soldier.py`). The user judges the look against reference 03 before anything else is built on it.
2. **The soldier:** segmented body, gear slots filled from a loadout, the procedural animation set.
3. **The sim** (headless, tested): gear to stats, rounds versus plates, finite mags, meds and grenades, auto reload, self and buddy aid, medics, fatigue, enemy AI, damage and death.
4. **The building:** one level (rooms, doors, corridors) in Blender, plus the room graph and doctrine stacking (rebuilt from the old prototype's squad brain).
5. **The views:** helmet cams, hacked CCTV, the HQ drone, the feed wall.
6. **Your control:** next room, door, breach type, hold, push, pull out; the FPV drone you fly; the recon micro-drone.
7. **The op loop:**
   - **brief:** from intel; the depot job's files unlock this op;
   - **loadout:** from the stash, onto the rig grid;
   - **the op;**
   - **report:** names, wounds, deaths, ammo and meds spent, levels;
   - then back to the garage.

## Sources (research 2026-11-22)
- FPVs clearing buildings for infantry (one Ukrainian regiment): [Euromaidan Press](https://euromaidanpress.com/2025/09/03/fpvs-clear-buildings/)
- Bomber drones, several sorties each, supporting small teams and resupply: [Euromaidan Press](https://euromaidanpress.com/2026/02/13/bomber-drones/)
- Drone roles and a proposed drone squad: [War on the Rocks](https://warontherocks.com/?p=34869), [Military.com](https://www.military.com/feature/2025/10/19/how-ukraines-drone-war-forcing-us-army-rewrite-its-battle-doctrine.html), [Bloomberg](https://www.bloomberg.com/features/2025-ukraine-drones-explainer)
- Man-portable loitering munition: [AeroVironment Switchblade](https://www.avinc.com/switchblade), [Wikipedia](https://en.wikipedia.com/wiki/Switchblade_300)
- Handheld 60 mm mortar: [Australian Army COVE](https://cove.army.gov.au/article/lightweight-handheld-mortars-suitable-and-effective-platform-be-organic-rifle-platoons), [Canadian Army wiki](https://army.ca/wiki/index.php/60_mm_Mortar), [Commando mortar](https://Www.Wikipedia.org/wiki/Commando_Mortar)
- Pocket recon drone: [Black Hornet (Wikipedia)](https://en.wikipedia.com/wiki/Black_Hornet_Nano), [Popular Science](https://www.popsci.com/technology/black-hornet-drone/)
- Ground robots for casualty evacuation and logistics: [ASPI Strategist](https://www.aspistrategist.org.au/ground-robots-are-transforming-battle-casualty-evacuation-in-ukraine/), [Defense News](https://www.defensenews.com/unmanned/2026/05/08/ukraine-ramps-up-ground-robot-production-to-spare-soldiers-haul-ammo-and-rescue-grandma/)
- Breaching categories: [Wikipedia: Door breaching](https://en.wikipedia.org/wiki/Door_breaching)

## Decided (user, 2026-11-22)
- **First op:** the Dobrev Freight depot, at night. Hacking it gives you the briefing (guard rota, manifests) and its CCTV in the fight. Enemy: depot guards plus a Bureau escort.
- **The FPV drone:** you fly it, first person, on a few seconds of battery, while the fight runs slowed.
- **Gear depth:** Tarkov-lite: about 8 stats on an inspect card, 3 round types, 3 plate classes, a handful of attachments.
- **Squad:** 4 named fighters, one of them a medic.

## Reference 06 (user, 2026-11-22, sent mid-build; not saved as a file yet)
An "UPRISING / FIELD NOTES // RESISTANCE DOSSIER" sheet in our exact pixel style:
- the garage as home base (CRT, the box, pegboard, med shelf, people working);
- **CAM 01**, a helmet-cam hallway with the medic's red cross on her back;
- **OPERATORS:** hooded, plate carrier, medic with a bag, radio operator with a tablet;
- **FIELD MED:** a bandage on an arm under a hanging lamp;
- **DRONE FEED** over a dusk field;
- **SECURITY CAM (HACKED)** over a wet loading yard with a truck and a fence;
- **GEAR** (rifle with attachment callouts), **MEDS**, **SIGNAL** (the hacking kit);
- **CAMERA SIGNAL UPGRADE 1 > 2 > 3:** the same feed going from blocky noise to clear. That's "cam stars = feed quality", drawn.

The user plans to make more of these, from screenshots of the game.

## 8. Yelled commands: they're their own people (user, 2026-11-22)
*User, after seeing the look test: "OMG YES, this is exactly what I meant. Keep the pace down. They are their own people, but you yell commands", like a Punisher scene of two old battle buddies clearing a place. "You can get in on the action, but far enough away that if they die it's like: omg, that was MY fault, not Jeff's!"*

- **Slow and deliberate.** Walking pace, a breath at every door, short bursts, the dying tube light flickering. Never twitchy.
- **You're on the radio, close by** (the van outside, the next building). You see what your sensors give you and shout. You can go in yourself, but you're the leader: if you die, the run ends.
- **Shouts are short and real-sounding,** sent over the radio:
  - **Move and focus:** stack on that door; breach it (open quietly, kick, bang a flash, blow a charge); push into a room or down a hall; hold; fall back; regroup on a spot.
  - **Fire:** cover left or right or that door; suppress that spot; focus that target; weapons tight or free.
  - **Care:** medic on someone; pull them out; reload now.
  - **Call-ins:** drone up; the FPV you fly; later the mortar.
- **They answer back and decide how:** "Copy, stacking on two." They react on their own and call things to you: contact left, I'm hit, mag, room clear, door's locked.
  - Under fire, they take cover before obeying.
  - Rookies hesitate and sometimes funnel into the doorway; veterans anticipate.
  - A fighter with a trait may push back: "Negative, he's still moving in there!"
- **Fault is visible.** The op report logs every shout with its time ("23:44 you: PUSH the warehouse"), so a death traces back to an order, or to them ignoring one.
- **No shouts = doctrine.** Left alone, they still clear the next room by doctrine. Your shouts set the focus and the risk.

### Decided (user, 2026-11-22)
- **Shouting:** the shout wheel (hold right mouse) plus a click on the door, room or enemy in the feed; number keys pick who it's for.
- **Pace:** real time with a full pause allowed, undecided between the two long-term ("a fan of harder games"). **No slow-motion** ("slowing down is for normies"). Build both: real time, plus a pause that can be switched off (hard mode).
- **Guards fight, flee or surrender** (you choose to zip-tie them, or not). Bureau escorts never surrender.
- **You:** in the van outside for now. Later, "long-distance connection" upgrades (antennas and so on) let you command from the war room, and advisors can choose for you, so it can truly run itself. Base level first.

## Build: the first fight (2026-11-22)
Title screen > **Combat: depot raid** (`v2/combat/fight.tscn`, content in `data/v2/combat/depot.json`).
- **The building:** made from the room and door list (`level.gd`): a corridor, a break room, a store room (locked), a security room, and the dispatch office with the manifests. Doors open, get kicked in, or get blown. Lights flicker; the dark limits sight.
- **Four named fighters** (`actor.gd` = soldier + combat state):
  - stats come from their gear (`rules.gd`, Tarkov-lite): round types against plate classes, attachments;
  - every mag, med, flash and charge is counted;
  - they reload on their own and bandage themselves;
  - downed fighters bleed out unless patched.
- **Doctrine** (`squad_ai.gd`): stack, a breath, breach (open / kick a locked door / bang / charge), flow in one at a time to the corners (the rear man holds the hall), call it clear, move to the next room, take the objective, walk out. The medic waits out the shooting unless you shout MEDIC. Anyone who gives up gets zip-tied.
- **Guards** (`enemy_ai.gd`): sit, patrol, see your weapon lights, hear shots and kicks (muffled through walls), fight back. They run or surrender when their nerve breaks. The Bureau escort never gives up.
- **You** (`fight.gd`):
  - **the shout wheel** on right mouse: stack, breach, bang & clear, push, hold, fall back, cover, focus, medic, carry on;
  - click the target on the main feed;
  - **1-4** pick who you're talking to; **Tab** or a tile click switches the feed;
  - **Space** pauses; **G** carries on.
  - Once you take control, they wait for your next call.
- **Feeds:** helmet cams for all four plus two hacked CCTV, live tiles along the bottom. A dead fighter's cam goes to NO SIGNAL.
- **Radio:** barks as subtitles with a squelch. Gunshots, kicks and flashes are made in code (placeholders).
- **The op report:** every fighter (status, shots, hits, meds left), what happened to every guard, and **every shout you gave and when**.
- **Tested** with bots: doctrine alone succeeds sometimes and fails sometimes (the Bureau escort in the security room); a "bang & clear" shout on that door turned the same fight into a clean win.
- **Not yet:**
  - the FPV and recon drones;
  - the mortar;
  - walking yourself in from the van;
  - better animations (no reload or bandage motions yet, just poses);
  - real sounds;
  - the loadout screen and the link to the stash, the depot hack and the garage;
  - balance (it's random and swingy).

## 9. Commanding from the van: what the first playtest showed (user, 2026-11-22)
**The user's notes:**
- Operators phased through walls and each other. *Fixed the same day.*
- Giving commands is hard: you can't move the camera to show what you mean.
- "Bang and clear" from a bad angle made them walk across the open doorway, then breach. *Fixed (split stacks).*
- They should really think for themselves: if a command puts them in danger, they don't do it right away, maybe only after prodding, and that's what gets them killed. Learning how to command is the balance.
- "Look this way" commands; they still fire on their own if an enemy appears. That awareness comes from training, reaction speed and weapon ergonomics.
- When firing starts, people don't walk in front of each other's muzzles. *Done: they hold fire and wait for the gap.*
- Slow is smooth, smooth is fast. That's the idea.
- It's hard to get them moving through the objective. Maybe a drone, or "team, look this way", then telling them where to go. Or scrap the helmet cams and go Door Kickers. But the user loves the cams ("I haven't seen it in a popular game yet").
- "Otherwise it's pretty fun so far. This is exactly what I was thinking."

**What the research says:**
- **SWAT 4:** you look at a door and open a menu that changes with what you're looking at: open & clear, flash & clear, pick the lock, blow it, stack up. Players' biggest complaint: they couldn't tell the team "breach, throw a flash, and wait." ([GameSpot](https://gamespot.com/reviews/swat-4-review/1900-6121423/), [GOG forum](https://www.gog.com/forum/swat_series/swat_4_is_there_a_way_to_tell_the_other_team_to_breachbangetc_when_not_near), [SWAT 4 guide](https://rentry.co/swat4-guide))
- **Ready or Not:** great gunplay, let down by squad AI that freezes, ignores orders and moves through people. Players want hold fire and take cover. ([TechRadar](https://www.techradar.com/gaming/ready-or-not-review), [SI](https://videogames.si.com/reviews/ready-or-not-review))
- **Rainbow Six 3:** plan the routes on a floor-plan map before the op; teams follow waypoints and wait for "go codes" so several teams enter at once. ([planning advice](https://www.cyberly.org/game-cheats/pc-walkthroughs/rainbow-six-3-raven-shield-general-planning-advice.html))
- **Hesitation that works:** Days Gone gives each squad a confidence number from strength, weapons, armour and health; low confidence means retreat. Ghost Recon Wildlands' buddies "do what the player asks as well as the circumstances allow". The lesson across all of them: **make refusal legible and tied to state, never random.** ([80.lv on Days Gone](https://80.lv/articles/days-gone-squad-coordination-explained), [Game Developer on Wildlands](https://gamedeveloper.com/design/why-friendly-ai-cheat-in-ghost-recon-wildlands), [Game Developer on Halo 5 squad commands](https://www.gamedeveloper.com/design/the-playbook-how-to-improve-squad-commands-in-halo-5-and-other-shooters-))

**Proposal (Claude):**
1. **The ops board (point here, watch there).** A small floor plan beside the feeds, drawn like a paper plan with tokens (Radio Commander style), not a top-down battle view.
   - Your people are dots from their radio trackers; enemies are marks only where someone saw them, fading to "last seen".
   - You right-click a door or room on the board for a SWAT 4-style context menu, including the missing one: **breach, flash, and wait**.
   - **The board comes from intel:** the depot hack gives you the blueprint and guard rota. Without intel, rooms are blank and get sketched in as your people walk them. That makes hacking pay off directly in fights.
   - The fight itself is still only seen through the cams. The gear stays the star.
2. **Look this way.** Drag on the main feed to ask the wearer to turn toward something. They do it at their own reaction speed (training plus weapon ergonomics), and they still snap to any threat on their own.
3. **They think before obeying.** Every order gets a danger read:
   - an unknown room, or one with known enemies;
   - no flash ready;
   - crossing a funnel, being under fire;
   - wounded or low on ammo.
   Each fighter has a threshold from training, trait and nerve.
   - Over the threshold, they **push back with the reason and an alternative**: "Boss, we don't know what's in there. Let me bang it first." You get two buttons: their way, or **again = do it anyway**.
   - Prodded, they go, but hesitantly (slower reactions), and the report says *ordered twice over Ada's objection*.
   - Veterans object rarely and are usually right; rookies object to everything, or never and get killed.
4. **Slow is smooth.** Training sets the doctrine pace:
   - rookies rush or freeze;
   - trained teams go slow and smooth;
   - veterans go smooth and fast.
   "Move to" on the board walks them through, clearing what's on the way.
5. **Drones later:** the recon micro-drone becomes the free camera you fly. It's earned at the bench, so it's progression too.

### Decided (user, 2026-11-22)
- **The ops board plus the cams:** point on a paper floor plan, watch through the cams. The plan comes from intel; without it, rooms get sketched as they're walked.
- **Pushback:** the reason plus their way, or prod (the same shout again) to make them go anyway, slower and shakier. The report logs the overruled objection.
- **Look:** drag on the main feed to make the wearer turn, at their own speed.
