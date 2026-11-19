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

## 11. Art & Audio Direction

- **Clean low-poly.** Flat or lightly textured colors, readable silhouettes, strong lighting. Think stylized, not realistic.
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
| M0 | **Setup** | Godot + git installed, project runs, free camera moves around a gray-box room |
| M1 | **Room clear** | 4 operators, click to move, enemies shoot back, pause works, lock-on camera |
| M2 | **Cover & ballistics** | Materials, penetration, exposure-based hit chance, suppression, stances, lean. Debug overlay. *It feels like cover matters.* |
| M3 | **Planning** | Paths, go-codes, door actions (kick/breach/flash), synchronized breach on two doors |
| M4 | **Scale & variety** | Teams of up to 30, a larger compound map, civilians, hostages, ROE scoring, after-action report |
| M5 | **Covert mode** | Disguises, suspicion, plant/swap items: the "janitor" mission is playable |
| M6 | **Persistence** | Roster, permadeath, injuries, recruitment by agency, save/load |
| M7 | **World map** | Globe, regions, carrier positioning, deploy to missions from the map, time passes |
| M8 | **Enemy network** | Node graph, intel leads, growth, adaptation, retaliation |
| M9 | **Operations** | Multi-step operation templates (supply-chain op, HVT capture, etc.) |
| M10 | **Training & aging** | Facilities, courses, aging, instructors |
| M11 | **World sim & news** | Nations, opinion, funding, other conflicts, generated news feed |
| M12 | **Art & polish** | Low-poly models, animations, sound, UI pass |

M1–M3 is the **vertical slice**. If clearing rooms isn't fun there, everything else gets reconsidered.

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
