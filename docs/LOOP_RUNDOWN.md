# Uprising: the full gameplay loop, as built (2026-11-23)

Written for a third-party review (the user will hand it to GPT). It covers:
- what the game is;
- every module that exists, what it does, and what it feeds;
- the loop as it runs today;
- where the links are missing.

The missing links come last, as questions with options. Section 6 lists what we want from the reviewer.

---

## 0. The game in one paragraph, and the fixed decisions

You are a reluctant parent in a generated authoritarian country, working from a garage. You build a resistance movement out of almost nothing: a day job you steal from, a PC you hack from, four workbenches where you make everything by hand in 3D, and a few people you kit out and send on raids. You grow it into an army that storms the capital.

The pressure is the Bureau: a named inspector narrowing a suspect pool toward you. Look: low-poly, dithered pixels, warm garage at night, amber UI (White Knuckle meets Iron Nest).

**Fixed by the user (don't re-open these):**
- **It's a game, not a simulation.** You personally make it all. Stealing and buying guns are extras; the fun is your own hands-on making and leading. Realism is flavour, never a rule.
- **Winning needs an army: at least 1000 men** to take the capital. You can always try early and might get lucky (a 5-man team in 5-star gear), but the game is built around fielding 1000+.
- **Benches are hands-on 3D crafting** (drill, file, cut, sew, tear, pour, fit, solder). Quality = steps x tool x material grade, giving 1-5 stars. Batching unlocks after 3 good crafts.
- **Fights are auto-battles you command** from the van: doctrine, shouts, a feed wall of helmet cams with a face per fighter. Slow pace, real time with a pause, no slow-motion.
- **Hacking** happens in one PC window:
  - CONNECT: route a signal through tiles.
  - INJECT: a code chain that spells out programs.
  - On site (air-gapped places): TUNE knobs instead of connecting.
  - The programs are learned in a tutorial: the post office, then the town hall.
- **Money:**
  - ShopNet: online, basic, purchases logged.
  - Lantern: a black market on the PC with less stock.
  - The Tram Yard: in person after curfew, a risky sneak dash.
  - Lockpicking is pin by pin, Skyrim-style.
- **Intel:** sold to the fixer, or posted on Nod (anonymous social media) for followers. Followers become recruits.
- **Fun first:** one juicy interaction before more systems. Flat button UIs push the user away.

---

## 1. The loop as it actually runs today

```
NEW GAME
  └ pick 1 of 3 day-job cards (hospital / steel mill / textile mill)
DAY n
  MORNING CARD ── steal from work? (nothing / a little / a lot) -> graded materials, suspicion
  EVENING in the garage, 18:00. 2 night actions (big things cost 1; small things are free)
    ├ PC (free) ── Patchbay hack (1 action) -> intel files, crates, money, keys, camera links
    │             ├ Dead Drop: sell intel (money, fixer trust) or post it (followers -> "leads")
    │             ├ ShopNet / Lantern: buy materials, ammo, guns, tools (arrive overnight)
    │             └ Files, Mail, Terminal, Browser... (flavour)
    ├ Benches (free or 1 action) ── make meds, rigs, gun parts, gadgets -> the stash
    ├ The box ── plug gadgets into SCAN / CRACK / NET slots -> better hacks
    ├ Gear cage ── put gear on your 3 people, pack their rigs -> "Send them": the depot raid
    │             └ fight -> deaths, ammo and meds used, loot -> back in the stash
    ├ Roller door (1 action, after fixer trust 5) ── curfew dash -> Tram Yard -> dash home
    └ House door ── sleep
  NIGHT LEDGER ── wages, upkeep, loyalty, crates and parcels arrive, the suspect pool drops
```

What already works end to end:
- job -> materials -> bench -> gear -> people -> fight -> loot;
- hack -> intel -> money or followers;
- money -> markets -> materials and gear.

What doesn't close yet:
- followers never become people;
- Bureau attention has almost no consequences;
- there is only one fight;
- there is no week or campaign structure;
- nothing grows toward 1000 men.

---

## 2. Every module: what it does, what it takes, what it gives

Legend:
- ✔ = the link works
- ~ = partial or placeholder
- ✘ = missing

Code lives in `v2/`, data in `data/v2/*.json`, and design docs in `docs/`.

### A. Time: the day and the night
- **Files:** `sim/game_state.gd` (the whole save: day, clock, money, attention, pool, materials, items, people...), `sim/economy.gd` (night actions, wages, upkeep, loyalty), `stations/sleep.gd`, `ui/overlays.gd` (morning card, night ledger, pause, raid stub, game over), `ui/hud.gd`, `stations/clipboard.gd`.
- **Does:**
  - The evening starts at 18:00 with 2 night actions. Anything of 1.5 hours or more costs an action and moves the clock.
  - Sleep runs `end_day`: wages, upkeep, loyalty, deliveries, rerouted crates, random ledger lines, and the suspect pool drops at random.
- **Links:**
  - ✔ economy ✔ deliveries ✔ crates
  - ~ the "rule of the day" (curfew moved, checkpoint...) is shown but does nothing
  - ✘ no week, events or calendar
  - ✘ the hospital job's night shift is the only thing that changes the action count

### B. Day job and stealing
- **Files:** `sim/economy.gd`, `ui/job_cards.gd`, data `economy.json`.
- **Does:**
  - Three job cards at the start. Each job has a wage, a family of materials, a grade range rolled per game, and a perk (a drill press, a sewing machine, or field dressings unlocked).
  - Each morning you choose how much to steal. Suspicion builds: a warning at 40, an audit at 70 (you lose today's take), fired at 100 (+15 attention).
- **Links:**
  - ✔ materials ✔ money ✔ attention when fired
  - ✘ no way to get a new job after being fired
  - ✘ the job never offers anything else (contacts, access to the building for an op, coworkers to recruit)

### C. Materials and the stash
- **Files:** `sim/materials.gd` (grades 1-5 per unit), `stations/stash.gd`.
- **Does:** 11 materials: shirt, vodka, tape, bag, strap, buckle, aluminium, pins, board, chips, cigarettes. Each unit has a star grade; crafting uses the best grade first.
- **Links:**
  - ✔ steal, crates, markets, barter
  - ✔ benches
  - ✘ materials have no other use (bribes in goods, upkeep in food, trading with people)

### D. Benches (crafting)
- **Files:** `sim/crafting.gd`, `stations/bench.gd`, `world/bench_work.gd`, `world/verbs.gd`, data `recipes.json`, models in `art/items.glb`.
- **Benches:** electronics (hacking), weapons (gun), armor (sewing table), meds (med table).
- **The 9 recipes:**
  - Meds: torn-shirt bandage, field dressing.
  - Armor: shopping-bag rig, chest rig.
  - Weapons: rough upper, a part only.
  - Electronics: port scanner, wordlist drive, signal damper, drop stick.
- **Does:** hands-on steps in 3D, then a formula roll (Balatro-style) to stars and perks. Tier 2 recipes unlock from a good tier 1 craft. Batching comes after mastery. Every bench has its own lamp that brightens while you work. The finished model drops onto the bench.
- **Links:**
  - ✔ to the stash, the cage (rigs, meds) and the box (gadgets)
  - ✘ the gun bench makes one part and no complete gun
  - ✘ no bench or tool upgrades (the starter-to-upgraded sheet exists as art only)
  - ✘ no way to make gear in the quantities 1000 men need

### E. The box (gadgets for hacking)
- **Files:** `stations/box.gd`.
- **Does:** drag gadgets into SCAN (shows ghost tiles on the route), CRACK (a longer code buffer) and NET (a slower trace). Better stars help more.
- **Links:** ✔ crafting to the box to hacking.

### F. The PC: HEARTH OS
- **Files:** `os/desktop.gd` plus apps (`patchbay`, `drop`, `shop`/`lantern`, `files`, `mail`, `browser`, `terminal`, `notepad`, `software`, `monitor`, `settings`). Data `os.json`.
- **Does:** a fake Linux-like desktop. Using it costs no time; only the actions inside it can.
- **Links:**
  - ✔ hacking, intel, markets
  - ~ mail, browser and terminal are flavour; the scripted story mail is old
  - ✘ no messages from your people or the fixer as characters

### G. Hacking
- **Files:** `sim/hack.gd`, `os/apps/patchbay.gd`, data `hacking.json`.
- **Targets:** the tutorial (post office, then town hall), two fixed specials (water office, Dobrev Freight depot), and a roster of 9 town places generated per game (offices, depots, shops, clinics, a police station). A police station is air-gapped and needs a drop stick plus going there yourself. Three or four show each night.
- **The six programs:**

| Program | What it gives |
|---|---|
| GRAB | intel files |
| WIPE | lowers the trace |
| DIRT | dirt on the owner, plus their password, which skips CONNECT next time |
| EYES | the building's cameras linked |
| REROUTE | a crate of materials tomorrow |
| PAYDAY | money, plus attention |

- **Getting caught:** cut out = +attention, a clue for the Bureau, and the target locked for 3 nights.
- **Links:**
  - ✔ intel, money, materials
  - ~ EYES says "you'll see them in a raid there", but no raid uses it
  - ✘ DIRT gives leverage over a person, but there is no system to use a person
  - ✘ the Bureau's clues are only stored in a list

### H. Intel: the Dead Drop
- **Files:** `sim/intel_market.gd`, `os/apps/drop.gd`.
- **Does:** each file is sold or posted.
  - **SELL to the fixer:** credits, falling the more of a kind you sell; +1 trust per sale (trust 3 opens Lantern, trust 5 the Tram Yard).
  - **POST on Nod:** followers and heat. At 100 heat the account is burned and you start over at zero. Every 150 followers = 1 "recruit lead".
- **Links:**
  - ✔ money, trust, markets, attention
  - ✘ **leads go nowhere**: no recruit flow
  - ✘ intel tags (plan, names, dirt, money) do nothing else, for example a "plan" file showing a raid's layout

### I. Markets
- **Files:** `sim/markets.gd`, `os/apps/shop.gd`, `stations/outside.gd`, data `markets.json`.
- **Does:**

| Market | Stock | Delivery | Catch |
|---|---|---|---|
| ShopNet | basic, grades 1-2 | overnight | electronics buys logged (+attention) |
| Lantern | 5 items, x1.45 price, grades 2-4 | dead drop overnight | 10% scams |
| Tram Yard | 9 stalls, grades 2-5, guns, armor, a drill press | you carry it home | barter accepted, maybe a sting (too cheap, with a tell) |

  Stock rerolls daily and prices rise with attention.
- **Links:**
  - ✔ money in, materials, gear and tools out
  - ✘ no regular costs: no rent, no family, no growing upkeep
  - ✘ nothing to buy later in the game (vehicles, safe houses, bulk orders)

### J. Going out: the curfew dash and lockpicking
- **Files:** `sim/curfew_map.gd`, `stations/outside.gd`, `sim/lockpick.gd`, `ui/lockpick_view.gd`, data `locks.json`.
- **The dash:** a generated night map with patrols carrying torch cones and a searchlight. Lamps expose you, dark corners hide you, and running is loud. Caught = a bribe or a search (you lose the bag, +attention).
- **Lockpicking:** pin by pin; you can snap picks. Only used on the yard gate on the way to the Tram Yard. A toy on the title screen has 4 locks.
- **Links:**
  - ✔ the markets
  - ✘ the Tram Yard is the only place you can go out to
  - ✘ in-person hacking is launched from the PC (you never walk there)
  - ✘ locks guard nothing else (stashes, offices, the hatch)

### K. People and gear
- **Files:** `sim/loadout.gd`, `stations/cage.gd`, `ui/face.gd`, `combat/soldier.gd`, data `gear.json`.
- **Does:** you start with 3 people (Viktor, Ada, Ivo: Pavel's old crew), each with a role, a trait, loyalty, a level, an ops count and a procedural face. Gear slots are primary, sidearm, head, face, rig (a grid you pack), plate, back and clothes. They show in 3D in the cage and in the fight.
- **Links:**
  - ✔ crafting, markets and loot to gear, and gear to the fight
  - ~ loyalty drops if unpaid and they can walk out (+attention)
  - ✘ no new people ever join
  - ✘ no skills or training
  - ✘ injuries aren't carried over
  - ✘ no cells or squads beyond these 3

### L. Combat
- **Files:** `combat/fight.gd`, `level.gd`, `actor.gd`, `squad_ai.gd`, `enemy_ai.gd`, `rules.gd`, `ops_board.gd`, `combat_audio.gd`, data `combat/depot.json`.
- **Does:** one op, a night raid on the Dobrev Freight depot.
  - Your team clears room by room by doctrine. You give orders on a paper ops board and shout calls from a wheel.
  - They push back when the order is dangerous, and repeating it overrules them.
  - The FIELD LINK screen shows one cam feed per fighter with their face, and the face stays when the cam cuts out.
  - Ends in an op report. Tarkov-lite rules: gear gives stats, ammo and meds are finite.
- **Links:**
  - ✔ cage to fight to `apply_op` (deaths, ammo and meds spent, loot)
  - ✘ the op doesn't come from intel or hacking
  - ✘ no reward beyond loot (no money, territory, followers or story)
  - ✘ only 1 level
  - ✘ no op generator

### M. The Bureau: the hunt
- **Files:** `stations/corkboard.gd`, `game_state.gd` (attention, pool), clues in `state.flags.clues`. Design in `docs/HUNT.md`.
- **Attention (0-100) rises from:**
  - hacks you get cut out of, and PAYDAY;
  - posting on Nod;
  - logged buys;
  - stings, being stopped on the street, being fired;
  - one terminal command.
- **What attention does now:** more patrols on the curfew map, and worse bribe odds. Nothing else.
- **The suspect pool:** drops at random each night.
- **The corkboard:** shows a placeholder inspector and placeholder facts.
- **Links:**
  - ~ inputs exist
  - ✘ **almost no outputs**: no raid warning, no house search, no arrest except through the debug panel, no inspector moves
  - ✘ clues don't narrow the pool

### N. Story and contacts
- **Files:** `stations/phone.gd`, Mail, data `world.json`, all placeholder.
- **Exist only by name:** kettle (the hacker friend), Hana (your partner), the fixer (no name yet), the inspector (V. Krall).
- **Links:** ✘ no characters with wants, no scenes, no family pressure yet. The user writes the story text later.

### O. The army and the war room
- **Files:** `stations/warroom.gd` (placeholder). The floor hatch is locked.
- **Links:** ✘ everything: cells, territory, the town map, the march to 1000, the capital.

### P. Shell
- Title screen, settings, 3 save slots plus autosave, F1 debug panel.
- Old prototypes: Breach Hand and Packet Pit, two early hacking minigame toys the user tried and rejected (kept in the code). Also the look test and the lockpick toy.

---

## 3. What flows where

| Resource | Made by | Spent on | State |
|---|---|---|---|
| Money | wages, selling intel, PAYDAY, barter | upkeep (8 per person per night), markets, bribes | ✔ flows; few late-game sinks |
| Materials (graded) | stealing, crates, markets, barter | crafting, barter | ✔ |
| Items / gear | benches, markets, loot | the cage (people), the box (gadgets), meds in fights | ✔ |
| Intel files | GRAB, DIRT | sell or post | ✔ but the tags are unused |
| Night actions (2) | each evening | hacks, long crafts, the curfew trip | ✔ |
| Suspicion (work) | stealing | audits, firing | ✔ |
| Attention (Bureau) | many | patrol count, bribe odds | ✘ few consequences |
| Fixer trust | selling intel | opens Lantern and the Tram Yard | ✔ |
| Followers / leads | posting | nothing | ✘ |
| People | the start (3) | fights | ✘ no growth |
| Loyalty | paying upkeep | walk-outs | ~ |
| Picks | markets, the start | lockpicking | ✔ |
| Keys / passwords | DIRT | skip CONNECT | ✔ |
| Camera links | EYES | nothing | ✘ |
| Clues | getting cut out | nothing | ✘ |

---

## 4. Where it could connect: the open links, as questions with options

Claude's pick is marked ★. The options are meant to be mixed.

**Q1. How do followers and leads become people?**
- a) ★ A lead becomes a recruit message in Mail/Nod. You meet them in person: a short scene where you choose and maybe vet them (a DIRT check, a risk of an informant).
- b) Leads go straight to a roster of applicants with stats; you hire for a fee.
- c) Recruits come from places: coworkers at your job, people met at the Tram Yard, freed prisoners.
- d) Every op you win in a district draws walk-ins from it.
- e) Leads must be "proved" with a small job (deliver a package) before they join.
- f) A mix: Nod gives quantity (militia), in-person gives quality (named specialists).

