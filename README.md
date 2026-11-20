# Long Reach

Covert counter-terror tactics and strategy. Built with Godot 4.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full design.

## Running
1. Install Godot 4 (Standard edition, not .NET): https://godotengine.org/download/windows/
2. Open Godot → **Import** → select `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (or the ▶ button top-right) to run.

## Campaign
You are hunting a terror network, **the Sixth Hour**: its leader (the Emir), four lieutenants, and their cells around the world.
Every member is a named person with a face you have to uncover. **Win** by killing or capturing the Emir.
**Lose** if the threat level stays at 90+ for 4 weeks (oversight shuts you down).

The game starts on the **campaign map**: 24 regions with enemy strength rings, known attack plots ("ATTACK 3 WK"),
gold **TARGETS** tags where you have located someone, and your **carrier**, whose gold lines show where you can strike.
Each week:
1. Optionally move the carrier: click a glowing **SAIL HERE** box at sea (one zone per week). Coverage builds intel on the cells there.
2. Pick an operation in range (right column, or click a region): **KILL** or **CAPTURE** a located person,
   **STOP THE ATTACK** on a known plot, or a **Blind raid** that hits a random cell and turns up leads.
3. **HQ: pick squad**: **+ SQUAD** on up to 4 operators (or just **AUTO-PICK + DEPLOY**).
4. In the mission the target is gold. On a capture raid he is unarmed and your soldiers will not shoot him:
   select a soldier, **right-click the target > Restrain**. **END OPERATION** (top right) writes the after-action report.

**NETWORK** (map header) shows the org chart: who you know, who is located, who is dead or in custody, and who knows whom.
Captures reveal a target's contacts; capturing lieutenants is how you find the Emir. Raids make nearby cells go dark for a while,
and taking down a lieutenant triggers a revenge plot in the West.

**END WEEK** on the map skips the operation. Plots you don't stop become attacks: they cut your budget and raise the threat level.
The campaign saves automatically.

**Research** (HQ tab): spend funding on one project at a time; it finishes after its days pass (each week).
Finished tech changes missions right away, e.g. the heartbeat sensor shows hidden enemies through walls as red HEARTBEAT blips,
suppressors make gunfire heard at 9 m instead of 20 m, trauma kits shorten recovery. Funding: weekly budget plus a bonus per successful operation.

## Controls
Only seeing and shooting are automatic. Everything else is an order you give.
**Left mouse = feet. Right mouse = eyes.**

| Input | Action |
|---|---|
| Left click a soldier | Select (Shift adds/removes; double-click follows him) |
| Left click ground | Move selected there (Shift = queue, Ctrl = move and wait for GO) |
| Left **drag from a soldier** | Draw his route freehand; from a selected soldier the whole selection follows it (Shift = add to plan, Ctrl = wait for GO at the end) |
| Left drag on empty ground | Box select |
| Right click ground | Look at that point now |
| Right **drag** from a point on a route | From that spot on, watch the point you drag to (solid line). Chain as many as you like along a route |
| Right drag from a soldier | Watch that point starting now |
| **Shift + right** click or drag | Same, but **PIE** it: dotted line with a pie icon; rifle up, slower, faster reactions, covering that point |
| Right click a **door** | Door wheel: Open, Kick, Breach charge, Open + flash, Kick + flash, Stack up (open doors: Flash in, Frag in). Ctrl = do it on GO, Shift = queue |
| Right click a **soldier** | Soldier wheel: Crouch/Stand, Walk/Run, Hold fire/Weapons free, Flashbang, Frag, Stop |
| Enter | GO: waiting soldiers continue, armed breach charges blow |
| Space | Pause (plan everything while paused) |
| - / = | Game speed 0.25x to 2x |
| P | Pixel look on/off |
| WASD, Q/E, wheel, middle-drag | Camera |
| F / Tab | Follow a soldier |
| 1-4 | Select soldier |
| Esc | Cancel / clear selection |
| R | Restart mission |

Soldiers stop at closed doors until you order the door opened. Classes decide the options:
Assaulter (rifle, flashbangs, frag), Breacher (shotgun, breach charges), Marksman (long rifle, no kicking).