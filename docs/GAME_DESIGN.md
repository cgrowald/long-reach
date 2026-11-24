# UPRISING (working title) — Game Design Document

*Living document and the source of truth for what the game is. Update it whenever a decision changes. Adopted 2026-11-20, replacing the counter-terror design (archived in `docs/archive/`).*

*Planning status (2026-11-20): the user wants the full picture before building ("that's how these things die, we start too quickly"). Don't start a milestone until the user says so.*

---

## 0. THE CORE (decided 2026-11-20, late night). Read this first; it overrides older sections

**Nothing is predetermined.** It's a systemic, run-based game in the spirit of Balatro's structure (random offers, combos, builds that snowball), not a text adventure. Growth is still the point.

### 0.1 The op loop (one loop at every scale)
> **Find a target → hit it → loot drops → combine the loot → the world opens up → bigger targets.**

- **Targets** are places on the overworld map (generated each run): government offices (data, dirt), gun stores (weapons), a metal refinery (parts for upper receivers), police posts, roadblocks, officials, radio towers, depots.
- **Loot** (rarity tiers, rolled traits; see PROOF_AND_INTEL.md) feeds:
  - the benches (parts become receivers become rifles);
  - people (dirt turns them);
  - the movement (leaks grow it);
  - new targets (Chain loot).
- **Weekly random offers** (forum, market, contacts) give you a handful of opportunities to choose from. You can't take everything.
- **Combos snowball:** refinery parts → receivers → armed cells → the armory opens → the barracks open.
- **The regime's rule of the week** works like a boss modifier you must play around.

### 0.2 Three ways to run any op
1. **Do it yourself:**
   - hack it on the PC (your "sword": the laptop is where a small person beats a whole system, the Dungeon Crawler Carl feeling);
   - or go there in first person (small locations only).
2. **Command it:** watch through cameras or drones and make a few big calls while your people fight as themselves.
3. **Auto-resolve:** read the result.

**Scale:** the same op system goes from you alone → a cell → squads → platoons across the town in the final war. Your control moves from your hands to the cameras to the drones; micro shrinks as scale grows. You can always jump in yourself.

### 0.3 Watch-and-decide combat (the biggest unknown; prototype first)
- **The feeling:** the Door Kickers 2 joy of a team pieing a corner perfectly, **without micro**.
- **Skill shows in movement:**
  - **rookies** bunch up, check corners late, flinch, miss;
  - **trained squads** stack, pie in one smooth motion and cross-cover.
  
  Getting good is something you *watch*.
- **Dice roll themselves:** XCOM-style hit and reaction chances, played out in real time. No "35%" button. Better training and gear than the enemy means faster reactions and better aim.
- **The player's calls** (a few per fight, like a manager game's touchline shouts):
  - **routes:** take the hallway, take the stairwell;
  - **assignments:** you watch this, you watch that, you hack or exploit that target, whether it's a device or a person;
  - **tempo:** quiet, loud, hold, pull out.
