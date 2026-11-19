# LONG REACH — Game Design Document

*Working title. Living document: this file is the source of truth for what the game is. Update it whenever a decision changes.*

Last updated: 2026-11-19

---

## 1. Pitch

You run a covert counter-terror organization fighting a terrorist network that has spread **everywhere**: compounds in the desert, smuggling routes through ports, sleeper cells in American cities. You recruit operators from the CIA, the military and police units, train them, and send them on every mission that matters. That ranges from a 30-man raid on a mountain compound, to a 4-man hostage rescue in a Florida government building, to one guy in a janitor's uniform planting a device.

There is no countdown timer. The world moves on around you, the network grows and reacts, and the news reports what you did. You choose what to pursue and how.

**Comparable feel:** Door Kickers (planning and close-quarters combat), the XCOM world map (without the rush), carrier command games (a mobile home base), and the long multi-step intelligence operations of real counter-terror campaigns.

---

## 2. Design Pillars

Every feature has to serve at least one of these. If it doesn't, it gets cut.

1. **Cover is king.** Exposed people die. Walls, materials, angles and suppression decide fights, not stats.
2. **Plan, then execute.** The best missions are won in the planning screen. Real-time with pause lets you adapt when the plan breaks.
3. **Every mission that matters.** Missions range from loud raids to quiet infiltrations. They all use the same engine and the same rules.
4. **The world remembers.** Actions have consequences: collateral damage, public opinion, the network adapting, host nations cooperating or refusing.
5. **People are the resource.** Operators are scarce, take time to train, age, and die permanently. Veterans become the instructors for the next generation.

---

## 3. Key Scope Decision: what "open world" means here

**Decision:** The "living world" is a **simulated world shown on a strategic map**, not a GTA-style city you walk around in.

- The world sim tracks nations, cities, the enemy network, public opinion, other conflicts and the news. It all runs underneath the world map and the news feed.
- When you act somewhere, the game loads a **3D tactical map** for that place: a compound, a port, an office building, a street block. The world's state shapes that map: how many guards, whether civilians are present, police response time, how alert the enemy is.

**Why:** A fully walkable open world is what costs AAA studios hundreds of people. A simulated world gives the same feeling ("the world cares what I do") at a scale one person and an AI can actually finish. Tactical maps can still be big, for example a whole village or a city block.

**News:** The news feed is **generated from in-game events** in a fictional but realistic world. Example: "Explosion at Port of Aqaba warehouse — 3 dead, authorities suspect smuggling dispute." Real-world current events are not pulled in (see Open Questions).

---

## 4. Game Structure: three layers

```
 WORLD (strategic, map of the globe)
   │  intel leads, network nodes, carrier position, budget, opinion
   ▼
 OPERATIONS (multi-step plans against a target)
   │  e.g. "Dismantle the Aleppo financing node" = 4 linked missions
   ▼
 MISSIONS (3D tactical, real-time with pause)
      raid / rescue / infiltration / surveillance / sabotage / capture
```

### 4.1 World layer
**Feel target: a dynamic campaign map in the spirit of Gates of Hell's conquest mode** (user's reference), adapted to a global covert war. The parts we want:
- The map is split into **regions/sectors**. You move your teams and assets between them; the enemy network has a presence in each.
- **Persistent forces:** the same squads go from battle to battle, carrying their wounds, losses, equipment and experience.
- **You choose which fights to take**, and each one is played out on a tactical map built from that sector.
- **Resources** (funding, political capital, intel) buy reinforcements, recruits and equipment between battles.
- **The enemy moves too:** cells spread into new sectors, reinforce, and strike back where you're weak.
- Our own twist: no fixed front line. The enemy is everywhere at once, and the carrier is your mobile HQ.

Further details:
- A globe or world map with regions, countries and cities.
- Time passes in hours and days. You can pause or speed it up. Nothing forces you to act right now, but the network acts if you leave it alone.
- You see: known network nodes, intel leads (with confidence %), your assets (carrier, teams, safehouses), world events and the news ticker.

