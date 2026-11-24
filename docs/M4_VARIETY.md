# M4: variety (plan, 2026-11-24)

The user, 2026-11-23: *"I fear the game is boring. The combat part is great so far. It needs a variety of maps and targets, and reasons to hit them, to start being fun."* Agreed order (2026-11-24): variety right after D. The user doesn't want to play until more of this section is in.

## 1. The sweep: everything said about it so far
- **Targets** (GAME_DESIGN 0): generated places on the overworld map: government offices (data, dirt), gun stores (weapons), a metal refinery (parts), police posts, roadblocks, officials, radio towers, depots. "Different loot gives different upgrades, so you choose targets by what you want to upgrade."
- **The first fights are small guerrilla work** (RUNDOWN 8): the bar where a politician drinks; a daytime checkpoint ambush (the user's reference: *The Devil's Own*). The bar was picked as the easy first mission (2026-11-22). COMBAT_SLICE 11: an easier first mission (a couple of guards, no Bureau); the police officer beat (befriend or exploit a cop, steal his keys, rob the police station: your first real guns).
- **One AI for any place** (COMBAT_SLICE 11): trenches, roads, houses, gas stations, bars; the doctrine and cover can't be built only for corridors. The scenario decides: a cheap shotgun wins up close; a small roadblock on foot is winnable, an army squad on a road is not.
- **Generated buildings** (DEPOT_SLICE R1, G3; LOOP_RUNDOWN Q14): a new building every time, generated from the target type (bar, depot, office, police station); hand-made maps for milestones. Every depot raid different (guards, stores, rooms). After a raid the place adapts: it covers the exploits you used (R3); ROADMAP M4 "an enemy that learns".
- **Op types** (LOOP_RUNDOWN Q5 f): raid, ambush a convoy, sabotage, rescue, assassination, propaganda (film it for Nod).
- **Open world** (user 2026-11-23): Schedule I style; things take time and pop up (contacts, jobs, targets, deliveries); no gates. **The overworld map** of what we hold and what they hold, Paper Mario style (wanted soon; M6 look decided: painted town, flat cut-outs, real 3D light).
- **Groups who buy** (Running Thoughts): weapons groups want weapons intel, reporters want dirt, hackers want data; Tarkov-trader-like quests later.
- **Nobody is just a target** (GAME_DESIGN pillar 4): guards, clerks and conscripts are people.
- **Multi-floor moves** (Operator clip 7): stairs, the landing above, under the stairs; windows as recon (clip 1).
- **Code that exists:** the town roster of hackable places (office, depot, shop, clinic, police; data/v2/hacking.json), four depot kinds by bench (parcel, bulk, cold, linen; data/v2/depot_runs.json), the person generator, the depot kit, level.gd building from a room/door list, the whole C combat (overview, orders, doctrine, wounds, leave card), coming home.

## 2. Gap questions (asked in chat 2026-11-24; answers go in section 3)
Q1 where targets come from; Q2 which op types first; Q3 how buildings are generated; Q4 outdoor fights now or later; Q5 reasons to hit (rewards); Q6 the enemy that learns; Q7 the easier first mission; Q8 how many targets and how often; Q9 the map now or later; Q10 people who aren't fighters; Q11 planning before going in.

## 3. Answers
(waiting)
