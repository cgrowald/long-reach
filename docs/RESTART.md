# The restart (v2)

*2026-11-21. The user wants to scrap the current build ("you're just making buttons to click") and start over around a loop that's fun right away. This doc holds the decisions so far, the look, and the research and concepts for the first piece: the hacking minigame. Background: docs/MARKET_RESEARCH.md.*

---

## 1. Decisions (user, 2026-11-21)

1. **Start over:**
   - a new project and a new look;
   - the old code stays in git history (tag it), and we copy pieces only when they fit;
   - the design docs stay.
2. **One long campaign** (Antistasi), but **the minigames reset every day** (Iron Nest): fun, repetitive, and the conditions change.
3. **Every minigame is scored like Balatro or Ball x Pit.** Cards, multipliers, combos. **Your score sets the quality of what you get**:

   | Score | Intel on a gun shipment |
   |---|---|
   | Bad | which building it's in |
   | OK | which floor, and when it moves |
   | Good | the room number and the guard schedule |
   | Great | a photo of the crate, the crate number and the buyer |

   The same goes for meds, dirt and everything else.
4. **Going out is like Shadows of Doubt, plus screens.** A generated town where every building has rooms and people, first person, and cameras and feeds you watch.
5. **The look:**
   - low poly and pixelated to keep costs low;
   - the animations make it pretty;
   - **White Knuckle's look** (see section 3) with **Iron Nest's feel of touching things**.
6. **The first piece is a PC dig for dirt:** a hacking minigame made Balatro or Ball x Pit-like, not typed commands. The user is still thinking about it; the concepts are in section 4.
7. **Benches:**
   - What you make by hand is for you.
   - Making it **standard issue** for your people means automating it: buy machines and hire workers. That costs money, and you can't make everything every day, so you choose what to outfit, first yourself and then your troops.
   - Open idea from the user: the end of each day is another Ball x Pit or Balatro-style fight, with your soldiers or yourself. Not decided yet.
8. **The groups that buy from you are like Tarkov's traders:**
   - procedurally generated;
   - they give quests and gear;
   - quests for one hurt another a little.
   
   They're a later update. At first you can source everything yourself. Once you have people, you send them on missions XCOM-style: pick your people, and they're gone for a few days.

---

## 2. The loop (v2)

> **Dig (PC minigame) → score sets the quality of the intel → sell it or use it → money buys kits and tools → better tools mean better scores and new targets → go out for what a screen can't get → people → automation → you pick the targets.**