### 4.2 Operations layer
The heart of "make plans like that against your enemy." An **operation** is a chain of missions and actions aimed at one network node.

**Example: Operation "Static" (a supply-chain op):**
1. *Intel:* Surveillance reveals the network buys communication devices through a front company.
2. *Mission (covert):* Infiltrate the front company's warehouse and identify the shipment.
3. *Action:* Intercept and modify the shipment. This takes time and a technical specialist, and carries a risk of discovery.
4. *Mission (covert):* An operator poses as a janitor at the distribution site to make sure the devices reach the targets. Includes a suspicion meter.
5. *Execute:* Trigger the op. The outcome depends on how many devices reached real targets compared to bystanders. Collateral damage affects opinion. The network is crippled in that region but shifts to new communications.

Operations come from **templates** (supply-chain sabotage, high-value capture, financial disruption, turning an informant, raid) filled in with the actual world state. That gives variety without hand-making every one.

### 4.3 Mission layer (tactical)
See section 6.

---

## 5. The Enemy Network

- Built as a **graph of nodes** spread across regions. Node types:
  - Leadership, Financing, Logistics/Smuggling, Recruitment, Bomb-making, Training camp, Sleeper cell, Propaganda
- Nodes are connected. Capturing or interrogating one node reveals intel on the nodes linked to it.
- **The network grows** slowly: it recruits, opens new cells, and plans attacks, which have a visible preparation time if you have intel on them.
- **The network adapts:**
  - If you hit them loudly, nearby nodes go dark or relocate.
  - If you compromise their communications, they switch to couriers, which are slower but harder to track.
  - If you embarrass them, they retaliate, possibly on domestic soil.
- **Domestic threat:** Sleeper cells in the US and Europe lead to the high-stakes, low-collateral-tolerance missions.

---

## 6. Tactical Missions

### 6.1 Core
- **Real-time with pause.** Orders can be given while paused. Optional auto-pause on events: contact, man down, door opened.
- **Camera:** Full free camera (pan, rotate, zoom), plus **lock-on follow** for any operator or asset (helo, drone, vehicle).
- **Unit count:** 1–30 operators.
  - 1–8: individual control.
  - 8–30: grouped into **teams** (fireteams or squads) with team-level orders. You can drill down to individuals at any time.

### 6.1a Control philosophy (user decision)
- **Only seeing and shooting are automatic.** Soldiers spot enemies in their vision cone, turn onto them and fire on their own.
- **Everything else is the player's choice:** opening or kicking doors, breaching, throwing grenades, stance, pace, where to look. Nothing happens unless you ordered it. A soldier who walks into a closed door stops and waits.
- **Action wheel:** right-click a door or one of your soldiers to open a radial menu of the actions available. Right-click the ground to move.
- **Classes decide the options.** What you bring determines what you can do:

| Class | Weapon | Kit | Wheel options |
|---|---|---|---|
| Assaulter | Rifle | Flashbangs, frag | Open, kick, stack up, flash in, frag in |
| Breacher | Shotgun | Breach charges, flashbang | Open, kick, **breach charge**, stack up, flash in |
| Marksman | Marksman rifle (long range, narrower view) | Frag | Open, stack up, frag in |
| *Later:* Shield, Medic, Pointman, Tech (sensors, drones), Covert | | | |

- Loud objectives mean you bring loud classes; covert jobs bring covert specialists. Picking the team for a mission is part of the planning (M4).

### 6.2 Planning phase
- Before the mission starts, while paused or with time frozen:
  - Draw **movement paths** per operator or team.
  - Set **go-codes** (Alpha, Bravo, Charlie) so teams can wait at a door and breach at the same time.
  - Assign door actions: open, kick, breach charge, flashbang-then-enter.
  - Set facing and "hold angle" orders.
  - Set the rules for engaging (weapons free, weapons tight, hold fire).
