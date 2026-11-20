# UPRISING (working title) — Game Design Document

*Living document and the source of truth for what the game is. Update it whenever a decision changes. Adopted 2026-11-20, replacing the counter-terror design (archived in `docs/archive/`).*

---

## 1. Pitch

You start with nothing: one person, a cover job, a family and a laptop, in a country ruled by a regime. Every campaign generates a new country. You build a resistance from zero:
1. A few people you trust.
2. Secret cells that don't know about each other.
3. Armed groups that free districts at night.
4. An army that **storms the capital and kills the leader**.

The regime hunts you the whole way. Everything you do leaves a trace. If they get close, you pick up your family and move, and lose contacts on the way. Early on, one arrest ends the game. Later you have people who can get you out. Everyone you recruit has a family. Everyone can die for good. Their families remember what you did.

**Built on:** Antistasi (Arma 3 mod: start from zero, grow into an army, enemy aggression scales up).
**Plus:**
- the real constraints of running an underground: trust, communications, supply, money, exposure;
- a **working terminal** as your main tool (the in-game computers of *Welcome to the Game*, Hacknet, Orwell);
- a **Hearts of Iron-style map with text events**;
- **missions only where they matter**, seen from above in pixel-art 3D.

**Not:** open-world Arma, a first-person shooter, or a CQB game.

---

## 2. Design pillars

1. **Start from nothing, grow into a movement.** Each stage plays differently. The variety comes from growth.
2. **Every gain leaves a trace.** Every useful action has a risk of being traced back to you. Lying low costs momentum. Moving costs your family and your contacts.
3. **Everyone is someone.** Recruits, their families and the officers hunting you are persistent named people who remember what happened (Nemesis-like). Death is permanent.
4. **New every time.** A generated country, regime, people and events every campaign.
5. **The real logistics.** Trust, communication channels, money, supplies and safehouses: the real limits of an underground decide what you can do. Abstracted into game systems; the game is about decisions, not instructions.
6. **The terminal is gameplay.** Your laptop is where the underground lives, and it can be seized.

---

## 3. The country (generated every campaign)

- **Map:** a fictional country (never a real one; user decision 2026-11-20) generated each campaign, shown as a stylized map in the spirit of Hearts of Iron:
  - **provinces**, each with **districts** (city quarters, towns, villages);
  - a **capital**;
  - roads, a coast or border, an airport;
  - **neighboring countries** around the edge.
- **The regime** (generated):
  - **Type:** military junta, ruling family, single-party state, theocracy, or a puppet of a foreign power.
  - **The leader:** a named person with a personality (paranoid, vain, cunning, brutal).
  - **Inner circle and factions:** the army, secret police, business elite, clergy, a foreign patron. Each can be turned against the others.
  - **Weak points:** corruption, an unpaid army, an unpopular war, an ailing leader.
- **Each district tracks:**
  - **Sympathy:** hostile → informers → indifferent → sympathetic → yours.
  - **Surveillance:** police presence, cameras, checkpoints, informers.
  - **Control:** regime, contested, liberated.
  - **Economy and population:** students, workers, farmers, minorities. Each group has different grievances.
- **Neighbors:**
  - Each has a stance toward the regime and toward you.
  - They can sponsor you, shelter refugees, or close the border.
  - They can sanction or support the regime, and step in if the war gets ugly. *A brutal movement turns neighbors against you; a popular one draws sympathy* (user note on tyranny, 2026-11-20).

---

## 4. You: the founder, and your family

- You are a person: name, age, face, a **cover job** (teacher, mechanic, IT worker, nurse, journalist…), skills and a home in one district.
- **Family:**
  - a spouse, kids and maybe a parent, all named and generated;
  - each with a job, school, friends and opinions;
  - **you choose whether they know.**
