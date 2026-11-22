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