**Q2. How do we get from 3 people to 1000+ while YOU still feel like you do it all?**
- a) ★ Two layers. Named operators (up to ~12, the FIELD LINK faces, gear by hand) plus militia counted in hundreds, armed in bulk from the gear you mass-produce. Named fighters lead militia units.
- b) Cells: each named leader runs a cell of N that grows on its own. You equip the leader; the cell's strength follows the leader's gear stars.
- c) Squads as cards: each squad is a card with a strength. You see 4-man fights for key ops; everything else auto-resolves on a district map.
- d) Districts: liberate districts one by one; each adds men and production.
- e) Your gear designs become "patterns" that workshops copy at scale. You make the first one by hand; quality copies down.
- f) The war room shows the army as numbers and banners; the 1000 is a meter fed by recruits, armed men and morale.

**Q3. How do you make gear for hundreds and still make it yourself?**
- a) ★ Master a recipe by hand, then it becomes a "line": the people you assign produce it overnight at your mastered quality (minus a little).
- b) Bench upgrades (the starter-to-upgraded sheet) raise batch size: a sewing machine makes x5 rigs per action.
- c) Contracts: the Tram Yard stalls take your pattern plus materials and return copies (cost plus risk).
- d) Captured factories later in the game make your designs.
- e) Hard cap: militia are mostly armed by loot and the black market; your bench gear goes to named operators only.