- **Time is the currency.** Every day goes to work (keeps your cover and income), family (keeps them stable) or the cause (everything else). Neglect shows: your boss asks questions, your spouse gets suspicious, your kid's grades drop.
- **Moving (going to ground):**
  - **Costs:** money, your cover job, your spouse's job, your kids' school.
  - **Communication:** some of your channels break and some cells go silent until contact is restored.
  - **Gains:** the hunters lose your trail.
  - **Strain:** family stress rises each move. Too much stress, and family members may leave, talk, or need rescuing.
- **Losing:**
  - **Early game:** you are arrested and nobody can get you out → **game over**. You are killed → game over.
  - **Later:** "get out of jail" capacity:
    - a lawyer network;
    - bribed guards;
    - a prison break mission;
    - a prisoner swap after you've taken hostages of your own.
  - The beginning is the most brutal on purpose.
- **Win:** storm the capital and kill (or capture) the leader. It takes an army.
  - **The epilogue** describes what you became, based on how you won: a liberator, a strongman, a new tyrant. Brutal methods along the way make the ending, and the neighbors, worse.

---

## 5. The terminal (your laptop)

The main interface for the underground, presented as a working computer. An "OS" with apps:

| App | What it does |
|---|---|
| **Messages** | Encrypted chats with your contacts and cell leaders. Messages take time depending on the channel, and can go unanswered, arrive late or be intercepted. Orders go out here. Some events arrive here as conversations you answer. |
| **Web** | A fictional internet: state media, forums, an underground site, social feeds. **Post propaganda** to win followers; each post can raise sympathy and also exposure. Evidence you leak (stolen documents, photos) is what makes people believe you. |
| **Network** | Your org chart: people, cells, who knows whom, their loyalty and their exposure. |
| **Map** | The country map from the underground's point of view, with your safehouses, caches and routes. |
| **Wallet** | Money, sources and transfers. Each source leaves its own kind of trail. |
| **Files** | Stolen documents, photos and dossiers on officials. Evidence for propaganda or blackmail. |
| **News** | The regime's news next to the underground's version of the same events. |

- **The laptop is a liability.** If a safehouse is raided while it's there, it can be seized, and everything on it becomes the regime's intel about you. **Wipe it** in time (you lose your files) or hide it. Opsec upgrades come later: encrypted drive, a dead-man switch.
- **Home life is outside the laptop:** your home (kitchen table, kids, the knock on the door) is where family events play out.

---

## 6. The network (inverting what was built for M7)

- **Recruiting goes through trust.** You recruit from people your existing members know.
  - Every recruit has hidden **loyalty, nerve and discretion**, and may be a **regime informant**.
  - **Vetting** (time, tests, background checks) reveals some of it. Skipping it is a gamble.
- **Cells:**
  - Members are grouped into cells; a cell knows only its own leader.
  - **Linking cells** speeds coordination, and means one arrest exposes more of the network.
  - **Cutouts** (go-betweens) are safer and slower.
- **Communication channels**, each with a speed, a safety level and a cost:
  - **meeting in person:** fast, risky;
  - **courier:** slow;
  - **dead drop:** slowest, safest;
  - **burner phones:** fast, but traceable over time;
  - **encrypted apps:** fast until compromised.
  
  The regime can **crack** channels; you learn it when a message is read or a meeting is ambushed.
- **Exposure, at every level:** the founder, each person, cell, safehouse and channel.
  - Actions leave **traces**: money moving, faces on cameras, phone metadata, a recruit who talks under arrest.
  - Each trace raises the regime's intel on a specific person or place, as with the M7 network intel, inverted.
  - **Responses:** lie low (costs momentum), move someone, burn a channel, or **cut a cell loose**.
- **Arrests:**
  - Arrested members may hold out, talk, or be turned and sent back as informants.
  - What they know is what the regime learns: compartmentalization pays off here.

---

## 7. The people remember (Nemesis-like)