- Plans can be edited mid-mission while paused.

### 6.3 Cover & ballistics (pillar #1)
- **Materials** each have a penetration resistance:
  - Glass < drywall < wood door < car body < brick < concrete < steel
- **Calibers** penetrate differently: pistol < 5.56 < 7.62 < .50 cal. Shooting through drywall is valid, and so is being shot through it.
- **Exposure:** Hit chance comes from how much of the body is visible from the shooter's point of view: stance, lean, cover height. Real line-of-sight checks, not a "half cover / full cover" label.
- **Suppression:** Incoming fire builds suppression. Suppressed units aim worse, move slower, and may refuse to peek. Fire-and-maneuver works.
- **Stances:** Stand / crouch / prone, plus lean left and right at corners.
- **Damage model:** Hit locations (head, torso, limbs) with armor zones. Wounded units are slowed and may need help or extraction.

### 6.4 Vision & information
- Fog of war: you only see what your units see or hear.
- Sound: gunfire and breaches alert nearby enemies. Suppressed weapons reduce the radius.
- Drones, cameras and informants can reveal parts of the map before entry.

### 6.5 Covert mode (same engine)
- **Disguises:** Janitor, delivery driver, guard, local civilian. Each disguise allows certain zones.
- **Suspicion:** Each NPC observes you. Running, carrying weapons, entering restricted areas, or being seen by someone who knows the real staff raises suspicion. If it fills, the alarm goes off and the mission may turn loud.
- **Interactions:** Plant item, swap item, pick lock, install bug, photograph documents, escort informant.
- Covert missions are often 1–3 operators with a team on standby.

### 6.6 Civilians, hostages & ROE
- Civilians move, panic, flee, freeze or get in the way.
- **Rules of engagement are set per mission by the theater** (see section 8).
- After-action report scores: objectives, casualties (friendly, enemy, civilian), collateral damage, noise and exposure.

### 6.7 Mission types (initial list)
| Type | Size | Typical theater | Notes |
|---|---|---|---|
| Compound raid | 8–30 | Middle East, Africa | Air support possible, loose ROE |
| Hostage rescue | 4–12 | Anywhere, often domestic | Strict ROE, time matters once alerted |
| High-value capture | 4–12 | Anywhere | Target must survive |
| Covert infiltration | 1–3 | Urban | Disguises, no weapons visible |
| Sabotage / plant | 1–4 | Any | Part of operation chains |
| Surveillance | 1–4 | Urban | Avoid detection, gather intel |
| Interdiction | 6–20 | Ports, roads, sea | Vehicles, convoys |

---

## 7. People: Recruitment, Training, Aging

### 7.1 Recruitment
Operators are pulled from **source agencies**. Each agency has a different starting profile:

| Source | Strengths | Weaknesses |
|---|---|---|
| Army special forces | Combat, teamwork, endurance | Covert/social skills |
| Navy maritime special ops | Maritime, assault, breaching | Covert |
| CIA ground branch | Covert, languages, intel | Large-unit tactics |
| FBI hostage rescue | Close-quarters combat, ROE discipline, hostage rescue | Long-range combat |
| Police SWAT | Close-quarters combat, civilians | Military tactics, endurance |
| Partner-nation forces | Local language and access | Varies |

- Recruitment takes time and funding. Pulling too many people from one agency strains relations with it.

### 7.2 Training
- Recruits enter a **training pipeline** before they can deploy.
- Training courses are **unlocked and upgraded** through facility investment: shoot house, sniper range, language school, covert/tradecraft school, medical, explosives/breaching, HALO and maritime.
- Training takes in-game weeks or months. Better facilities train faster and higher.

### 7.3 Aging & instructors
- Operators age. Physical stats decline in their late 30s and 40s, while experience and judgment stay.
- Retiring veterans can become **instructors**. Each instructor boosts the courses in their specialty, so your best people keep shaping the organization after they leave the field.
- **Permadeath.** A dead operator is gone, with a memorial wall. Wounded operators need recovery time, and some injuries are permanent.