**Q4. What does Bureau attention DO? (a ladder)**
- a) ★ Thresholds:

  | Attention | What happens |
  |---|---|
  | 20 | more patrols, checkpoints |
  | 40 | the inspector moves (canvassing, a neighbour questioned) |
  | 60 | warning signs; a house search you must clean up for (hide the stash) |
  | 80 | a raid countdown |
  | 100 | the raid |

  Attention cools slowly; WIPE, bribes and decoys cool it faster.
- b) Attention turns into clues, and clues pin facts on the corkboard that narrow the suspect pool. When the pool reaches 1, they come for you (Shadows of Doubt-style, docs/HUNT.md).
- c) Both: attention is how hard they look; clues are how close they are.
- d) Reprisals on the town: the Bureau punishes a district. Town mood falls or rises (anger at them gives you recruits).
- e) The inspector as a Nemesis-style rival who learns your habits (you always hit depots, so depots get guards).

**Q5. Where do ops come from, and what do they pay?**
- a) ★ Intel makes ops. A "plan" file from a depot hack puts the depot raid on the ops board, with the map revealed and the guard roster known. EYES gives live cams in that raid.
- b) The fixer offers contracts (money plus trust).
- c) Story ops at milestones (free a prisoner, hit the radio mast).
- d) Generated ops from the town roster: every hackable place is also raidable, so the hack scouts it.
- e) Ops pay in loot plus the thing the op is for: a crate of rifles, freed people (recruits), a district's fear dropping (mood), or money from a payroll truck.
- f) Op types: raid, ambush a convoy, sabotage, rescue, assassination, propaganda (film it for Nod: followers).