- **Every recruit has a family:** named parents, siblings, a spouse, kids, generated with the recruit.
- **When a recruit dies or is arrested, the family reacts** according to their personality and what happened:
  - **grieves** and stays quiet;
  - **joins you** to finish what their son started;
  - **blames you** and goes to the police → an informant who knows faces;
  - **seeks revenge** on you personally.
  
  They persist and remember. A brother you ignored can show up years later in a police uniform.
- **The hunters are people too:**
  - a named **police investigator**, then a **secret police officer**, then an **army commander**, assigned to your case;
  - they gain rank and resources when they score against you, and get scarred, sidelined or replaced when you embarrass them;
  - they can be bribed, blackmailed or killed. Killing one brings a harder successor and a crackdown.
- **Relationships inside the movement:** loyalty to you, friendships and rivalries between members, romance, and grudges over who got left behind.
- *Note: the Nemesis System is patented by Warner Bros. This is a personal project; if it ever ships, check that patent before release.*

---

## 8. Supply and money (the real constraints)

- **Money sources** (each with a trail and a risk):
  - small donations;
  - diaspora abroad;
  - a front business you run;
  - smuggling;
  - robbery (high heat, hurts sympathy if civilians suffer);
  - a **foreign sponsor**, whose money comes with demands: targets, ideology, loyalty.
- **Supplies:**
  - medical, documents, phones, vehicles, weapons and later drones;
  - acquired by purchase, theft, raids on depots, smuggling over the border, or defectors bringing their own;
  - kept in **caches**, which can be found.
- **Routes:**
  - supplies move along roads between districts;
  - **checkpoints** and surveillance on a route raise the risk of interception;
  - lost shipments leave traces.
- **Safehouses:** each has a capacity, a cover story, a neighborhood's sympathy and an exposure level.
- **Upkeep:** people need money and food, and families of the fallen expect support. Not paying them is a choice with consequences.

---

## 9. Growth stages (and how the regime escalates)

| Stage | You have | Typical actions | The regime responds with |
|---|---|---|---|
| **1. Alone** | yourself, a few contacts | find people, first propaganda posts, small money, gather proof | ordinary police, informers |
| **2. Network** | cells, safehouses | recruit, vet, propaganda, steal documents, **break into government buildings for proof**, **take out surveillance cameras** to open up districts | a named investigator, wiretaps, raids on suspects |
| **3. Insurgency** | armed groups | ambushes, sabotage, freeing prisoners, holding a district at night, crude **drones** for scouting | secret police, curfews, checkpoints, collective punishment (which can backfire) |
| **4. Open war** | an army, liberated provinces | defend towns, take bases, win over army units, foreign support | the army, air power, foreign advisers, massacres that turn the world against the regime |
| **5. The capital** | a movement | general strike, defections, the final assault | the leader's guard, last stand |