### 7.4 Operator stats (draft)
- Marksmanship, CQB, Movement/stealth, Composure (resistance to suppression), Endurance, Medical, Explosives, Tradecraft (covert), Languages, Leadership.
- Traits: earned through experience, e.g. "Steady under fire," "Hesitates on civilians," "Breacher."

### 7.5 Characters you care about (core feeling)
The goal: you **don't want them to die**. Losing someone should hurt because you know them.
- **Every operator is a person:** name, callsign, age, agency they came from, hometown, short bio, pixel portrait.
- **Service record, written automatically:** missions, kills, rescues, wounds, medals, and notable moments, e.g. "Dragged ALPHA-2 out under fire, Aleppo, 2031."
- **Bonds:** operators who serve together build trust, which means better coordination. Losing a close teammate affects morale and can add a "shaken" trait.
- **Injuries persist:** scars, permanent limps (slower), lost confidence. Recovery takes real in-game time.
- **Fatigue and stress:** sending the same people on too many missions leads to mistakes.
- **Death is permanent:** memorial wall with their full service record. A letter to the family.
- **The game rewards bringing everyone home:** medics, carrying wounded, retreat and extraction orders, a mission bonus for zero losses.
- Veterans retire into instructors (7.3), so your best people live on in the next generation.

---

## 8. Theaters & Rules of Engagement

| Theater | Collateral tolerance | Support available | Police/host response | Tone |
|---|---|---|---|---|
| Ungoverned zones (Middle East/Sahel) | High | Carrier air, drones, helos | None/slow | Loud raids |
| Partner nations | Medium | Limited air, local forces | Host may refuse or leak | Political |
| Europe | Low | Ground only | Fast police | Precision |
| United States (domestic) | Very low | Domestic team only | Very fast, media instant | Highest stakes |

Breaking ROE costs opinion, funding and host-nation access. It may also trigger investigations that bench operators.

---

## 9. Assets

- **Carrier group (the mobile HQ):** Positioned on the world map. Its position decides:
  - Response time to each region
  - Range for air support, helos and drones on missions
  - Moving it takes days and is visible to the world, which has political effects.
- **Domestic response team:** A separate home-based unit for missions inside the US. No military air support.
- **Safehouses:** Forward bases in regions. They speed up deployment and enable covert ops there.
- **Drones / ISR:** Reveal maps, track targets, and provide overwatch.
- **Helicopters / vehicles:** Insertion, extraction and fire support on tactical maps.

---

## 10. Resources & Economy

- **Funding:** Monthly budget, influenced by results and public and political opinion.
- **Political capital:** Spent to operate in sensitive places, get partner cooperation, or survive scandals.
- **Intel:** Leads with confidence levels. Acting on low-confidence intel risks empty compounds or traps.
- **Personnel:** The real bottleneck. See section 7.
- **Other conflicts:** Wars and crises break out in the world sim. You *may* lend assets to help, gaining funding, equipment or partner goodwill, at the cost of operators and attention. It's never required.

---

## 10A. Research & Equipment (the long war)

You run this secret organization for **years and years**, and you can feel it getting better. Research works like XCOM's: projects that take time and money, unlocking gear that changes how you fight.

- **Real jumps, not +5%.** Each breakthrough opens a new way to play.
- **Projects cost** money, time (weeks to months) and specialists (engineers, scientists, recovered enemy intel).
- **Sources:** your own R&D, partner agencies, captured enemy tech, reverse engineering.
- **Prototype, then production:** new gear arrives as limited, sometimes unreliable prototypes before it's mass-produced.
- **Arms race:** the enemy network adapts too (counter-drone, encrypted comms, couriers).