- **Squad AI:** the squad decides the plan, and each soldier carries it out his own way (hierarchical AI). Soldiers act on their own: take cover, pull wounded, react to grenades.
- **Readability rule:** sloppiness must look like rookies, not bugs. (SWAT 4's main complaint was teammates who sometimes clear brilliantly and sometimes run past an enemy.)
- **Auto slow motion on contact** gives you a beat to make the call.
- Not as complex as Door Kickers 2 or Gates of Hell. Not a shooter.

### 0.4 Readable combos: the op report
After every op, a report tallies up like Balatro's score:

> loot ★★★ · CLEAN (no casualties) · GHOST (never seen) · NO CIVILIANS HURT → ★★★★, sympathy up

- **Clean execution raises or keeps loot rarity, and grows your skills.** Sloppy work downgrades loot and adds heat.
- This holds for every kind of op: hacks, robberies, hits on officials, roadblocks.
- **Payday-style getting caught:** quiet → suspicion → alert → response, within an op; heat across the run (revisit later).

### 0.5 Two economies
- **The broker:** a third party you pay in loot or money for special upgrades (skills, perks, tools, specialists). **Never war materials.**
- **War materials** (guns, ammo, parts, plates) come only from your own loop: raids, benches, supply chains.

### 0.6 People: named legends and the numbers
- **A few named operatives** you care about (XCOM-style). They're the legends for high-profile ops, upgraded with rare loot (rare metals, special ammo). Rare loot recurs through the main loop; it's not finite.
- **Everyone else** grows into squads and platoons as numbers.

### 0.7 More than one way to win
- **Military:** storm the capital.
- **Political:** a perfect, damning evidence drop from a great op gets the president impeached. No army needed on a great run.
- Others to design (a popular uprising, a general strike?). Your lean tends to pick your path.

### 0.8 Views
- **Overworld map** for the town or country.
- **The PC** is the main tool.
- **First person** only for small locations (the garage, a records room, a stairwell).
- **Cameras and drones** for commanding fights.

### 0.9 What carries over from what's built
- **Kept:** the laptop OS, Probe and the lab engine (becomes generated), loot, patterns, the garage, sound.
- **Reused:** the old CQB engine (soldiers who see and shoot on their own, the pie maneuver, raised and low-ready poses). It gets autonomous, skill-based behavior.
- **Becomes optional:** the hand-scripted days 1-4, kept as a tutorial or one opening story.
- **Story:** the user's opening stories set your starting pieces and a long-term goal. Their scenes fire when the systems get you there, not on fixed days.

### 0.10 Build order
1. **Combat prototype:** watch-and-decide on one building (see docs/COMBAT_PROTOTYPE.md).
2. **Town overworld** with generated targets and weekly offers.
3. **The op system:** plan → execute (yourself, command or auto) → op report → loot.
4. **The gun bench** eating loot.
5. Generated labs, the broker, named operatives.

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

## 2B. Many ways to every need; you lean into one (direction, 2026-11-20)

- **Every need has several ways to meet it**, and they connect across the game. Example, **meds**:
  - make them at a bench;
  - steal them;
  - work at the hospital (cover job);
  - exploit a hospital worker (blackmail, bribe, or hack their system).
- **All paths are playable, but you physically do the piece you lean into.**
  - The path you lean into is a hands-on minigame.
  - Leaning in gives more benefits and more exact choices (better yield, finer control, special options).
  - Paths you don't lean into resolve as simpler orders or are handled by recruits.
  - **What you lean into may be what makes each run feel different.**
- **Build bench by bench, need by need,** connecting each one to everything else (jobs, people, the OS, exposure).
- **The hacking angle:**
  - The OS is state-made and controls everything (cameras, doors, records, payroll, the hospital, the trains), so there are **backdoors to learn and exploit**.
  - Hacking is a fresh, simple take on Hack The Box-style labs: much simpler and clearly pointed out, so you feel like a hacker without real security knowledge.
  - This is the default protagonist's angle, since he doesn't do the big firefights.
- **Big fights are possible later,** but doing them in person makes you a public icon on the state's TikTok-like feed. Fame is power and exposure. Way down the line.

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
| 2026-11-20 | Late-game laptop = supply lines and owned businesses (source the refinery's inputs to make metal for guns; ties into war control). Three progressions feed each other: your skills create your gear, your gear upgrades your people; some people are workers, and knowing people teaches you things and speeds up (then automates) table jobs. Targets: gun store = guns and ammo; refinery = war materials (gear, meds, tech, gun creation); ministry = dirt that pulls in people. Step 1 (the open OS) built. |
| 2026-11-20 | Open PC and economy (docs/OPEN_PC_AND_ECONOMY.md): PC intro was too scripted; becomes a drab dystopian Linux-like OS with programs per activity (Probe, Market, Nod, Messages, Map, Files, Darknet, Workshop), generated themed internet, systemic chat, no story set pieces (short clips for joining inner circles). Real-kit-inspired gadget tree, gunsmith tools, espionage as its own table. All stations in the garage from day one, labelled; buy kits on the Market. Bureau heat levels with seizure, raids with a timed scramble, prison (fast-forward), egregious crimes end the game. Going out = town map + short hands-on scenes. 3 resources (money, parts as items, intel loot). Hours budget per day. Followers = recruits, donations, crowd protection, inner-circle invites. Early money = job + repair side jobs. Inner circles rent high-level operators for ~3 days after quests. No laptop hardware upgrades. |
| 2026-11-20 | Combat controls reworked (user): select the whole squad or individuals; right-click a door = everyone auto-stacks by doctrine; then build a breach plan by clicking a combo (door method, grenade, entry order like 1-3-4-2, pie first) and execute; right-click ground = move. Always live in the sim. You micro movements, not individuals. Better character models later. Depth of field on 3D views. Next early-game needs: hacking, poster placing, the job; first bench = hacking tools (espionage maybe its own table); build a base bench framework first. |
| 2026-11-20 | Combat prototype answers: drone + CCTV switchable; hotkey directions (squad picks the spot and uses cover), stop commands, per-soldier control for defense, attack and defense both matter; pause any time when not there in person, slow motion; NO numbers on screen; same gray-box building now, system must support big realistic buildings; user supplied a reference video instead of filming drills. Built in tactical/watch/. Skill now also = accuracy while moving and plates. |
| 2026-11-20 | NEW CORE (section 0): systemic Balatro-like structure, nothing predetermined; the op loop (target, hit, loot, combine, open up); three ways to run any op (yourself, command via cameras/drones, auto); watch-and-decide combat with skill visible in movement and auto dice; op report tally; broker (upgrades, never war materials); named legends + numbers; military and political wins; overworld + PC + first person for small places. Build order: combat prototype first. User offered phone videos of drills (ex-Army) to model AI movement. |
| 2026-11-20 | T3 built: Probe app with the Annex lab (map, typed commands, Tab completion, typo hints, idle hints, assist chips, patterns that can break, trace meter), loot drops with tier cards and the Archivist, loot posts give big follower bonuses. |
| 2026-11-20 | Annex answers: Pavel moved to the capital (yes). Mrs. Duda dilemma (great, keep). Keep typing, plus an assist option with autofill chips for known commands; beaten defenses become saved "patterns" you replay (memorized feel), which daily rules can break. Short labs give small loot (1-3 stars); big jobs give procedurally generated high-tier loot (up to 5-star blackmail/leaks) with a Dungeon Crawler Carl style looting thrill but our own rarity; big loot also unlocks path support for your troops. Terminal UI vibe needs a look pass (WIP). See docs/PROOF_AND_INTEL.md 5-8. |
| 2026-11-20 | Answers: lean-in is GROWN BY DOING (no classes). Hacking labs = a clickable map of the target network plus a few short typed commands with hints. First need to get all its paths: PROOF AND INTEL (hack an office, break in, janitor job, exploit a clerk). Every run varies: country and regime, opening story, your circle of people, and which paths exist. |
| 2026-11-20 | Direction: every need has several connected paths (meds: make, steal, hospital job, exploit a worker); you physically play the path you lean into, which gives more benefits and finer choices and may define how a run feels. Hacking angle: the state OS controls everything and has backdoors; simple, clearly signposted HTB-style labs. Big fights later make you a public icon on the state TikTok. Build bench by bench. First 10 h loop must be fun; weeks are fine. User's running thoughts live in the Obsidian Second Brain. |
| 2026-11-20 | T2a built: placeholder 3D garage (pixel-rendered) around the laptop; views bench/laptop/window/door, clickable things with flavor text in data/terminal/room.json. See docs/ROOM_AND_BENCH.md. |
| 2026-11-20 | Story structure: Pavel's arc is an opening side story that unlocks the insurgency; it ends (in one version) with finding Pavel, a "everything we left behind led us here" scene, handing him leadership, then giving it to a ring of trusted leaders. No single correct answer. The user writes ~10 opening stories; Claude then writes many more in that style (at dev time, stored as data) so it feels like an open world. |
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
| 2026-11-21 | Building paused: too many parts, no loop. Do market research first (docs/MARKET_RESEARCH.md), decide the loop, then build only that. User: "it needs to play like Iron Nest, or other games with terminals as a main source of gameplay... the workbenches supply the troops you need to overthrow the government." Steps 2-4 of OPEN_PC_AND_ECONOMY are on hold until the loop is decided. |
| 2026-11-22 | **Readability + hacking direction** (user, late): the font was unreadable game-wide: now one sharp monospace (DejaVu Sans Mono), all UI drawn at full resolution, the 3D world stays pixel. The day-job pick is three cards (photo, gives, costs; GPT makes the photos). Hacking must be quick and fun with little screen switching, in the new OS look (GPT's petrol/ivory/copper sheets); in-person hacking for air-gapped buildings gets built in (start: plug in and upload a program). Connect = GPT's PATCHBAY route puzzle; inject = a second puzzle, picked from docs/HACKING.md section 5. Sell intel to the fixer **and** post it on Nod from anonymous accounts (followers = recruits); all payoffs built now behind knowledge walls; targets generated from the town; getting traced = attention + target locked. |
| 2026-11-22 | **Next builds** (user, late): the hacking pass first, from the design (the user hasn't played the hacking job and doesn't need to first). The easy first mission = the bar where the politician drinks, with guns. The clearing moves from the user's Operator clip (COMBAT_SLICE section 10) get built with that mission, together with the army rules (J-hook, kneel to reload, bounding out). A "FIELD LINK" combat screen reference is saved in POLISH.md for the face-lift. |
| 2026-11-22 | **Economy decisions** (docs/ECONOMY.md section 8): pick 1 of 3 random day jobs (hospital = meds, steel mill = metal + an early drill press, textile = cloth + a sewing machine); material grades per source, per game; stealing from work is a risky morning choice; the black market is earned through a fixer; upkeep per person per night; lockpicking hands-on in 3D; exploiting people is a short talk with angles; money is tight early. The garage and the economy come before more combat; the combat face-lift is listed (COMBAT_SLICE section 11), including an easier first mission and the police-station robbery chain. |
| 2026-11-22 | **Gear on your people** (docs/RUNDOWN.md section 9): a gear cage in the garage with the fighter in 3D; the rig grid is drag-into-cells (market bag 3x2, chest rig 4x2, plate carrier 4x3 + plate); first kit = street clothes, junk and one bad gun to share; fists and melee later; gear from the benches, the black market and loot. (Row added 2026-11-22 late, it was missing.) |
| 2026-11-22 | **Game rundown decisions** (docs/RUNDOWN.md section 7): opening = inherit Pavel's half-built op; clock = nights where only big things cost; people recruited from your world (level, train, retire, dead for good); leader death = roguelite successor; top end = select-fire, LMG, DMR, mortars and drones (rare, built on the mill); money from intel and loot, spent on gear, bribes and safehouses; 3-4 cities, then the capital; the Bureau finds you = a warning, then a home raid you fight. Also: TTK falls with better weapons; tougher targets need better rounds; the doctrine pass follows the user's army method (COMBAT_SLICE section 10); the world map zooms country > city > zone > building, with news and a living regime. |
| 2026-11-22 | **Combat, from the slice to the van** (docs/COMBAT_SLICE.md; rows added 2026-11-22 late, they were missing): the slice must hit hard; first op = Dobrev Freight depot at night (the hack gives the briefing and CCTV); you fly the FPV; Tarkov-lite gear depth (about 8 stats, 3 round types, 3 plate classes); 4 named fighters with a medic. The look test was "exactly what I meant": keep the pace slow, they are their own people and you yell commands, their death should feel like your fault. Real time with a pause, no slow-mo, you're in the van for now. After playtests: ops board, pushback and overrule, split stacks, walk 0.85 m/s, "if their eyes can see it, their guns can". Clearing follows the user's army method (section 10) and his Operator clip (watched, same section). |
| 2026-11-22 | **OS played + hacking job:** OS loved; font too boxy, switched to Tahoma. Hacking = a short job of 3 PC programs (pscan, crackle, grab) on one target; gadgets plug into the box in 3D on the desk; fixed hours per job; trace full = cut out with what you have plus a clue. Combat presentation researched (docs/COMBAT_ANGLES.md), not decided: the user raised Iron Nest (never see the round, tracking + sound + recon photo), helmet cams, and in person vs commanding. |
| 2026-11-22 | **First bench playtest:** the benches are "exactly what I wanted", this build is the new base (tag v2-base). Needs: every step must show plainly what goes where, next; better models; real tools with tiers (drilling already good); rig = cut strips, bend, sew in the right places, then pouches; HEARTH OS must feel like a real (Linux-like) OS, not a page of buttons; hacking should step away from Balatro (a punch-card machine read by the nubs, or programs loaded and launched on the PC with a fun minigame). Next: the OS. |
| 2026-11-22 | DRIVE questions: benches in 3D first person; batching after 3 good crafts at average quality; rigs are grids whose size, pouch fit and plate slots come from the materials (Tarkov constraint: great armor early means little room); fights top-down auto-battle with call-ins; hacking tried as build-launch-watch-nudge chain. |
| 2026-11-22 | **The drive** (docs/DRIVE.md): keep the v2 look. Balatro / Ball x Pit pull without their gameplay. Benches are hands-on first-person crafting that climbs in tiers (drill and file a receiver, Tarkov "IKEA rig" armor, torn-shirt meds) as the incremental grind. Fights are auto-battler style (Just King) with the life of the ball pit toy. Many things to master; you stay in charge, starting alone like Antistasi. Build the garage mechanics first, then move out. |
| 2026-11-21 | **Debug shell first** (docs/SHELL.md): build the whole barebones game so the world feels good, then drop systems in. v2 White Knuckle look in Blender, garage hub with a swivel chair, placeholder sounds, war room as a placeholder reached by a floor hatch or the PC, real saves from day one, everything a normal game has (title, settings, pause, save/load). |
| 2026-11-21 | **The hunt** (docs/HUNT.md): the Bureau narrows a suspect pool of real generated townspeople by pinning facts from your clues; two numbers (Attention = how hard they look, Profile = how close to you); a named Nemesis-style inspector; clues go left → collected → pinned, cleanable early; every counter-move is a job. User picked: corkboard is earned (pool + warnings always), named rival, innocents can be arrested, sloppy play = raid warning around day 8-10. |
| 2026-11-21 | **Restart (v2)**, see docs/RESTART.md: new project and look (White Knuckle low poly + Iron Nest tactile panels, animations carry it), one long campaign with daily minigames scored Balatro/Ball x Pit-style (score = intel quality tier), going out like Shadows of Doubt plus screens, first piece = a hacking minigame for digging dirt, benches automate into standard issue via machines + workers, Tarkov-style trader groups later, XCOM-style missions for your people. |
| 2026-11-21 | **Core loop** (docs/CORE_LOOP.md): one "job" engine for every path (hack, exploit a person, break in, work there, send people). A: send-aways for routine jobs, watch-and-decide for the big ops. B: going out is walled off with placeholders. C: typing plus cards (Iron Nest feel, tools are minigames). D: rig modules are built at benches; the good tech is illegal and comes through the insurgency network and your growing cell. E: the main pressure is the Bureau hunting you (a detective, deeper than Plague Inc.'s cure meter); family needs come later. Next design job: the hunt. |
| 2026-11-23 | **Markets, lockpicking, the tutorial, models** (user): the face-lift sheets are concept art for MODELS (GPT draws, Claude builds in Blender). Spending money: ShopNet online (basic, logged), a black market on the PC (Lantern, less stock) and one in person, only after curfew (a risk): built as a sneak dash (user picked). Lockpicking like Skyrim mixed with other games: pin by pin (user picked). Hacking programs are learned in the tutorial: the post office, then the town hall (user picked). Every bench gets its own orange desk lamp that lights the work up. Research the Red Dawn style literature for gaps (docs/LITERATURE.md). |
| 2026-11-23 | **Not real life + 1000 men** (user): you make it all yourself, which is the point; stealing and black-market guns are extras. Winning needs fielding at least 1000 men; you can always try the capital early and get lucky (for example a 5-man team in 5-star gear). Gaps always come as questions with many options. Next: the full loop. Claude wrote docs/LOOP_RUNDOWN.md (every module, the links, Q1-Q14 with options) for a GPT review; GPT's research comes back to Claude after. |
| 2026-11-23 | **GPT's review answered, the depot slice** (docs/DEPOT_SLICE.md section 1). Lots unlock by mastering an item (several handmade crafts per new item, upgrades raise lot size). Leaders come from early survivors and run district companies; you always keep your own squad. Upkeep climbs the chain of command (per person up to a squad, per squad at platoon, per platoon at company, per company at battalion). The depot brings back guard weapons (poor pistols and SMGs, no plates), a random bench upgrade by depot kind (one depot variant per bench, roguelite), a captured person (an interrogation section) and a spot where your people get you in to hack. Vehicles come from elsewhere and open targets outside town. Krall escalates: someone you know questioned, then a delivery intercepted, then a garage search (audits and checkpoints too), starting far off and closing on your op. EYES must be hacked; the base level shows enemies your people can't see so you can warn them; upgrades add the rest. GPT's big inspiration research comes with the face-lift. |
| 2026-11-23 | **Combat screen too cluttered** (user, before playing M1): remove the bottom camera tiles and keep the operator list; only the one chosen camera angle shows (pick it from the list). The ops map needs zoom in and out. Polish before playing. |
| 2026-11-23 | **Rest of M1 decided** (user): (1) gun swap is automatic: a dry fighter shouts and takes a downed guard's SMG (few rounds), HOLD stops it, the SMG comes home in their rig. (2) You hand the stick to one fighter in the cage (tech level shown, too low can't carry); whoever finds the PC calls the carrier over. (3) The vault is a 3D room (three numbered doors, cables to the control PC); you must hack in with a **guided command hack** (short made-up commands with hints, each step costs backup-clock seconds, better sticks give shortcuts), then click the door on the feed and it swings open. (4) The plan file and the prisoner's ID are 2D paper you look at (bible 13). (5) Cage layout per bible 17; the rig grid opens from the RIG slot over the stash. Small fixes get screenshots in chat; full playtests only after big slices. |
| 2026-11-23 | **Vault hack revised + the boredom worry** (user): the vault hack is a small draggable terminal popup that looks like a plain shell; you tell the carrier what to type and the typing is the time cost (they're out of the fight, you cover them); no countdown bars; a second popup shows the vault camera to pick the door ("exactly what I wanted"). Helmet cams stay as the main feed. The user fears the game is boring: combat is great, but it needs a variety of maps, targets and reasons to hit them; also things to do while an op runs (maybe a feed on your PC at night). Parked: blood splatter and ragdoll deaths. |
| 2026-11-23 | **After M1 (user): open world, the whole game, catalogs.** (1) Judge fun on the WHOLE game once it is built, not piece by piece; stop asking about Krall in playtests (he has no face and isn't fleshed out). (2) Krall chasing you and spending currency to act don't feel fun. Direction: Schedule I style: do what you want, things take TIME, and you wait for things to pop up before you can go further. No gating; it should feel like an open world. (3) An overworld map of what we hold and what the regime holds, in the Paper Mario style already decided for the night outings (wanted soon). (4) GPT is making gear catalogs (docs/refs/catalog/); Claude works out where each item's materials come from, makes the models, and links it all (recipes, sources, blueprints). (5) Blueprints = tech the regime keeps for itself (you take them in raids). Baseline handmade items need a source and a place early in the game: maybe "ideas" bought off people, then built at the bench. (6) Our fighters' models are too jagged: smooth them toward the GPT look; not the art bible yet. (7) Keep going through the M stages; the face-lift stage is the user's favourite; animations matter too. |
| 2026-11-23 | **Next after M1 = items from the catalogs** (user picks): every catalog tile becomes its own named item (stats, material source, model). Ideas for handmade gear come from people who sell them, from your recruits' old jobs, and from StateNet pages. Gating is replaced by things popping up over time (contacts, jobs, targets, deliveries), Schedule I style. |
| 2026-11-23 | **Catalog build decided** (user): models come from one smooth Blender kit per family (parts mixed per tile); the 125 face tiles are sliced into the game's portraits (hurt/scarred sheet for the injured); item stats = warmth and weather, pockets and carry, blend in or stand out (disguise, morale, attention), toughness and repair; the people sheets dress townsfolk and recruits, set the regime ranks, and are the target shape for the fighter model. |
| 2026-11-24 | **Back to the M list; M1b answers** (user): no new milestones (the catalog plan is parked). M1b starts with the sewing table. Feel: ReStroy (simple version: every item fully modelled on every side, picked up and turned in 3D) plus Assemble With Care. Wear: slowly from each op, but mostly from getting hurt (bullets, maybe environmental damage). Art: GPT draws each bench (starter, improved, upgraded, plus step sheets) and Claude follows it. Design: docs/BENCH_SEWING.md. |
| 2026-11-24 | **Making things takes no time** (user): crafting and mending cost only materials; only missions and leaving the garage take time. **Order:** finish the sewing table's upgrades, then nail down combat and the loop of using everything together (before the other benches). Animation references saved in docs/refs/combat/ (README there): walk, kneel, hip fire, flinch, swaps, bullet impacts. "The bench is beautiful, can't wait to see that on our guys." |
| 2026-11-24 | **Connect the systems; never feel lost** (user): "you're lacking in connecting all of our systems"; keep everything super readable. The user likes the TONIGHT board concept (a big board that plainly shows what's next). The whole garage gets a do-over in the sewing table's direction: wide, open, fun (concepts in docs/refs/Garage/). GPT's review notes (direct the raid from an elevated 3D view with a pinned helmet feed, orders Move/Hold/Interact/Withdraw, pushback with an alternative, leave outcomes, readable hits, status signs, the haul placed at home, the next evening answering the last) are the plan's raw material: docs/CONNECTED_LOOP.md. |
| 2026-11-24 | **Connected loop answers** (user): build the TONIGHT board and station signs first, then the garage rebuild, then combat. The new garage is walked around **in first person**. Combat main screen: an elevated 3D overview with one helmet feed pinned beside it. Lethality: GPT's values (unarmoured guard down in 1-2 clean hits; our fighters wounded by the first serious hit, can go down on the second) **only for vital hits** (head, torso); arm and leg hits take more. |