- **Regime escalation** (like Antistasi's aggression system): its response stage rises with your visibility and your attacks, and falls if you go quiet. Each stage brings new tools and new named enemies.

---

## 10. Actions: map, events and missions

- **Map actions:** most things are orders on the map or terminal. They take days, use people and supplies, and resolve with a chance of success and a chance of a trace.
- **Text events** (Hearts of Iron-style) come from a **storyteller** (as in RimWorld). It reads the state of the country and picks from a large library of event templates filled with the current world. Events chain into stories with choices.
  - Examples: a student protest you can join or exploit; a recruit's mother at the police station; a foreign journalist asking for an interview; the regime offering an amnesty.
- **Missions** for the moments that matter, top-down / third-person in pixel-art 3D, reusing the tactical engine:
  - break into a ministry for proof;
  - take down a camera network;
  - free a prisoner;
  - an ambush;
  - escape a raid on your safehouse;
  - later, battles for towns and the capital assault (RTS-scale).
  
  **Every mission can also be auto-resolved** from your people's skills, gear and plan.

---

## 11. Time

- Continuous calendar in **days**, with pause and speed controls, as in Hearts of Iron.
- Actions take days or weeks. Events pause the game.

*Claude's call; the user can overrule.*

---

## 12. Art and tech

- **Look:** pixel-art low-poly 3D, top-down or third-person for missions; a clean stylized map; a crisp retro-OS terminal.
- **Tech:** Godot 4.7, GDScript. Architecture rules as before:
  - simulation in `sim/`, separate from presentation;
  - data-driven (`data/` JSON);
  - one tactical engine;
  - everything serializable;
  - debug overlays.
- **Reuse from the counter-terror build:**
  - people (portraits, roster, wounds, memorial, service records);
  - the network sim (inverted into the regime's investigation);
  - the tactical engine (missions);
  - research (becomes capabilities / opsec upgrades);
  - UI theme;
  - map drawing (zoom, pan, glow).

---

## 13. Roadmap

Each milestone ends playable.

| # | Milestone | Done when |
|---|---|---|
| U1 | **The country and you** | Generated country map (provinces, districts, capital, neighbors, regime and leader); you and your family with a cover job; day calendar with pause/speed; daily time split between work, family and the cause; new campaign from a seed |
| U2 | **The terminal** | Laptop OS with Messages, Web (post propaganda → followers and sympathy vs exposure), Network, Map, Wallet, News; first contacts by chat |
| U3 | **The network and the hunt** | Recruiting through trust, hidden loyalty and informants, vetting, cells, channels, exposure and traces, a named investigator, arrests, interrogation, **prison = game over**, moving house |
| U4 | **Storyteller and events** | Director plus the first ~100 event templates with chained stories and choices; HOI-style event popups |
| U5 | **Money and supply** | Sources with trails, caches, routes, checkpoints, safehouses, upkeep, the foreign sponsor |
| U6 | **People remember** | Recruits' families, reactions to death and arrest, revenge and informants, hunters who rank up and remember |
| U7 | **First missions** | Break-in for proof, cameras, prisoner rescue, safehouse escape, on the tactical engine with stealth; auto-resolve |
| U8 | **Insurgency** | Armed groups, districts held at night, regime escalation stages, drones, jail-break capacity |
| U9 | **War** | Army units, liberated provinces, battles, neighbors intervening, sanctions |
| U10 | **The capital** | Final assault, the leader, epilogues by how you won |

---

## 14. Open questions

- [ ] Working title: "Long Reach" no longer fits. "Uprising" is a placeholder.
- [ ] Ideology of the movement: chosen at start, emergent from your choices, or left out?
- [ ] How much the founder fights personally (risking game over) versus commands from the shadows.
- [ ] Multiple game-over rules later (the movement survives without you? a successor?).

---

## 15. Decisions log

| Date | Decision |
|---|---|
| 2026-11-20 | **Game switched** (user): you are the founder of an underground resistance in a generated country, growing from nothing to an army (Antistasi as the groundwork). Win = storm the capital and kill the leader, which takes an army. Counter-terror design archived. |
| 2026-11-20 | A newly generated fictional country every campaign (never a real one). Neighboring countries exist and react, especially if you become a tyrant. |
| 2026-11-20 | Real-life underground constraints are the core: supply network, communications, exposure. Every gain risks a trace; getting traced means moving your family and losing contact with cells. |
| 2026-11-20 | Early prison with no one to free you = game over. Later you earn ways out. The start is the most brutal. Lost lives are permanent. Every recruit has a family that remembers and can come after you or snitch (Nemesis-like). |
| 2026-11-20 | A working in-game terminal (laptop) is a core interface: propaganda websites for followers, stolen proof so people believe you. Missions such as breaking into government buildings for proof and taking out surveillance cameras to open districts. Drones later. |
| 2026-11-20 | Presentation: Hearts of Iron-style map with text events, plus real gameplay in the terminal and in specific missions. Pixel art, top-down / third-person. Not open-world Arma; not a CQB game. |
| 2026-11-20 | Claude's calls (overrulable): working title "Uprising", time in days with pause/speed, epilogue by method, missions auto-resolvable, U1-U10 roadmap. |
