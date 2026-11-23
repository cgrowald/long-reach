# Hacking: research, GPT's concepts, and minigames to pick from (2026-11-22)

*User: "Hacking should be quick and fun, limited screen switching. Build in that we'll add in-person hacking to get into buildings that have air gaps; we can start with basic things like uploading a program that gets you what you want. I don't know what kind of minigame it should be: research a ton of hacking games, spitball some, and we'll pick. Hacking is scary for me right now because the UI is janky: face-lift it along with making the game." GPT's PATCHBAY puzzle: "fine for making the connection, and then maybe we inject programs that need another kind of puzzle?"*

Gamified only (CLAUDE.md): toys and learnable angles, never real procedures.

## 1. What other games do (and what we take)
| Game | The hack | What works | What doesn't | Take |
|---|---|---|---|---|
| **Cyberpunk 2077** (Breach Protocol) | A grid of codes; pick along a row, then a column, then a row, to spell 1-3 "daemon" sequences in a small buffer | 20-40 s; several optional goals at once = greed; the buffer size is gear | Abstract (codes mean nothing) | **Strong fit for "inject":** each sequence is a payload you upload |
| **Deus Ex: Human Revolution** | Capture nodes toward the target while a trace races back from the defender | Tension you can read; tools (stop worm, nuke) are items | 60-90 s, same every time | The race against the trace; tools as consumables |
| **Watch Dogs / BioShock** | Rotate pipe pieces to route a signal | Instantly readable | Gets rote fast, no stakes | The **connect** step (GPT's PATCHBAY is this, with gear modules added) |
| **Fallout 3/4** | Guess the password from a word list; "likeness" feedback; duds removed by brackets | Short, a little deduction | Solvable by rote | Our crackle dials already do "guess from the owner's life" |
| **Gunpoint** (Crosslink) | Rewire a building's switches, lights, doors and cameras on an overlay | Hacking changes the *place*: the payoff is a better fight | Needs a building to act in | **The in-person / op hack:** link the light switch to the door, loop the camera |
| **Midnight Protocol** | A turn-based board of nodes; a deck of programs (breakers, sniffers); trace and sysops | Programs are your loadout; very planned | Keyboard-only, slow, easy to forget the rules | Programs as a loadout you craft |
| **Hacknet / Uplink** | Typed commands against a trace timer | Feels like real hacking | Typing walls; the user wants mouse first | The trace timer and the "connect, crack, grab, wipe logs" rhythm |
| **TIS-100 / Exapunks** | Write tiny programs | Deep and clever | Homework, not 60 s fun | Nothing (too heavy) |
| **Mass Effect, BioShock, System Shock 2** | Timing or frogger toys | Quick | Called the worst kind: random, unrelated to the world | Avoid toys with no tie to the world |
| **NieR: Automata** | A little twin-stick shooter | Juicy | An action game inside an RPG | Probably not for us |
| **Duskers** | Typed commands drive drones through a dark ship | Huge tension | Typing | Later, for drones maybe |

**The lesson:** the hacks people like are **short, readable, and change what happens next** (Gunpoint, Breach Protocol, Fallout). The hated ones are random toys with no link to the world.

Sources: [PCGamesN best hacking games](https://www.pcgamesn.com/best-hacking-games), [Game Rant worst hacking minigames](https://gamerant.com/worst-video-game-hacking-minigames/), [Game Rant top 10 hacking games](https://gamerant.com/best-hacking-video-games-list/), [TechRadar best and worst](https://techradar.com/news/gaming/before-watch-dogs-the-best-and-worst-hacking-games-1250541), [Sportskeeda interesting hacking mechanics](https://www.sportskeeda.com/esports/5-best-video-games-interesting-hacking-mechanics), [Midnight Protocol reviews: Phenixx](https://phenixxgaming.com/2021/10/29/midnight-protocol-pc-review), [Screen Rant decks](https://screenrant.com/midnight-protocol-best-deck-builds-guide/), [Game Developer: Midnight Protocol design](https://gamasutra.com/design/hacking-answers-tactical-narrative-game-midnight-protocol).

## 2. GPT's concepts, read against this
- **The desktop + login** (petrol, ivory, copper; a left dock of Files / Mail / Jobs / Tools / Field; a top bar with OFFLINE and the clock; a toast "Job updated"): the right look for the OS face-lift. Clean and calm, unlike ours now.
- **PATCHBAY** (route a signal across a 5x4 grid with tiles from a tray; modules BUFFER / FILTER / BRIDGE from crafted hardware; NOISE bar; TEST LINK): a good **connect** step. It's the pipe puzzle, made better because the tray and the modules come from your benches. *Risk:* pipe puzzles go rote, so the grid must change per target and the noise must push you.
- **WATCHLINE** (camera sources you've linked, signal quality, modules, "ADD TO FIELD DESK"): not a puzzle, a **manager**. It's where camera access lands and gets sent into an op. Good as a simple app.
- **SPOOL** (rebuild a damaged disk from fragments into a readable document): a jigsaw. Nice for story files, but a third puzzle per hack is too much switching. Better as an **optional** step for rare files only.
- **My read:** GPT gives one puzzle (PATCHBAY) and two screens around it. The user's instinct is right: connect with one puzzle, inject with another. But **both should happen in one window**, so there's no app hopping.

## 3. The shape Claude suggests: one window, two beats, about a minute
1. **CONNECT** (PATCHBAY-style): route the signal to the target. Gadgets add special tiles (bridge, buffer, filter). The trace starts when you test the link.
2. **INJECT** (the pick below): choose what to upload. Each program is one payoff (files, camera, payroll, delivery, dirt), locked behind its knowledge wall until learned. Greed vs trace.
3. **Out:** results land where they belong: files on the shelves (for the fixer or Nod), cameras in WATCHLINE, a crate at a drop, money in the wallet. SPOOL only for rare damaged files.

The trace bar runs through both beats; getting cut out = Bureau attention + the target locked (decided).

## 4. In person (air gaps), built in from the start
- Some targets say **"AIR GAP: needs a device on site."** The PC can't reach them.
- You make a **drop device** on the hacking bench (a USB stick, later a planted relay box) and carry it on an **outing** (or one of your people carries it into an op).
- On site it's the **same inject puzzle**, but on a small handheld screen with a real-time clock (a patrol coming) instead of the trace.
- **First version:** "upload a program that gets you what you want": plug in, one inject round, walk away.
- **Later:** a planted relay turns the air-gapped place into a normal PC target; in ops, "exploit every PC" (the user's army rule) uses this; a Gunpoint-style **crosslink** to rewire a building before a raid.

## 5. Inject minigames to pick from (spitballs)
**A. Code chain (Breach Protocol style).** A grid of short symbols. You pick one in the top row, then down that column, then across that row... Each program you want is a short symbol sequence; spell as many as fit in your buffer. Buffer size and starting hints come from gadgets. *Quick (20-40 s), greedy, proven.* Build: small.

**B. Node race (Deus Ex style).** A small node map; click to capture nodes toward the files while the trace climbs back toward you from the server. Tools (a stall, a decoy) are crafted items. *Tense and readable, 60 s.* Build: medium.

**C. Payload packing (the rig grid, again).** Programs are Tetris-like pieces; fit them into the target's memory grid before the trace fills. Bigger payoffs = awkward shapes. It mirrors the rig grid the user already likes. *Very "our game".* Build: small to medium.

**D. Signal tuning (for in person / wireless).** Two knobs on a little oscilloscope: match the target's waveform, hold it steady while the upload bar fills; drift and interference fight you. *Tactile, 15-30 s; great on the handheld.* Build: small.

**E. Crosslink (Gunpoint style; for buildings and ops).** A blueprint overlay of a place: drag wires between devices (light switch → door, camera → loop, alarm → nowhere). Pays off in the fight. *Most game-changing, but needs places with devices.* Build: bigger (do it with the bar mission).

**F. Password from their life (what crackle does now).** Keep it as an alternative key: dirt on the owner can skip the CONNECT puzzle. Build: exists.

**Claude's pick:** **CONNECT = PATCHBAY**, **INJECT = A (code chain)** on the PC, **D (tuning)** for the first in-person handheld, **E (crosslink)** later with the bar mission, **F** kept as the dirt shortcut.

## 6. The OS face-lift goes with it
Build the hacking window in the new look (GPT's petrol / ivory / copper, the left dock, top bar, toasts) and move the rest of HEARTH to it in the same pass. The unreadable font is already fixed game-wide (2026-11-22: one sharp monospace, UI drawn at full resolution).

## 7. Decided (user, 2026-11-22)
- **Main hacking:** CONNECT = PATCHBAY, INJECT = A (code chain), ON SITE = D (signal tuning), plus F (the owner's password from dirt skips CONNECT). B, C and E come later for different hacks.
- **Faces** for the mission face-lift: option a (2D layered pixel portraits).
- **Order:** this hacking build, then the face-lift, then bench by bench, step by step, until each looks clean and perfect.

## 8. Built (2026-11-22)
- **Rules** (`v2/sim/hack.gd`, `data/v2/hacking.json`): the two fixed targets plus 9 town places generated from the world seed (office, depot, shop, clinic, police); 3 or 4 show each night, rotating. Tiers 1-3 set the board size and trace speed. Programs: GRAB and WIPE known from the start; DIRT, EYES (cameras), REROUTE (a crate at the drop next morning) and PAYDAY (money, more heat) are locked until learned (no way to learn them in play yet: F1 > "Learn all hacks"). Cut out = clue + Bureau attention + target locked 3 nights. Air-gapped places need a **drop stick** (new hacking-bench recipe) and you go there: TUNE then INJECT against a 75 s patrol clock.
- **PATCHBAY app** (`v2/os/apps/patchbay.gd`, the dock's Jobs button): one maximized window. Left = tonight's targets (tier dots, READY / AIR GAP / LOCKED / DONE chips), middle = briefing, then the puzzle, then the report, right = the box's gadgets, top = steps and the trace bar. A hack costs one night action.
  - CONNECT: click a tray piece, click a slot to place it, click it again to turn it, right-click to take it back; the signal lights up copper as it flows and the link opens the moment it reaches OUT. SCAN gadget = ghost tiles.
  - INJECT: a 5x5 (6x6) code grid; pick along the lit row, then the lit column...; programs run the moment their code shows up in the buffer. CRACK gadget = longer buffer, NET gadget = slower trace. JACK OUT any time.
- **DEAD DROP app** (`v2/os/apps/drop.gd`, the dock's Drop button): every intel file has SELL (the fixer; price drops per kind) and POST (Nod; followers, recruit leads, account heat; burned at 100 = new account). Fixer trust 5 = "market behind the market" (not built).
- **OS face-lift:** petrol desktop with a factory line drawing, ivory windows with flat petrol title bars, copper selection, a top bar (HEARTH, Applications, Files, Session, OFFLINE, clock), a left dock (Files, Mail, Jobs, Drop, Tools, Shell), window tabs at the bottom, the LOCAL SESSION login. Old Jobs/job windows and hack_job.gd deleted.
- **Tested:** rules bot (30 checks), and a bot driving the real PC (login, brief, connect by clicks, inject, report, on-site tuning, Dead Drop) with screenshots. Not tested by a person: whether it's fun, the knob feel, the difficulty.
