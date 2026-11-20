# UPRISING (working title) — Game Design Document

*Living document and the source of truth for what the game is. Update it whenever a decision changes. Adopted 2026-11-20, replacing the counter-terror design (archived in `docs/archive/`).*

*Planning status (2026-11-20): the user wants the full picture before building ("that's how these things die, we start too quickly"). Don't start a milestone until the user says so.*

---

## 1. Pitch

You are nobody: a reluctant family man or woman with a cover job, a garage and a laptop, in a country ruled by a regime. Every campaign generates a new country. Something was taken from you. You build a resistance from zero:
1. A few people you trust.
2. Secret cells.
3. Armed groups.
4. An army that **storms the capital and kills the leader**.

**Late in the game, the stress comes from running all of it:** feeding, arming and supplying an army (like Arthur Sinclair, who runs the Department of Strategic Resources in *World War Z*).

The regime hunts you the whole way. Everything you do leaves a trace. Get traced, and you pack your family into the car and move, losing whatever didn't fit. Early on, one arrest ends the game. Everyone you recruit has a family. Everyone can die for good. Every act of violence is remembered by someone.

**Inspirations, and what we take from each:**

| Game | What we take |
|---|---|
| **Antistasi** (Arma 3 mod) | The groundwork: start from zero, grow into an army, the regime escalates |
| ***Papers, Please*** | Days with **new rules every day**: you keep learning new angles |
| ***Schedule I*** | Incremental building: make → supply → reinvest → expand. Chores become small minigames, then you automate them |
| ***Iron Nest*** | Hands-on, weighty actions in one room, but our mechanics keep changing so it never goes stale |
| ***Welcome to the Game*** / Hacknet | A working computer: our own fun fake OS |
| ***Mount & Blade: Warband*** | Choosing your backstory at the start |
| ***Hearts of Iron*** | Map plus text events |
| ***World War Z*** (Sinclair) | Late-game logistics as the real battle |

**Not:** open-world Arma, a free-roaming shooter, or a CQB game.

---

## 2. Design pillars

1. **Start from nothing, grow into a movement.** Each stage plays differently.
2. **By hand → master → automate → new rules.** Every system starts hands-on, becomes routine, gets handed to someone you trust, and then the regime changes the rules and something new and hard appears. This is the incremental pull and the anti-repetition rule in one.
3. **Every gain leaves a trace.** Every useful action risks being traced back to you. Moving costs your family, your workshop and your contacts.
4. **Nobody is just a target.** The people on the other side have families, reasons and grudges. The regime is bad; its policemen, clerks and conscripts are people. You can become what you fought (the question *Iron Nest* raises: are the targets really the bad guys?).
5. **The story matters as much as the gameplay.** You choose who you are and what was taken from you. It should be able to hit close to home.
6. **The real logistics.** Trust, communications, money, materials, supply, food, ammo and plates decide what you can do. Abstracted into decisions, never real instructions.
7. **New every time.** A generated country, regime, people, events and daily rules.

---

## 2A. The feel of the world (decided 2026-11-20)

**Orwell's *1984*, rebuilt with new-age tech, and built badly.** Not a Nazi feel, not old Russia, not present-day China.

- **Advanced on the surface.**
  - It's the 2040s (the game starts **Monday 14 October 2041**).
  - Smart everything: cameras with face matching, a citizen app, digital ID, smart doorbells that report.
  - Feeds, state influencers, slogans on every screen.
  - Reporting your neighbors is a game with points.
- **The surveillance is everywhere, and it's full of holes.**
  - The tech isn't as good at tracking as people fear.
  - The country's education is poor, so there aren't enough people to maintain it: systems go unpatched, default passwords never get changed, contractors cut corners, databases don't talk to each other, and outages are routine.
- **The AI is dumb.**
  - Not LLM-level: keyword filters, chatbots that loop, face matching that's fooled by a hat.
  - The regime's "smart" systems are often only as smart as the tired clerk reading the alerts.
- **The 1984 part:**
  - the Party rewrites records ("there is no record");
  - loyalty is performed in public;
  - the Ministry of Information;
  - fear of the neighbor, not of the machine.
- **What this means for gameplay:**
  - **flaws everywhere are your toolbox.** Every system has a gamified weak spot you can learn and exploit: a camera on factory settings, a filter that misses misspellings, a database that forgets you when you move districts, a guard who trusts the screen.
  - The regime's new daily rules patch some holes, and open new ones.
