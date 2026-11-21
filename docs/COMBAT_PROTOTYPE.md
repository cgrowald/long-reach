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

## 4. Gap questions before building (answer what you can)

1. **Camera:** in the prototype, which do you want to try first?
   - a drone view (above, angled);
   - the CCTV cameras;
   - both, switchable.
2. **Your calls:** a radial wheel on the soldier or door (like our old action wheel)? Or hotkeys? Or both?
3. **Slow motion vs pause:** auto slow motion on contact only? Or can you also pause any time (more control, less tension)?
4. **Hit numbers on screen:** show the percentages floating over heads (XCOM-like, readable)? Or hide them, so you only judge by watching?
5. **The building:** reuse the old gray-box test building for speed? Or should the prototype already be a "government records office" layout?
6. **Your takes:** do you want to film a few drills before I build the clearing behaviour? Or should I build from my own best knowledge and you correct it after watching?