**Example tech branches (grounded in real and near-future gear):**
| Branch | Progression examples | What it changes |
|---|---|---|
| Sensing | Through-wall **heartbeat/motion sensor** (short range, shows heartbeats behind walls) → handheld radar → **long-range heartbeat signature tracking**, inspired by the recent CIA story about finding someone in Iran that the user mentioned. Also thermal, night vision (gen 1 → panoramic), acoustic gunshot locators | Tactical: see enemies through walls before breaching. Strategic: locate high-value targets from the world map |
| Entry & mobility | **Grappling hook** and rope (enter from roofs and upper floors), breaching shotgun, frame charges, thermal lance, ladders, fast-rope from helicopters, high-altitude parachute jumps | New ways into a building beyond the front door |
| Drones | Micro drone to scout rooms → armed drones → persistent surveillance overhead | Intel before contact; overwatch |
| Weapons & protection | Suppressors, better optics, higher-rated plate carriers, ballistic shields, less-lethal weapons for captures | Survivability; capture missions |
| Comms & intel | Encrypted radios, signals intercepts, **device exploitation** (needed for supply-chain sabotage ops), facial recognition | Unlocks operation types |
| Medical | Better trauma kits, field surgery, faster recovery, fewer permanent injuries | Keeps your people alive |
| Covert | Disguise kits, forged credentials, device-tampering lab | Covert missions |

---

## 11. Art & Audio Direction

- **Low-poly with a pixel-art look.** 3D rendered at low resolution and upscaled with hard pixel edges, with a limited color palette and flat colors. Charming and readable, not realistic. UI text stays crisp.
- **Readability first:** Friendly vs. enemy vs. civilian must be clear at a glance. Cover and material types should be visually distinct, e.g. drywall looks thin and concrete looks heavy.
- Placeholder "gray box" art until the gameplay is fun. Art is swapped in later without code changes.
- Audio: Punchy weapons, muffled sound through walls, radio chatter for team callouts.

---

## 12. Technical Foundation

- **Engine:** Godot 4 (latest stable), **GDScript**.
  - Reason: free; everything is stored as text so the AI can edit scenes, scripts and data directly; good 3D; small and fast to iterate.
- **Version control:** Git from day one. Commit at every working state.
- **Architecture rules (these prevent rewrites):**
  1. **Simulation separate from presentation.** The rules (ballistics, AI decisions, world sim) don't depend on models or animations. Visuals just display the sim.
  2. **Data-driven.** Weapons, materials, calibers, agencies, courses, mission templates, operation templates, theaters: all defined as Godot Resource files (`.tres`) or JSON, not hard-coded.
  3. **One tactical engine** for every mission type. Covert, raid and rescue are configurations, not separate games.
  4. **Save system early.** Everything persistent (roster, world, network) is serializable from the start.
  5. **Debug tools built in.** Show line of sight, exposure %, penetration traces, AI state, suppression. This is how we tune the "cover is king" feel.

- **Planned folder layout:**
  ```
  /game
    /data         weapons, materials, agencies, templates (.tres / .json)
    /sim          pure rules: ballistics, AI, world sim, network
    /tactical     3D mission scenes, units, camera, orders UI
    /world        world map, operations UI
    /people       roster, training, aging
    /ui           shared UI
    /art          models, materials (placeholder first)
    /audio
  /docs           this design doc, decisions log
  ```

---

## 13. Build Roadmap

Each milestone ends with something **playable**. Don't move on until it's fun.

