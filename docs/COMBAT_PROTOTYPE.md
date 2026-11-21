# Combat prototype: watch and decide (plan, 2026-11-20)

*The biggest unknown in the design (GAME_DESIGN.md section 0.3). Before building towns, ops and benches, answer one question:*

> **Is watching a trained squad clear a building fun, and clearly more satisfying than watching rookies do it, with only a few calls from you?**

If yes, the whole game stands on it. If no, we find out cheaply.

---

## 1. What other games teach us (research, 2026-11-20)

- **Squad sets the plan, soldiers carry it out their own way.** A common design is a hierarchy: the squad picks tactics and objectives, and each unit completes its part as it sees fit. That's our model. ([itch.io dev post](https://itch.io/post/15730921))
- **Defilade:** troops take cover, rescue wounded comrades, dive from grenades and vault obstacles on their own, and the enemy AI plays by the same rules. The kind of autonomy we want. ([Steam](https://store.steampowered.com/app/5246700))
- **SWAT 4:**
  - Context orders on a door ("open, bang and clear") make you feel like a team leader.
  - The main complaint: teammates sometimes clear brilliantly and sometimes run straight past an enemy.
  - **Lesson:** sloppy has to read as *rookie*, never as *bug*. ([GameSpot review](https://gamespot.com/reviews/swat-4-review/1900-6121423/))
- **Combat Mission:**
  - Soldiers react on their own (hit the dirt, crawl to cover), but in its plan-then-watch turn system players can't intervene, so automatic reactions frustrate.
  - **Lesson:** keep it real time with **auto slow motion on contact**, so you can always make a call. ([Battlefront forum](https://community.battlefront.com/topic/106112-infantry-tacai-response-to-incoming-fire-while-moving))
- **Steel Division:** a suppression gauge; at max, infantry are pinned and dash for cover. A simple, readable stress model. ([Eugen](https://eugensystems.com/?p=2520))

---

## 2. Prototype scope

**Reuse the old CQB engine.** It already has:
- soldiers who see and shoot on their own;
- doors, flashbangs, the pie maneuver, raised and low-ready poses;
- vision cones, cover, the gray-box test building.

**New in this prototype:**

| Piece | What it does |
|---|---|
| **Skill per soldier** (0-100) | Drives everything below. Three presets to compare: Rookie, Trained, Veteran |
| **Autonomous room clearing** | Given "clear that room", soldiers stack at the door, pick entry order, pie the corner and take their sectors, without you drawing anything. **Skill changes the quality:** a veteran's stack is tight and his pie is smooth; a rookie bunches up, pies late, enters the wrong corner, flinches at noise |
| **Auto dice** | Reaction time and hit chance from skill, stance, cover and the enemy's tier, rolled automatically, shown as small numbers over heads (toggle) |
| **Your calls** (radial or hotkeys, 3-5 per fight) | **Route:** "take the hallway / the stairwell". **Watch:** "you, cover that door". **Work:** "you, hack the camera box / cuff the clerk". **Tempo:** quiet / loud / hold / pull out |
| **Stress** | A suppression gauge; pinned soldiers seek cover. Veterans recover faster |
| **Self-care** | Drag a wounded teammate, react to grenades |
| **Auto slow motion** on first contact (1-2 seconds) | Your moment to call it |
| **Views** | A drone view (high, slow follow) and two fixed CCTV cameras in the building (grainy, which fits the hacking theme) |
| **Op report** | The tally at the end: clean / ghost / no civilians / time, then loot stars |
| **A/B switch** | Run the same building with Rookies, then Veterans, back to back |

**Not in it:**
- the town map, benches, loot economy;
- first-person you;
- big battles.

---

## 3. Your phone videos (motion capture): yes, they can help, in two ways

### A. Behaviour (most valuable, and free)
How soldiers *decide*: spacing in a stack, when the second man moves, the angle and speed of a pie, where each man looks, how a two-man entry splits the room. That's code. Your Army experience is exactly what makes it right.

- **Film short takes** (5-20 seconds each), **side or top-down angle**, whole body in frame, good light, one or two people.
- **Narrate each take** ("this is how we cleared an L-shaped hallway, number two waits until...").
- **Claude can pull still frames out of the videos with Blender** (already installed, nothing to download) and turn them into timings, distances and sequences for the AI.
- **Start with about 12 drills, not 100:**
  1. stack on a door;
  2. pie a corner;
  3. two-man entry (center-fed door);
  4. two-man entry (corner-fed door);
  5. clearing an L-shaped hallway;
  6. T-intersection;
  7. moving down a hallway in pairs;
  8. stairs going up;
  9. low ready vs high ready movement;
  10. a rookie doing it wrong on purpose (bunching, late pie);
  11. dragging a wounded man;
  12. reacting to a grenade or bang.

### B. Animation (later, needs an outside service)
- Tools turn phone video into 3D animation files: Rokoko Vision, Move.ai (the Move One app), DeepMotion, Plask.
- **Free tiers are small;** Rokoko's free tier is about 30 seconds a month, paid from roughly $12 a month. **Check the vendors' pages for current prices.** ([Rokoko](https://rokoko.com/products/video), [Move One](https://apps.apple.com/us/app/move-one/id6448635527))
- The files go into Blender, onto our character rig, then into Godot.
- **This needs your account, and your videos uploaded to their servers.** Your call, later, when we have real character models.
- **For the prototype,** simple blocky poses are enough; movement and timing sell the competence first.

---

## 4. Answers (user, 2026-11-20)

1. **Camera:** both views, drone and CCTV, switchable.
2. **Calls:**
   - **Hotkeys.** Tell them which direction to move, then give a move order, without clicking the exact spot. They use cover intelligently on their own, so you're not running 100 simulations in your head.
   - Plus **stop commands**, and the option to **control each soldier individually to set up defenses.**
   - **Both sides matter:** attacking *and* defending.
3. **Pause:**
   - **If you're not there in person,** you can pause at any time, give new commands, then let it play out.
   - **Slow motion** too, at first, to see whether it's good and to help with soldiers who miss a corner or check it too slowly.
4. **No numbers on screen.** Judge by watching; knowing the numbers takes the fun out of it.
5. **Same gray-box building** for speed, but the system should support longer halls and realistic-sized buildings.
6. **Reference:** the user found a video of a clearing style instead of filming drills ("we don't need a whole lot right now"). Video studied in section 5. Not stored in the repo.

## 5. What the reference video shows (2026-11-20)

A two-minute shoot-house training montage: helmet cams, fast cuts. It's good for **style**, not exact timings. What it shows:

- **Door prep:** the breacher sets up the door (charge and initiator) while the team waits **stacked tight along the wall beside the door**, out of the doorway.
- **Hallways:** a **tight single-file train**, about an arm's length apart. The lead covers the far end of the hall; the man behind covers over the lead's shoulder.
- **Entry:** the team **flows through the doorway without stopping in it** (the doorway is the "fatal funnel"). Each man peels to a different side: the first goes deep along one wall, the second takes the opposite side, and the next ones follow. Weapons are on target the moment each man is inside. Several men are in the room within about 1-2 seconds.
- **The feeling to copy:** momentum and flow. Nobody stands still in a doorway; everybody knows where he's going.

### Clearing rules for the AI (from the video + standard practice)
| Behaviour | Veteran | Rookie |
|---|---|---|
| Stack | Tight, along the wall, out of the doorway | Loose, someone standing in front of the door |
| Gap between men entering | ~0.5 s | 1.5-2.5 s, with a pause in the doorway |
| Direction after entry | Alternating sides, no crossing | Sometimes both go the same way, or one stops at the threshold |
| Pie a corner | Smooth, weapon up, steady speed | Jerky, starts too close to the corner, weapon low |
| Reaction to a target | Fast (reaction time from skill) | Slow, sometimes freezes |
| Hallway train | Tight, the lead covers the far end, the second over his shoulder | Strung out, everyone looking the same way |

## 6. As built (2026-11-20): `tactical/watch/`, from the title screen "Combat prototype"

- **`room_graph.gd`:** the test building's 4 rooms and which doors connect them; "best exit in this direction".
- **`squad_brain.gd`:**
  - direction → stack along the wall beside the door (out of the doorway);
  - open it (quiet) or kick + flashbang (loud);
  - **veterans and trained slice the pie on the open doorway from outside first**;
  - flow in one by one, alternating sides, eyes on their corner;
  - call the room clear;
  - also hold, pull out, one soldier covers a direction, one soldier hacks the camera hub (reveals everyone for 25 s).
- **`watch_cams.gd`:** a drone that follows the squad (mouse wheel zooms) and 3 CCTV cameras with a grain filter; a CCTV camera shows everyone in its room.
- **`watch_main.gd`:**
  - skill picker, hotkeys, fog of war, call-outs over heads ("Going in!", "Contact!", "CLEAR!");
  - auto slow motion on first contact; pause; manual slow motion;
  - green tint on cleared rooms; the op report with stars and tags.
- **Skill** (`data/watch/skills.json`):
  - reaction, accuracy, **accuracy while moving**, plates (damage taken);
  - stack spacing, gaps between entries, hesitation in the doorway, wrong-side entries, standing in the fatal funnel, whether they pie first.
- **Headless results** (the squad clears room after room on its own, quiet tempo):
  - **Veterans:** all 6 enemies down, lose 1-2 people;
  - **Trained:** most enemies down, the squad doesn't survive;
  - **Rookies:** 2-4 enemies down, up to 7 doorway stops.
  
  There is real variance; one windowed veteran run was wiped on the last room.
- **Known rough edges:**
  - placeholder capsules;
  - enemies don't move (they wait aimed at doors once they hear shooting);
  - no wounded-dragging or grenade-dodging yet.

## 7. Controls v2 (2026-11-20, the user's redesign)

- **Select:** left-click a soldier (Shift adds), 1-4, or click empty ground / Q for the whole squad.
- **Right-click a door:** the selected soldiers auto-stack on it by doctrine and wait.
- **The breach plan panel** (`breach_panel.gd`): click the combo, then EXECUTE (Enter).
  - **door:** open / kick / breach charge (only if someone on the stack carries one);
  - **grenade:** none / flashbang / frag;
  - **entry order:** click callsigns or press 1-4, e.g. 3-1-4-2;
  - **slice the pie first** (skipped after a grenade).
  
  You can plan while they're still walking up; they go when stacked.
- **Right-click ground:** move there. WASD pans the drone, F follows the squad.
- **Look** (from the second reference video): tilt-shift depth of field, a muted colour grade, rain over the squad.
- **Next idea logged:** comms tiers. Shouting is slow and only reaches whoever can hear; radios and headsets cut the delay.

## 8. Gap questions before building (answered above)

1. **Camera:** in the prototype, which do you want to try first?
   - a drone view (above, angled);
   - the CCTV cameras;
   - both, switchable.
2. **Your calls:** a radial wheel on the soldier or door (like our old action wheel)? Or hotkeys? Or both?
3. **Slow motion vs pause:** auto slow motion on contact only? Or can you also pause any time (more control, less tension)?
4. **Hit numbers on screen:** show the percentages floating over heads (XCOM-like, readable)? Or hide them, so you only judge by watching?
5. **The building:** reuse the old gray-box test building for speed? Or should the prototype already be a "government records office" layout?
6. **Your takes:** do you want to film a few drills before I build the clearing behaviour? Or should I build from my own best knowledge and you correct it after watching?