- **The day:** the morning rule (a condition that changes today's minigames) → choose a target → play its minigame (the dig, a bench build, an outing) → the score becomes loot → sell, use, or keep it → night.
- **Your tools are your jokers.** Every tool, upgrade and contact adds a modifier to the minigames ("+2 mult on anything with a password", "the first trace spike is free"). Choosing targets for the upgrade you want next is the build-crafting.
- **The arc:** you do everything → you automate what you've mastered → you send people out → you choose the big targets.

---

## 3. The look

From the user's screenshots:
- **White Knuckle:** low-poly geometry with low-res, slightly dithered textures. Strong single-colour lighting (bruise purple, sodium orange, cold grey concrete). Pixel-art first-person hands. Big brutalist spaces. Menus are chunky pixel UI on a dark red CRT-like screen ("WARNING: EXPERIMENTAL").
- **Iron Nest:** panels you touch. Brass dials, rolling number counters, toggle switches with lights, levers, a clipboard with handwritten notes, a stopwatch on a map. Every input is a physical object with a satisfying *clunk*.

**For us:**
- **First person at your bench**, with pixel hands.
- **The PC is a screen on the desk.** Next to it is a **physical hack rig**: switches, dials, a slot for tool cartridges, a big SEND lever. Your upgrades are modules you physically install on the rig, so the Balatro jokers are objects you can see and touch.
- **The garage:** low-poly, dithered, one lamp and the screen glow.
- **The animations carry it:** hands reaching, switches snapping, counters rolling, the screen shaking on a big multiplier.

---

## 4. The hacking minigame: research

### What the games teach us
- **Balatro:** the maths is just chips × mult. What makes it feel good is that **every step is shown and heard**: each card and joker fires one at a time with a rising ping, and the number climbs. One analysis calls the juice the game: "strip Balatro's animations and sounds and you have a calculator." Two separate levers (chips and mult) let you build in two directions.
- **Ball x Pit:** fire balls into a field of bricks, watch them bounce, and fuse balls into new ones. Between runs you rebuild a city whose buildings give upgrades. Praised for its fusion and combos; criticised for repetition and a slow meta.
- **Midnight Protocol:**
  - A hacking game where you bring a **limited deck of programs** to each job.
  - The network is a map of nodes: access, data, finance, encryption. Each program suits a node type (*leech* drains a finance node, *spoon* cracks an encryption node).
  - A **trace bar** fills each turn.
  - Hardware upgrades give stronger breakers, a longer trace bar and more deck slots.
- **Cyberpunk 2077's Breach Protocol:** a grid of codes, and a limited buffer.
  - Pick codes to complete **sequences (daemons)**. Each sequence is a different reward, and completing several in one go is the combo.
  - A better deck gives a bigger buffer.
  - The timer only starts on your first pick, so you can plan first.
- **The new wave of hacking deckbuilders** (Null Runner, NETFALL, Terminal Warfare, DeckRunners) all use the Netrunner shape: your programs break the target's defences (ICE) before the trace catches you. DeckRunners is the only one that names Balatro as an influence. Lesson: the deckbuilder version is common. A **Ball x Pit-style physical hack** would be fresher.

### Three concepts (the user picks, ideally after playing 30-second toys of two of them)

**A. "Breach hand" (Balatro).**
- The target is a stack of security layers with score thresholds. Each threshold is one tier of intel: beat 300 for the building, 800 for the floor, 2,000 for the room, 5,000 for the crate photo.
- You draw a hand of **packet cards**. Each has a port (SSH, MAIL, CAM, BADGE: the suits) and a value. You play sets: same port, runs, credentials + exploit + payload.
- **Every play raises the trace**, and you stop or get caught.
- **Your tools are jokers.** For example: "Sticky-note reader: ×2 mult on PASSWORD cards when the target has a careless clerk."
- **The target's weak spot** (from the town) is a bonus, and **the rule of the day** is a boss modifier ("Firewall update: MAIL cards score 0").
- *Strengths:* proven, deep build-crafting, easy to read. *Risks:* it's poker with a skin, and the deckbuilder market is crowded.

**B. "Packet pit" (Ball x Pit / Peglin).**
- The target network is a board of nodes falling from the top:
  - firewalls (bricks to break);
  - data nodes (chips);
  - exploit nodes (mult);
  - honeypots (trace spikes);
  - a sysadmin who patches holes.
- You aim and launch **packets** that bounce through the network:
  - a worm splits;
  - a keylogger sticks and drips data;
  - a phish is slow but turns a node to your side.
- **Fuse two packets** into a new one.
- **Trace:** the board creeps down every launch. When it reaches you, you're out. You can pull out any time with what you have.
- Score → intel tier, as in A.
- *Strengths:* very physical, very watchable, made for juice (bounces, breaks, combos). It fits "touch" (aim, then pull the SEND lever) and it's fresh in the hacking genre. *Risks:* aim-and-watch can get samey; it needs strong packet variety.

**C. "Sequence breach" (Breach Protocol with multipliers).**
- A grid of codes. Pick a path through it to complete sequences.
- Overlapping sequences chain into a combo multiplier. A bigger buffer comes from upgrades.
- *Strengths:* short and clean, a real puzzle. *Risks:* less juice, and it's solved more than played.

**Possible twist for any of them: one engine, many skins.** The same core could run every minigame with different pieces, so learning one carries over:
- the dig: packets into a network;
- a break-in: tools into a lock or alarm system;
- a bench build: parts onto a board;
- the end-of-day fight the user floated: your soldiers into a building.

This also matches the project rule "one tactical engine for every mission type".

### Claude's recommendation
*(Done 2026-11-21: both toys were built AND played; the user rejected each as is and asked for a mix, see section 6 and docs/CORE_LOOP.md.)* Build **B and A as two tiny toys** (one target, a few packets or cards, two tools, a score → intel-tier readout), each playable in 30 seconds, in the new look's grey box. The user plays both and picks, then we build that one until it's fun before anything else.

---

## 5. Gaps still open
- The hacking concept (A, B, C or a mix): the user is thinking.
- The end-of-day fight: is it a thing, and is it the same engine?
- How going out works minute to minute (Shadows of Doubt style: what do you actually do in a building?).
- Saves: daily, at night (decided earlier, still holds?).
- Story: Pavel and the user's stories. Where do they fit in v2?
- Audio: the sounds we have, plus what the juice needs (rising pings, clunks).

## Sources
- Balatro: [blakecrosley.com design guide](https://blakecrosley.com/guides/design/balatro), [GMTK: Balatro's cursed design problem](https://gmtk.substack.com/p/balatros-cursed-design-problem), [AV Club](https://www.avclub.com/balatro-hones-the-art-of-making-numbers-go-up), [GamesHub](https://www.gameshub.com/news/features/balatro-roguelike-deckbuilder-2637397)
- Ball x Pit: [PC Gamer](https://www.pcgamer.com/games/roguelike/ball-x-pit-review), [Destructoid](https://www.destructoid.com/reviews/ball-x-pit-review/), [GamesRadar](https://www.gamesradar.com/games/roguelike/ball-x-pit-review), [Mobalytics](https://mobalytics.gg/gamebase/reviews/ball-x-pit-review), [Gamereactor](https://www.gamereactor.eu/ball-x-pit-1656513/)
- Midnight Protocol: [Game Developer](https://gamasutra.com/design/hacking-answers-tactical-narrative-game-midnight-protocol), [Softpedia](https://www.softpedia.com/reviews/games/pc/midnight-protocol-review-534571.shtml), [Third Coast Review](https://thirdcoastreview.com/2021/10/12/review-midnight-protocol)
- Breach Protocol: [PC Gamer](https://pcgamer.com/how-to-cyberpunk-2077-hacking-breach-protocol), [Sportskeeda](https://www.sportskeeda.com/esports/cyberpunk-2077-how-breach-protocol-efficiently), [Gamepressure](https://www.gamepressure.com/cyberpunk-2077/hacking/z7c78e)
- Hacking deckbuilders: [DeckRunners](https://sirdrmchurtz.itch.io/deckrunners), [Terminal Warfare](https://store.steampowered.com/app/4812060/Terminal_Warfare)
- White Knuckle: [80.lv breakdown](https://80.lv/articles/breakdown-how-dark-machine-created-a-roguelite-speed-climbing-game)

---

## 6. The hack, v3 design (2026-11-21, after the user played both toys)

**What the user said:**
- It has to be a mix of the two toys.
- Build a deck of hacking cards, like other hacking card games. The cards only come from learning how to hack or from making gadgets. Specific cards do specific jobs: one breaks a firewall, one gets you an SSH shell.
- Each card is used once.
- Each target has a network, like Deus Ex and Cyberpunk, but with a fun spin.
- It should be the incremental, giant-numbers feeling of Balatro: planets upgrade hands and jokers add mult and points. Here, your toolset has star ratings that do that, so you hack buildings faster and faster.
- Hacking is one small part of the game. Maybe each hack has its own minigame.
- What you get feeds gear for your soldiers. Star-rated gear makes a soldier a legend and more likely to survive.
- The world of Iron Nest is where you work from.
- The goal is the "OHHH, THAT'S the actual way to do it" moment. Not spamming the hack button, but combining the right exploits. Like Balatro or Ultra Pool: you can play normally and try to win, but the combos get you there.

### The idea in one line
**The combo IS the real attack logic, gamified.** Scout, get in, escalate, then grab. Play cards in the right order, against the weak spot you found, and the numbers explode. Play them randomly and you scrape by. That's the "OHHH" moment, and it teaches the *shape* of hacking (no real procedures).

### Pieces (Balatro mapping)
| Balatro | Ours | Where it comes from |
|---|---|---|
| A blind | **A node** in the target's network (firewall, shell, camera, database, vault). Each has a defence number to beat. | The target (generated) |
| A hand of cards | **Your hack deck**, brought on the job. Each card is used once per hack. | **Techniques** you learned (they come back every hack) + **gadget cards** you made at a bench (gone once played) |
| Poker hands | **Chains**, read in the order played (see below) | Fixed list, upgraded by practice |
| Planets | **Technique levels**: practise a chain and it levels up (+chips, +mult) | Doing it, plus manuals found as loot |
| Jokers | **Rig modules with star ratings** (1-5 ★): permanent passives | Bench-built, loot, the broker |
| Boss blind | **The rule of the day** + the node's security software | The world |

### Card roles (the four suits, but they mean something)
- **SCAN** (recon): low chips, but **tags the node's weak spot** ("old SSH", "default password", "careless clerk").
- **ACCESS** (get in): chips. SSH key, phish, cloned badge, default password.
- **EXPLOIT** (escalate): mult. Overflow, injection, privilege jump.
- **PAYLOAD** (grab or stay): turns the score into loot. Dump, keylogger, backdoor.

### Chains (the "poker hands")
Read in the order you play the cards:
- **Kill chain:** SCAN → ACCESS → EXPLOIT → PAYLOAD. The big one.
- **Tunnel:** 3+ cards of the same protocol (all SSH).
- **Matched:** any card that hits the tagged weak spot ×2 (a stack of matches multiplies).
- **Brute:** 3+ ACCESS cards. Works but is weak and loud (+trace).
- **Ping:** anything else.

### The giant numbers
- **Overkill carries over.** Damage beyond a node's defence flows into the next node. One great chain can blow through three nodes, with the numbers cascading down the network map. This is the Balatro "the score keeps going" feeling.
- **Rig modules multiply,** and a 5★ module is silly ("each Matched card ×3").
- **Week 1:** the Ministry mail server takes 10 careful minutes. **Week 6:** your rig blows through it in 20 seconds and you go for the vault instead. Hacking gets *faster* as you grow, the way the user wants.
- **Late game:** nodes far below your power **auto-crack** (the incremental / automation moment), so you only play the hard nodes by hand.

### Minigames per node type (the mix)
- Most nodes: **cards** (Breach Hand).
- **Firewall boss nodes** (heavy defence): a **flood** minigame. Your chain's score becomes packets, played out Packet Pit style for bonus overkill.
- Later: a **camera node** (loop the footage: timing), a **badge reader** (a rhythm swipe). Each is short, and each is an optional skill bonus on top of the cards.

### Where it goes
- What the hack gets you is **intel tiers** (see section 1) **and parts and plans**: blueprints, codes and schedules.
- Those become **gear at the benches**, and **star-rated gear makes soldiers legends**: better survival, better numbers.
- It all happens from **the Iron Nest room**: the garage, the rig, the benches.

### Open questions for the user
1. Do learned techniques come back every hack (only gadget cards are gone for good), or is every card gone for good?
2. Overkill flowing through the network: yes?
3. Should a node's own minigame (flood, camera loop) be optional bonus or required?
4. How many cards does a hack take? (Claude's guess: a deck of ~15, 5-8 plays per hack, 3-6 nodes.)
