# Long Reach: Vision 2 (proposal, 2026-11-20)

*Status: ADOPTED 2026-11-20. The user picked all four recommendations in section 6: toolbox with auto-resolvable raids; the Director (you) and operators both have families; home country chosen at the start; history-inspired event templates (no download). Build order: section 5. Fold details into GAME_DESIGN.md as each phase is built.*

The user's direction (2026-11-20):
- **New every time.** Plague Inc. is great, but its world events repeat. Real history has thousands of events to draw from.
- **Missions are not the point.** The point is the **freedom to attack the organization however you think will work**. "Not only Door Kickers."
- **Variety.**
- **A family**, which adds another side to the game.
- **You lose if your home country is destroyed** and your family has to flee.

---

## 1. What's already out there

| Game | What it does | What players say | What we take from it |
|---|---|---|---|
| **Counter Terrorist Agency** (2019) | Same premise: find connections, interrogate, dismantle networks on a map | Mixed. Fun for a few hours, then repetitive: the same scenarios, the same enemies | **This is where Long Reach is today.** A network board on its own gets old fast. |
| **Phantom Doctrine** (2018) | Cold-War spy agency, an investigation board linking clues, XCOM-style missions | The investigation board is the best-liked part; missions repeat by the end | Deduction is fun. Repeated missions are not. |
| **Sid Meier's Covert Action** (1990) | A **procedurally generated plot** you uncover piece by piece; several mini-games | The procedural plots are still praised. Meier: "two games competing with each other" was the mistake | Generate a plot, not just targets. Keep the tactical layer from crowding out the strategy. |
| **Sigma Theory** (2019) | Spy agents with love lives, double agents, diplomacy | Mostly positive, "one more turn". Too much randomness undercuts your skill | Personal lives make it stick. Bad luck must be readable, not arbitrary. |
| **Rebel Inc. Escalation** (Ndemic, Plague Inc.'s studio) | Counter-insurgency sim | Very positive; the **dilemma** system is praised | Hard choices with no clean answer. |
| **RimWorld** | A "storyteller" picks events from a large categorized list based on the game state | The benchmark for emergent stories | **The answer to "new every time"**: an event library plus a director that reads the world. |
| **Floor 13: Deep State** (2020) | Secret-police bureaucracy sim | Mostly negative: harsh failures, outcomes are just told to you | Show consequences in play; don't just print text. |
| **This War of Mine / Papers, Please** | Family or civilians at home whose survival depends on your choices | Hugely memorable | **The family pillar.** Stakes you feel. |
| **Crusader Kings** | Characters, families and dynasties drive emergent drama | Endless stories | Families and relationships produce the best moments. |
| *Coming:* **Patrol** (2027), **Shadow Division: Spymaster**, **The Syndicate** (2026) | Procedural counter-insurgency tactics with a "Heat" meter; spymaster sims | Not out yet | The space is getting busier; the combination below is still unclaimed. |

**The gap nobody fills:** a game that combines
- a **procedurally generated enemy with its own plan** (Covert Action),
- **any tool you can think of** to take it apart (not just raids),
- **people and family you care about** (This War of Mine, Crusader Kings),
- a **world that keeps throwing new, history-inspired events** at you (RimWorld's storyteller),

and keeps the tactical missions as one tool among many.

---

## 2. The new core loop

> Each week you read the briefing, look at the enemy and its plan, then **choose how to hurt them**, with whatever tool fits:
> watch, wiretap, follow the money, bribe, blackmail, turn someone, plant a mole, poison their supplies, feed them lies, have a partner arrest them, strike with a drone, or send in a team.
> Every tool costs something different (money, time, people, political trust, exposure) and the enemy **reacts to how you hit them**.
> Back home, your country and your family feel every attack you fail to stop.

Tactical missions stay in, but they're **optional to play**. Every op can be **played** or **auto-resolved**. Auto-resolve uses your people's stats, gear and plan, so your roster still matters. That's the fix for "two games competing".

---

## 3. Six big systems

### 3.1 The procedural enemy (new every campaign)
Every campaign generates a different organization:
- **Identity:** name, ideology flavor, home region, how it recruits, propaganda style.
- **Structure:** a strict pyramid, a franchise of semi-independent groups, or a loose web of inspired lone actors. Each needs a different strategy. A pyramid falls with its leader; a franchise does not.
- **Leader personality:** cautious, flamboyant, paranoid or charismatic. This changes how the organization reacts. A paranoid leader purges his own people when he smells a mole.
- **Money:** charities, smuggling, kidnapping ransoms, a state sponsor, crypto. Each can be attacked differently.
- **A master plan with stages** (as in Covert Action), for example: *raise money → buy explosives in the Balkans → move them through a port → activate a sleeper cell → hit a stadium in your country.* You uncover the stages one by one. Breaking any link stops the plan; they then pick a new plan.
- **Its own counter-intelligence:** it hunts your informants, your moles and, eventually, your people's families.

### 3.2 The toolbox: freedom to attack however you want
Every person in the network gets **procedurally generated details and weak points**. You find them out through intel:
> *"Bashir 'The Accountant' Haddad: diabetic, insulin shipped monthly from Amman. Brother sells cars in Dubai. Gambles. Trusts only his driver."*

Each detail opens options:

| Approach | Example | Cost and risk |
|---|---|---|
| **Surveil** | Follow, photograph, map his contacts | Time; may be spotted |
| **Wiretap / hack** | Bug the phone, read the chats | A tech specialist; after a while they switch to couriers |
| **Follow the money** | Freeze the charity's accounts with Treasury | Political trust; the money moves elsewhere |
| **Turn him** | Use the gambling debt to make him an informant | Ongoing intel; if he's found out, he's killed and the network goes paranoid |
| **Plant a mole** | One of your operators joins the cell | Very high payoff; your operator's life is on the line |
| **Sabotage the supply chain** | Swap the explosives for duds; the "Static" op with tampered devices | Weeks of setup; collateral risk |
| **Disinformation** | Fake evidence that the lieutenant is a traitor | They purge their own people. It can spiral out of control |
| **Partner arrest** | Ask Jordan's police to pick him up | Cheap, but they may leak or let him go |
| **Drone strike** | A clean kill in an ungoverned zone | No interrogation; a public-opinion hit; revenge |
| **Raid / capture** | A tactical mission (play it or auto-resolve) | Your people's lives |
| **Bounty / public reward** | Reward money for tips | Floods you with false leads; sometimes one is real |

**Combining approaches** is where the strategy lives. Turn the courier → learn about the meeting → wiretap the safehouse → raid it when all three lieutenants are in one room.

### 3.3 The storyteller and the event library (never the same twice)
- A **director** (like RimWorld's) reads the state of the world every week: the threat, how well you're doing, what happened recently. It picks from a large **library of event templates** and controls the pacing: quiet stretches, then crises.
- **Templates are modeled on real history, not literal replays.** Example template: *"Kidnapping of foreign aid workers in {unstable region}; kidnappers demand {ransom}; {host nation} refuses to negotiate."* Slots are filled from the current world: real cities, generated people, the active enemy cells.
- **Events chain into stories with choices** (dilemmas, as in Rebel Inc.): pay the ransom, attempt a rescue, let the host handle it. Each choice has consequences weeks later.
- **Categories:** terror plots, kidnappings, coups, elections, natural disasters, wars breaking out, refugee waves, financial scandals, leaks and whistleblowers, defectors walking in, rival agencies interfering, the media digging into you, host nations changing sides, technological breakthroughs.
- **Scale:** start with **~150 templates**, each with several variants and slots. That's thousands of distinct events, and the library grows over time.

*On pulling 20,000 real events from Wikipedia:* we could, but raw historical events don't plug into game rules, and a literal replay of a real attack can feel exploitative. Recommendation: write templates **drawn from real history** (the kind of thing that really happens, in the places it really happens). Claude can write hundreds without downloading anything. If you still want a real-events import later, it needs your OK to download.

### 3.4 Home front and the loss condition
- **Your home country** (US by default; maybe choosable: UK, France, Israel, Australia…) has a **Homeland** status made of security, public trust and the economy.
- Attacks that land hurt it. A major attack hurts it badly, and so do panic and scandals about your methods.
- **Homeland breaks down step by step:** the economy slides, then martial law, then cities emptying.
- **You lose** when the country falls apart and **your family has to flee**. The losing screen is your family at the border.
- **Washington** also matters: Congress, the press and the President set your budget and **which tools you're allowed to use**. Blackmail and drone strikes may get banned after a scandal.

### 3.5 Family: your life outside the war
- **You are the Director**, a person with a spouse and kids (generated, named, with faces) and a house in a real city.
- **Family events** come from the storyteller:
  - your kid's school play the same night as an op;
  - your spouse wants you to quit;
  - your teenager asks about your job;
  - a reporter at your door;
  - an anniversary you forgot.
  - Late game: **the network finds your address.**
- **Choices pull both ways.** Spend time at home (family OK, you miss a briefing) or stay at the office (better ops, family strain). A collapsing marriage hurts your judgment: worse event odds and slower decisions.
- **Operators have families too:**
  - a widow you write to after a death;
  - an operator's son who wants to enlist years later;
  - an operator who quits because his wife is sick;
  - an operator who's distracted by a divorce.
  This is how people become people.
- **The worst case:** the enemy targets a family. A **personal mission** with real stakes.

### 3.6 A living world
- Nations with **stances** toward you (friendly, wary, hostile) that change through events and through how you operate on their soil.
- **Elections, coups and wars** change what you can do and where, and new ungoverned areas give the enemy room to grow.
- A **generated news feed** that reports your work, mostly without knowing it was you.

---

## 4. Procedurally generated missions (later)
Missions stay in, as one tool of many, but generated: a building generator (compound, apartment, warehouse, villa, office), random guard placement, day or night. **Not first priority**, per the user (2026-11-20). Auto-resolve means the campaign never depends on a mission being fun.

---

## 5. Proposed build order

| Phase | What | Why first |
|---|---|---|
| **A. Toolbox** | Generated weak points per person; the approaches above as week-long actions with costs and risks; informants and moles as ongoing assets; auto-resolve for every op | The user's main ask: freedom to attack however you want |
| **B. Storyteller + event library** | Director; ~150 templates with slots; chained stories with dilemmas; news feed | "New every time" |
| **C. Procedural enemy** | Generated identity, structure, leader personality, money sources, a master plan with stages, enemy counter-intelligence | Each campaign plays differently |
| **D. Home front + family** | Homeland status and loss, Washington and allowed tools, Director's family, operators' families | Stakes |
| **E. Living world** | Nation stances, coups, elections, wars | Depth |
| **F. Procedural missions** | Building generator, mission types | Variety in the tactical part |

Each phase ends playable, as always.

---

## 6. Questions for the user
1. **Adopt this direction?** Toolbox plus auto-resolve means the tactical game becomes optional.
2. **You as the Director with a family**, or only your operators' families?
3. **Home country:** US only, or choose at the start?
4. **Real events:** history-inspired templates (recommended), or also import real events later?