**Q6. What makes a week feel different from a day (the middle layer)?**
- a) ★ A weekly "Bureau move" plus a weekly need (rent, Hana's insulin, a cell asking for meds), so each week has a goal.
- b) Story beats every 7 days.
- c) Market events (a shipment came in, a crackdown).
- d) Seasons: winter means more upkeep, longer nights.
- e) Days of the week matter (Friday payday, Sunday markets).

**Q7. What should intel tags do besides money and followers?**
- plan: the raid layout and patrols known; a better plan on the ops board.
- names: recruits, informants to avoid, blackmail targets.
- dirt: turn an insider (keys, a guard who looks away, a forged pass).
- money: payroll and fuel cards, cash out with risk.
- ★ all four. They make the PC feed the fights and people.

**Q8. Money sinks for the mid and late game?**
- a) ★ Safe houses (more room, more benches, a fallback if raided).
- b) Bribes on a schedule (a cop on payroll lowers attention per week).
- c) Vehicles (a van for ops, a truck for supply runs).
- d) Bulk material orders.
- e) Family (rent, school, medicine).
- f) Upkeep that grows with the army.

**Q9. Losing and winning?**
- a) ★ Lose: arrested with no way out early on (game over); later, prison is an op your people run to break you out. Lose all your people plus no money: a soft fail.
- b) Win: storm the capital. A huge multi-stage op with N squads; needs 1000+ fighters (a soft gate: you can try earlier).
- c) Other wins: a general strike (followers), the army defects (dirt on generals), the leader assassinated.