- **Tone check:** this is a regime you can laugh at (its tech is clumsy, its slogans absurd) that still kills people. Both have to be true at once.

---

## 3. The core loop: one day (decided 2026-11-20)

| Phase | Where | What you do |
|---|---|---|
| **Morning** | Laptop | Regime and underground news, overnight messages, what went wrong. **The day's new rule or measure** appears, e.g. *"From today, ammunition sales require ID registration."* |
| **Day** | Cover job | Earn money and keep your cover. A short hands-on job minigame (section 6). Skipping or slacking gets noticed. |
| **Evening** | Home | Family: dinner, kids, your spouse's questions, events with choices. If they don't know, you **hide things** when someone walks into the garage. |
| **Night** | **The room**: laptop + workbench | The core. Laptop: messages, propaganda, plans, money, the map. Bench: build and repair. |
| **Overnight** | Map | Operations resolve, traces pile up, the regime acts. Sometimes a **mission** you play yourself (top-down). |

- **Juggling is the fun, but it ramps up.** Systems unlock one at a time as you grow, the way Papers Please adds one rule a day. Delegating (pillar 2) takes old chores off your hands, so the load stays manageable while the stakes rise.
- **Time:** in days, with pause and speed controls. Later the day loop compresses (fast-forward; if you hold a good line, not much changes). The details come when we get there.

---

## 4. Character creation (decided 2026-11-20: chosen, Warband-style)

You build your character through a short story of choices:
- **Who you were:** where you grew up, what your parents did, your schooling. This sets your starting skills and your circle.
- **Your family now:** spouse or not, kids, a parent living with you. Each is named and has a face you can adjust.
- **Your job** (section 6).
- **What was taken from you:** a brother disappeared at a checkpoint, a child hurt at a protest, a parent who died in custody, your home seized, your name blacklisted.
  - You can make it personal, even mirror something from your own life, so it hits hard.
  - This person or loss runs through the campaign: an empty chair at dinner, the brother who might still be alive in a prison, a chance at justice against the officer responsible.
- **Your temperament:** cautious, angry, idealistic or pragmatic. It shapes the choices you're offered.

---

## 5. Your circle (the people you start with)

- At the start you already know **8–12 people**:
  - neighbors, friends, coworkers, relatives;
  - **a cop friend who loves the government**;
  - a mechanic who owes you;
  - a cousin in the army;
  - a nosy neighbor.
- **Each has:** a loyalty to the regime, a relationship to you, a job, access to things (keys, uniforms, schedules, a truck), and a family.
- **Using them:**
  - The early game is mostly about **what your circle can give you**, and what it costs them.
  - Example: you get your cop friend drunk and take his keys to raid the armory. His life is ruined, he's suspended or jailed, and he knows it was you. Now he has a grudge and a reason, **to put right the wrong for the love of his country**: he hunts you, informs on you, or turns up at your door. (User example, 2026-11-20.)
- **Recruiting** starts from your circle and grows through their contacts (trust chains). Every recruit has hidden loyalty, nerve and discretion, and may be an informant.

---

## 6. The cover job (decided 2026-11-20: important at the start, cut it if it isn't fun)

- **Several jobs to choose from.** Each is a short hands-on daily minigame and each has perks.

| Job | Minigame feel | Perks |
|---|---|---|
| Janitor (in a ministry, a police station, a barracks) | cleaning rounds | Access: keys, floor plans, overheard conversations, trash with documents |
| Grocery clerk | bagging and the register under time pressure | Hear town gossip; tell the regime's informers from regular customers; supply contacts |
| Factory mechanic | repairing engines | Parts, tools and skills for the bench; fix police and army vehicles (sabotage chance) |
| Police clerk / soldier / government office worker | paperwork, Papers Please-like | **Intel**: schedules, records, who's investigating whom. The highest risk |

- **Working well** keeps your cover, earns money and builds access over time (more keys, more trust, a promotion).
- **The big theft:** once you use your access in a big way (take the armory keys, copy the records), **you have to quit**: you're a suspect. Your cover is burned and you've stepped deeper underground.
- Details to be worked out when we get there. **If it isn't fun, we cut it** and make the job a quick choice.

---

## 7. The room (decided 2026-11-20: seated first person for now)