| # | Milestone | Done when |
|---|---|---|
| M0 | **Setup** ✅ | Godot + git installed, project runs, free camera moves around a gray-box room |
| M1 | **Room clear** ✅ | Click to move, enemies shoot back, pause, lock-on camera |
| M2 | **Eyes & angles** ✅ | Vision cones + fog of war, turn speed, firing arc, facing orders, corner-slicing at doorways, walk/run, hold fire |
| M3 | **CQB bare bones** ✅ | Doors, go-code, flashbangs + frags, crouch with exposure-based hits, slower pace + game speed control, pixel-art look |
| M3.5 | **Classes & action wheel** | Only seeing/shooting automatic; doors block until ordered; right-click radial action wheel on doors and soldiers; Assaulter / Breacher / Marksman with different weapons, kit and options; breach charges |
| M4 | **Characters you care about** | Persistent roster with names, bios, portraits, stats, traits, service records, lasting injuries, permadeath + memorial wall; pick your squad before a mission; after-action report; save/load |
| M5 | **Research & equipment** | Tech tree over in-game years; projects take time, money and specialists; loadouts; first techs: heartbeat sensor, grappling hook, night vision, suppressors, scout drone |
| M6 | **Campaign map** | Sector-based dynamic campaign (Gates of Hell conquest feel): move teams between sectors, choose battles, persistent forces, resources for reinforcements, enemy moves too; carrier as mobile HQ; in-game calendar |
| M7 | **Enemy network** | Node graph, intel leads, growth, adaptation, retaliation |
| M8 | **Operations** | Multi-step operation templates (supply-chain op, HVT capture, etc.) |
| M9 | **Training & aging** | Recruitment by agency, facilities, courses, aging, instructors |
| M10 | **Scale & variety** | Teams of up to 30, compounds, civilians, hostages, ROE scoring, generated maps |
| M11 | **Covert mode** | Disguises, suspicion, plant/swap items: the "janitor" mission is playable |
| M12 | **World sim & news** | Nations, opinion, funding, other conflicts, generated news feed |
| M13 | **Art & polish** | Pixel-art low-poly models, animations, sound, UI pass |
| Later | **CQB depth** | Bullet penetration by material, suppression, leaning, smarter enemy AI (patrols, flanking, surrender), breach charges, multiple go-codes |

The tactical layer only needs to be **good enough** (user feedback after M2: the long war, the people and the research are what make this game, not out-doing dedicated CQB games). Prioritize M4–M6.

---
## 14. Open Questions

- [ ] **Real-world news:** fictional generated world (recommended), or a world inspired by real regions and events? Pulling live real news is not planned.
- [ ] **Setting:** real countries and cities, or fictionalized versions? Real is more immersive; fictional gives more freedom.
- [ ] **Enemy org identity:** name, ideology and look. Fictional is recommended.
- [ ] **Interrogation / informants:** a mechanic, or abstracted?
- [ ] **Failure state:** can the campaign be lost (funding pulled, a major attack succeeds)? Or is it endless/sandbox?
- [ ] **Campaign end:** dismantle the network's leadership, or ongoing sandbox?
- [ ] **Vehicles on tactical maps:** drivable, or scripted insertion/extraction only?
- [ ] **Sniper/overwatch** role at long range on large maps.

---

## 15. Decisions Log

| Date | Decision |
|---|---|
| 2026-11-19 | Engine: Godot 4 + GDScript |
| 2026-11-19 | Real-time with pause; free camera + lock-on |
| 2026-11-19 | 1–30 operators per mission; teams above ~8 |
| 2026-11-19 | Permadeath; recruit from agencies; train; age into instructors |
| 2026-11-19 | Clean low-poly art |
| 2026-11-19 | Living world is simulated on a strategic map, not a walkable GTA-style open world |
| 2026-11-19 | Build tactical vertical slice (M1–M3) before the world layer |
| 2026-11-19 | "Open world" = go anywhere in the world, but a place becomes a playable 3D map only when you send a team there |
| 2026-11-19 | M0 playtested and approved; M1 built |
| 2026-11-19 | M1 playtested and approved. Personal project, not for release |
| 2026-11-19 | After M3: only seeing and shooting are automatic; every other action is chosen through a right-click action wheel; classes define weapons, kit and wheel options. Campaign map should feel like Gates of Hell's dynamic conquest mode |
| 2026-11-19 | After M2: tactical layer only needs to be good enough. Focus moves to characters you care about, XCOM-style research over years, and the world. Pixel-art low-poly look. Combat pace was too fast: slow it down and add game speed control |