**Q10. Going out beyond the Tram Yard?**
- a) ★ A town map with places: the Tram Yard, your work, the post office, contacts' homes, targets for on-site hacking. Each is a short hands-on scene (the dash plus a lock plus a minigame).
- b) Only the dash, with different destinations and goals.
- c) First-person walking in a small 3D street (big cost).

**Q11. The first week (onboarding order)?**
- ★ Day 1: job pick, the garage, the post office tutorial hack. Day 2: sell or post, the first bench craft. Day 3: the town hall tutorial and a ShopNet buy. Days 4-5: kettle's first raid (the bar). The fixer opens up; the first recruit lead. Day 7: the first Bureau move.
- Alternatives: no hand-holding after day 1; or a scripted prologue (the night Pavel disappears).

**Q12. People between fights?**
- a) ★ Injuries take days to heal and meds speed it up. Death is permanent.
- b) Skills grow with ops survived (accuracy, nerve).
- c) Stress and trauma (trait changes).
- d) Relationships (pairs fight better together).
- e) Families (each recruit has one; the Bureau can use them).

**Q13. Bench upgrades: how do you get the "upgraded" stations?**
- a) ★ Buy tools at markets (a sewing machine on ShopNet, a fume fan on Lantern).
- b) Earn them through mastery.
- c) Craft them at another bench.
- d) Loot them in ops (raid the textile mill).