- **Seated, nearly fixed first person** in one small room, in pixel-art 3D. You turn between:
  - the **laptop**;
  - the **workbench**;
  - the window (who's outside?);
  - the door (who's coming?);
  - shelves and stash spots.
- The bench should feel like a cozy repair game (user reference: *ReStroy*, repairing electronics and chilling): tactile, satisfying and calm, until there's a knock at the door.
- **The room changes as you grow:** your garage → a cramped safehouse after the first move → a basement workshop → a mountain camp → a war room in a liberated city.
- **Later option:** free walking within the room or base, like Iron Nest. Not now.
- **Engine:** Godot handles this; no Unity needed. Free-roaming first person is what would look bad and blow up the scope, and we avoid it.

---

## 8. The terminal (your laptop)

The main interface for the underground: our own fun fake OS.

| App | What it does |
|---|---|
| **Messages** | Encrypted chats with contacts and cell leaders. Delay depends on the channel. Messages can go unanswered or be intercepted. Orders go out here; some events arrive as conversations. |
| **Web** | A fictional internet: state media, forums, an underground site, social feeds. **Post propaganda** for followers (sympathy up, exposure up). **Leak stolen proof** so people believe you. |
| **Network** | Your org chart: people, cells, who knows whom, loyalty, exposure. |
| **Map** | The country map from the underground's point of view: safehouses, caches, routes, operations. |
| **Wallet** | Money, sources, transfers. Each source leaves its own kind of trail. |
| **Files** | Stolen documents, photos, dossiers. Evidence for propaganda or blackmail. |
| **News** | The regime's version and the underground's version of the same events, plus the daily rules. |
| **Shop / contacts** | Buying materials and gear, which leaves records as the rules tighten. |

- **The laptop is a liability.** It can be seized in a raid; **wipe it** in time (losing your files) or hide it. Opsec upgrades come later.

---

## 9. The workbench (incremental building)

- **Guns are easy to buy in this world.** You build because **buying leaves a record**. The daily rules tighten one by one: registration, limits, flagged buyers, cameras at gun shops. **The regime's pressure is what pushes you into building.**
- **The progression:**
  1. **Hand bench in the garage:** clean and repair bought guns, load ammunition, fix radios. Slow, fiddly and hands-on.
  2. **Workstations you buy:** a press, a lathe, a printer (flyers, forged papers), radio gear, later drones and armor plates.
  3. **Teach a recruit to run a station.** It then runs on its own; your time goes to the next hard thing.
  4. **Workshops in liberated areas,** eventually small factories.
- **Materials** are bought (traces) or stolen. **Output** has to reach your cells through couriers and routes, where it can be intercepted.
- **Moving destroys progress:** you take what fits in the car; the rest is lost or found.
- **Minigames are stylized game actions** (like Schedule I's mixing), not real gunsmithing procedures.

---

## 10. The network and the hunt (inverting what was built for M7)

- **Cells:** grouped members, each knowing only its leader. Linking cells speeds coordination, and one arrest then exposes more. Cutouts are safer and slower.
- **Communication channels** trade speed against safety: meeting in person, courier, dead drop, burner phones, encrypted apps. The regime cracks channels, and you find out when a message is read or a meeting is ambushed.
- **Exposure at every level:** you, each person, cell, safehouse and channel.
  - Actions leave **traces**: money moving, faces on cameras, purchase records, a recruit who talks.
  - Traces raise the regime's intel on specific people and places.
  - **Responses:** lie low, move someone, burn a channel, cut a cell loose, or **move your family**.
- **Moving house:** costs money, jobs, school and the workshop. Some channels break and cells go silent until contact is restored. Family stress rises.
- **Arrests:** members may hold out, talk, or be turned. What they know is what the regime learns.
- **Prison:** early on, **if you are arrested and no one can get you out, the game is over**. Later you build "get out of jail" capacity: lawyers, bribed guards, a jailbreak mission, prisoner swaps.
- **The hunters:** a named police investigator, then a secret police officer, then an army commander, assigned to your case. They gain resources when they score and are replaced by someone harder when you remove them. They're people too, with families and reasons (pillar 4).

---

## 11. The grudge ledger (decided 2026-11-20, replaces the Nemesis idea)

- **Every act that hurts someone is recorded:**
  - who did it (you, one of yours, the regime);
  - who was hurt (killed, arrested, ruined, betrayed);
  - who saw it;
  - who loved them.
- The victim's relatives and friends get a **grudge** against whoever did it, if they know or suspect who that was.
- **Most grudges stay quiet.** The storyteller occasionally brings one forward as an event or a person:
  - the widow who identifies your courier;
  - the son who joins the police years later;
  - **the cop friend you ruined**, set on putting it right;
  - a brother at your door.
- **It works both ways:**
  - The regime's violence creates grudges against the regime. Those people are your best recruits.
  - Your violence creates informers and avengers.
  - **Repression feeds the uprising; brutality feeds the regime.**
- **Grudges can also end:** a confession, a debt repaid, justice for the officer responsible, forgiveness, or one of you dead.
- Kept light: one record per act; the storyteller decides when it matters. No hierarchy of bosses. (Not the Nemesis System. The user finds Nemesis "silly"; we only want attacks to be remembered.)

---

## 12. The country (generated every campaign)

- **A fictional country** (never a real one), Hearts of Iron-style:
  - provinces and districts, a capital, roads, a coast or border;
  - **neighboring countries**, which react, especially if you become a tyrant.
- **The regime:**
  - its type: junta, ruling family, single-party state, theocracy or puppet;
  - a named leader with a personality;
  - factions to turn against each other: the army, secret police, business elite, clergy, a foreign patron;
  - weak points.
- **Districts track:** sympathy, surveillance (police, **cameras you can take out to open up a district**, checkpoints, informers), control, economy, population groups and their grievances.
- **Daily rules and measures:** the regime's escalation shows up as concrete new rules (curfews, ID checks, purchase registration, internet filtering, checkpoints on specific roads). You learn to work around each one, and the next one arrives.

---

## 13. Money and supply

- **Money sources** (each with a trail and a risk):
  - your job;
  - donations;
  - diaspora;
  - a front business;
  - smuggling;
  - robbery (heat, hurts sympathy);
  - a **foreign sponsor**, whose money comes with demands.
- **Caches** can be found. **Routes** pass checkpoints. **Safehouses** have capacity and exposure. **Upkeep:** people need money and food, and the families of the fallen expect support.

---

## 13A. The middle game (decided 2026-11-20)

A mix of the beginning and the end:
- **Making equipment for your growing army** is the backbone: the workbench grows into workshops, and output goes out to your fighters.
- **Routine work:** recruiting, vetting, keeping cells supplied and hidden. It's still hands-on, but it gets more and more delegated.
- **Small-unit attacks** (missions or auto-resolve):
  - on **infrastructure**: cameras, power, comms;
  - on the **regime's logistics**: convoys, depots, fuel.
- **Building your own logistics:** routes, caches, couriers, safehouses.
- **Moving into the late game:** small-unit tactics and routine work fade, because you've recruited people to do them. What remains is commanding the army in large engagements on the way to the capital.

Large-scale battle command is the weakest-defined part. Design it at U9.

---

## 14. Late game: running a war (logistics)

The stress moves from *hiding* to *running everything*:
- **Battle planning on the map:** what to attack, when, and with whom. You hold a line and pick fights.
- **Every fighter must be equipped and kept supplied:**
  - **food**;
  - **ammo** for their specific weapon;
  - a **plate carrier** that needs **plates** and **magazine pouches**;
  - **meds** for their medkit.
  
  Shortages show up in combat: missing plates, empty magazines, untreated wounds.
- **The supply chain:** workshops and factories → depots → trucks → units at the front. Routes get cut, depots get bombed, a winter needs coats.
- **Money pool:** pay, buy, bribe, sponsor demands.
- **Days continue,** with fast-forward. If the line is solid, not much changes, so the player spends attention where it's needed.

---

## 15. Actions: map, events and missions

- **Map and laptop orders** take days, use people and supplies, and resolve with a chance of success and a chance of a trace.
- **A storyteller** reads the state of the country and picks from a large library of event templates filled with the current world (HOI-style popups and chats). Events chain into stories with choices and pull in your circle, your family and the grudge ledger.
- **Missions** for the moments that matter, top-down in pixel-art 3D on the existing tactical engine:
  - break into a ministry for proof;
  - take out a camera network;
  - raid the armory with stolen keys;
  - free a prisoner;
  - escape a raid on your safehouse;
  - an ambush;
  - later, battles and the capital assault.
  
  **Every mission can be auto-resolved.**

---

## 16. Win, loss, endings

- **Win:** storm the capital and kill (or capture) the leader. It takes an army.
- **Lose:** arrested early with no way out, or killed.
- **Successor:** late in the game you can anoint a second in command. If you die, they take over and play continues, but the movement takes a hit (sympathy, loyalty, some cells break away).
- **Epilogue:** what you became (liberator, strongman, new tyrant), what happened to your family, your circle and the person who was taken from you.

## 16A. Saves, scope and tone (decided 2026-11-20)

- **Saves:** the game saves when you **sleep** (end of each day). You can reload the last morning. **Ironman** is an optional mode (one save, nothing undone). Game overs only stick in ironman. Hard permadeath for everyone would push players away.
- **Scope:**
  - first aim for a **finishable ~10-hour campaign** as proof of concept;
  - expand toward a ~60-hour campaign later, so Hearts of Iron players will love it;
  - polish only after the small game works end to end.
- **Violence:**
  - torture can be part of the game;
  - **only adults can be hurt**;
  - **civilians can be killed, but it hits you hard**: they're who you're fighting for, even the ones who aren't on your side (sympathy, recruits, grudges, morale, neighbors).
- **Writing voice:**
  - the main game, the regime and the news are **bleak and dark**;
  - **your own side is darkly funny**: chats, dinner scenes, the people in your movement. You should like your people, and they lighten the mood.

---

## 17. Art and tech

- **Look:** pixel-art low-poly 3D:
  - a seated first-person room;
  - top-down missions;
  - a stylized country map;
  - a crisp retro OS on the laptop.
- **Tech:** Godot 4.7, GDScript. Architecture rules as before:
  - simulation in `sim/`;
  - data in `data/`;
  - one tactical engine;
  - everything serializable;
  - debug overlays.
- **Reuse from the counter-terror build:**
  - people (portraits, roster, wounds, memorial, service records);
  - the network sim (inverted into the regime's investigation);
  - the tactical engine;
  - UI theme;
  - map drawing.

---

## 18. Roadmap (draft, not started; the user wants the full picture first)

Each milestone ends playable.

| # | Milestone | Done when |
|---|---|---|
| U1 | **You and your world** | Warband-style character creation (backstory, family, job, what was taken); a generated country and your town; your circle of 8–12 people; the **room** (seated first person, laptop + bench + door + window); the **day loop** skeleton (morning → job → evening → night → overnight) with the first family events |
| U2 | **The laptop** | Fake OS: Messages, Web (propaganda → followers, sympathy vs exposure), News with **daily rules**, Wallet, Map, Files |
| U3 | **The workbench** | Hand-crafting minigames, buying materials (with traces), first workstations, delivering output; the regime's rules pushing you from buying to building |
| U4 | **The network and the hunt** | Recruit from your circle and through trust chains, informants, vetting, cells, channels, exposure, a named investigator, arrests, **prison = game over**, moving your family |
| U5 | **Grudges and the storyteller** | The grudge ledger, the event library (~100 templates) with chained stories pulling in your circle and family |
| U6 | **Cover jobs** | 3–4 jobs with minigames, access and intel, the big theft and quitting (cut if not fun) |
| U7 | **First missions** | Break-in for proof, cameras, armory raid, prisoner rescue, safehouse escape; auto-resolve |
| U8 | **Insurgency** | Armed groups, districts at night, regime escalation, recruits running your stations, routes and caches, drones, jailbreak capacity |
| U9 | **War and logistics** | Army units, equipment slots (plates, pouches, meds, ammo, food), the supply chain to the front, battle planning, neighbors |
| U10 | **The capital** | Final assault, the leader, epilogues |

---

## 19. Open questions

- [ ] Working title ("Uprising" is a placeholder).
- [x] The movement's ideology (2026-11-20): chosen at the start, or later when it unlocks.
- [x] Successor (2026-11-20): late in the game, after long investment, you can anoint a second in command who takes over if you die; the movement takes a hit. Before that, your death ends the game.
- [ ] How each cover job's minigame plays (decide at U6).
- [ ] How the late-game day loop compresses (decide at U9).
- [ ] Free walking in the room/base later (Iron Nest-like)?

---

## 20. Decisions log

| Date | Decision |
|---|---|
| 2026-11-20 | World feel: 1984-style control with new-age tech, but sloppy: unpatched systems, default passwords, poor education, dumb non-LLM AI; flaws everywhere are the player's toolbox. Start date Mon 14 Oct 2041; the laptop shows full date, weekday and time. Story: Claude writes the premise and beats (docs/STORY_PREMISE.md), the user writes the scenes. |
| 2026-11-20 | The user will write some of the game text; all writing lives in data/ JSON (docs/WRITING_GUIDE.md). |
| 2026-11-20 | Middle game = making equipment for the army + routine recruiting + small-unit attacks on infrastructure and regime logistics + building your own logistics; small-unit tactics and routine fade in the late game (delegated), leaving large-engagement command. Saves when you sleep, optional ironman. ~10 h finishable proof of concept first, ~60 h later. Torture allowed, only adults hurt, civilian deaths possible but punishing. Bleak regime/news, darkly funny own side. Free sound packs OK (user wants to learn to make sounds later). Blender art made by Claude, then the user tweaks it to remove the "AI look" (Claude teaches what to change; see docs/ART_GUIDE.md); user will share reference screenshots for the look. Delete old counter-terror code once its replacement exists. |
| 2026-11-20 | T1 built (terminal on its own, days 1-4 of FIRST_WEEK.md). Cybersecurity is fully gamified (fun angles, not real procedures). Workflow: lean CLAUDE.md + a `godot-verify` project skill; Claude asks gap questions before each milestone. |
| 2026-11-20 | Successor: late game, you can anoint a second in command who takes over if you die (the movement takes a hit). Ideology: chosen at the start, or when it unlocks. First gameplay to build = the terminal on its own, to make sure it's fun to use; it should have its own quirks and secrets. |
| 2026-11-20 | Planning before building: the user wants the full picture before starting a milestone. |
| 2026-11-20 | Core loop = one day: morning laptop (news, messages, daily new rule) → cover job → evening home/family → night in the room (laptop + workbench) → overnight map resolution. Juggling is the fun, but systems unlock gradually. |
| 2026-11-20 | Seated first person in one room (laptop, bench, door, window), pixel-art 3D, in Godot (no Unity). Cozy repair-game bench feel (user reference ReStroy). Free walking maybe later. Missions top-down. |
| 2026-11-20 | Incremental building: guns are easy to buy, but buying leaves records; tightening rules push you into building ammo and weapons and repairing gear; buy workstations, teach recruits to run them, grow into workshops and factories. |
| 2026-11-20 | The player is a reluctant fighter who does it for their family; not good at first. |
| 2026-11-20 | Character creation chosen Warband-style, including what was taken from you; it can be personal. The story matters as much as the gameplay; moral greyness (are the targets really the bad guys?). |
| 2026-11-20 | Cover job: important at the start, several jobs (janitor, grocery clerk, factory mechanic, police/military/government) with minigames and perks such as intel and access; a big theft forces you to quit. Cut it if it isn't fun. |
| 2026-11-20 | Grudge ledger instead of Nemesis: attacks are remembered by victims' families ("you killed my father"); a betrayed friend who loves the government sets out to right the wrong. |
| 2026-11-20 | Late game: the stress comes from logistics (World War Z's Sinclair): plan battles, a money pool, equip, feed and supply every soldier (ammo, plates, pouches, meds). Time stays in days with speed-up. |
| 2026-11-20 | **Game switched** (user): you are the founder of an underground resistance in a generated country, growing from nothing to an army (Antistasi as the groundwork). Win = storm the capital and kill the leader, which takes an army. Counter-terror design archived. |
| 2026-11-20 | A newly generated fictional country every campaign (never a real one). Neighboring countries exist and react, especially if you become a tyrant. |
| 2026-11-20 | Real-life underground constraints are the core: supply network, communications, exposure. Every gain risks a trace; getting traced means moving your family and losing contact with cells. |
| 2026-11-20 | Early prison with no one to free you = game over. Later you earn ways out. Lost lives are permanent. Every recruit has a family. |
| 2026-11-20 | A working in-game terminal (laptop): propaganda websites for followers, stolen proof so people believe you. Missions such as breaking into government buildings and taking out surveillance cameras. Drones later. |
| 2026-11-20 | Presentation: Hearts of Iron-style map with text events, plus real gameplay in the terminal, the room and specific missions. Not open-world Arma; not a CQB game. |
| 2026-11-20 | Claude's calls (overrulable): working title "Uprising", time in days with pause/speed, epilogue by method, missions auto-resolvable, U1–U10 roadmap. |
