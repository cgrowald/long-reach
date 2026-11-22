# Project history: what was built, played, decided and dropped

*Written 2026-11-21 so a fresh session has the whole story and doesn't re-propose things the user has already done or rejected. Newest first. Details live in the linked docs, and the user's raw words are in the vault's Running Thoughts.*

---

## Where we are now (2026-11-21, latest)
- **Design only, nothing is being built.** The user: "We're not building anything yet, we're trying to get the main gameplay loop down."
- **The current loop is `docs/CORE_LOOP.md`:**
  - one "job" engine for every path (hack, exploit a person, break in, work there, later send people);
  - conflicts A to E decided (section 5b).
- **The hunt is designed:** `docs/HUNT.md` (suspect pool, named inspector, clues; 4 questions decided). It is a layer on top of the job engine and is built only after a job is fun on its own.

## The v2 toys: ALREADY PLAYED, verdict given (do NOT ask the user to play them again)
- **Built 2026-11-21 in `v2/`** (main scene `res://v2/menu.tscn`):
  - **Packet Pit:** a Ball x Pit-style hack. Aim, pull the SEND lever, packets bounce through nodes.
  - **Breach Hand:** a Balatro-style hack. Packet cards with ports as suits and poker hands as protocols.
- **What they share:** a pixel CRT, and an Iron Nest-style rig with cartridges, a lever, CHIPS × MULT counters, trace lamps and an intel tier ladder.
- **The user played both.** Verdict: *neither as is.* "It's gotta be a mix of the two."
- **What the user wants instead:**
  - a deck of hacking cards that come only from learning techniques or making gadgets;
  - specific cards do specific jobs (break a firewall, get an SSH shell);
  - cards are used once;
  - each target has a network (Deus Ex / Cyberpunk);
  - Balatro-style upgrades: star-rated tools act as jokers, technique levels act as planets, and you get faster at hacking buildings over time;
  - the "OHHH, that's the actual way to do it" moment: combo the right exploits, don't spam a button.
- **That became the hack v3 design** (`docs/RESTART.md` section 6).
- **The user then widened it:** the same card and combo system also works for **exploiting a person** (getting codes, dirt or intel out of someone). This is the job engine in `CORE_LOOP.md`.
- **The toys are reference code only.** The rig UI, pixel root, juice helpers and sims in `v2/ui` and `v2/sim` may be reused when building starts again.

## The restart (2026-11-21)
- **Why the restart:** the user wanted to scrap the build: "just making buttons to click", and the art put them off.
- **What changed:** a new look and a new project folder (`v2/`). The old build is tagged `v1-final`.
- **Research:** `docs/MARKET_RESEARCH.md` covers Iron Nest, Papers Please, Welcome to the Game, Hacknet/Uplink, Orwell/Beholder, Duskers, Schedule I, Balatro and Antistasi, plus Shadows of Doubt, Ball x Pit, Thief Simulator and Mount & Blade.
- **The look:**
  - White Knuckle: low-poly, pixel-dithered, strong coloured light, pixel hands;
  - Iron Nest: touchable panels, dials, levers, a clipboard.
  - Low poly keeps the cost down; the animations make it pretty.
- **Structure:**
  - **One long campaign** (Antistasi), with **minigames that reset every day** (Iron Nest: fun, repetitive, new conditions).
  - **Every minigame is scored** like Balatro, and the score sets the intel quality tier: bad = just the building, great = the room number and a photo of the crate.
- **Benches:**
  - What you make is first for you, and becomes "standard issue" for your people through machines and workers (which cost money).
  - Good tech is illegal; you get it through the insurgency network and your growing cell.
- **Groups and recruits:**
  - Groups that buy intel become Tarkov-style traders later.
  - Recruits go on XCOM-style missions and are gone for a few days.
  - Star-rated gear makes soldiers legends.

## v1: the old build (2026-11-20), tagged `v1-final`, superseded
- **T1:** a scripted laptop OS week (Pavel's story), as a terminal.
- **T2a:** a 3D pixel garage around the laptop.
- **T3:** the Annex hacking lab: typed commands, loot cards with stars.
- **The combat prototype (`tactical/watch/`):** watch-and-decide.
  - The squad stacks on doors, pies corners, and follows a breach plan panel.
  - Drone and CCTV views.
  - The user liked the doctrine feel. It's kept as the "big ops" combat (CORE_LOOP decision A).
- **Step 1, the open PC sandbox:**
  - a generated town, systemic messages, Market, Workshop, Nod, Map, generated web pages, the drab HEARTH GNU/State look;
  - the user's verdict was "buttons to click, not fun", which triggered the restart.
- **Ideas from v1 still alive** (see CORE_LOOP section 3):
  - a generated country;
  - Bureau heat and raids with the scramble;
  - followers on Nod;
  - inner-circle operators on loan;
  - Pavel as one side story;
  - the user writes some of the story;
  - only adults can be hurt;
  - early prison means game over.