**Q14. Fights: what variety?**
- a) Generated buildings from the target type (bar, depot, office, police station).
- b) Hand-made story maps for key ops.
- c) ★ Both: generated for the roster, hand-made for milestones.
- d) Your intel and EYES change what you see before going in.

---

## 5. Claude's suggested full loop (if the ★ picks are taken)

```
EVENING (one day)
  day job steal  ─┐
  PC: hack ─ intel ┼─ sell (money, fixer trust) / post (followers -> leads -> recruit scenes)
                   └─ "plan" intel -> an op on the ops board
  benches: make by hand -> mastery -> production lines (militia gear overnight)
  markets: buy what you can't make
  go out: the Tram Yard, meet a recruit, an on-site hack
  ops: named operators lead; win -> loot, freed people, district mood, money
NIGHT
  production lines run, deliveries land, upkeep paid, the Bureau moves (attention ladder + clues)
WEEK
  a need (family or cell) + a Bureau move + one story beat
CAMPAIGN
  3 people -> named operators (~12) -> cells and militia (hundreds) -> districts -> 1000+ -> the capital
  the inspector closes in the whole way; getting raided means moving the garage (a safe house)
```

**Build order Claude would suggest:**
1. The recruit flow (Q1).
2. Intel makes ops (Q5 + Q7) with a second op (the bar).
3. The Bureau ladder (Q4).
4. The week (Q6).
5. Production lines and militia (Q2 + Q3).
6. The town map (Q10).
7. The war room and districts.

---

## 6. What we want from the reviewer
1. Where does this loop stall or get boring, minute to minute and over 10 hours?
2. Which links in section 3 are the most important to close first?
3. Better options for Q1-Q14, especially Q2 (the scale to 1000 while the player still does it all) and Q4 (Bureau pressure).
4. Games, books or films that solved the same problems, with the mechanic named.
5. Anything that contradicts the fixed decisions in section 0, flagged as such rather than assumed.
