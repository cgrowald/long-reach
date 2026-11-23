# The economy (design, 2026-11-22)

*User: "Economy right now is super important. You don't get too much of one thing, but it's all there in the game." The early game is hacking, exploiting people, or stealing from your work; then you make things at home. Your day job shapes what you're good at. Materials have rarity, random every game: 2-star cloth might make only one kind of gear, or a worse version (less room, worse ergonomics). When you're good enough you can go and get whatever you want: lockpicking, exploiting your neighbour's job, bribing him. The black market is earned later. Questions for the user are at the end.*

---

## 1. What you trade in
| Resource | What it is | Shown as |
|---|---|---|
| **Money** (cr) | Wages, sold intel and loot, client jobs | A number |
| **Materials** | Raw stuff for the benches, in **families**: cloth, metal, electronics, medical, parts | Units with a **star grade (1-5)** |
| **Supplies** | Ready-to-carry things: clips, mags, shells, flashes, charges, batteries | Counts |
| **Gear** | Made, bought or looted items | Stash items with stars |
| **Intel** | Dirt, plans, names, blueprints, camera access | Stash items |
| **Favours and dirt on people** | What you can make someone do | A small ledger per contact |
| **Heat** | How hard someone is looking at you: work suspicion, Bureau attention, the hunt's clues | Meters |

## 2. Material grades decide what you can make
- **Every material unit has stars (1-5).** A recipe needs a minimum grade, and the grade also sets the multiplier (the "MATERIAL" in STEPS × TOOL × MATERIAL = QUALITY).
- **Low grades limit the outcome, never just the number:**
  - 2-star cloth makes only the market-bag rig, or a chest rig with fewer cells and worse ergonomics;
  - 4-star webbing makes a real chest rig;
  - plate carriers need 4-star cordura.
- **Each family has its own ladder:**
  - **cloth:** rag, canvas, webbing, cordura, aramid;
  - **metal:** scrap, mild steel, tool steel, alloy;
  - **electronics:** salvage boards, chips, modules, military modules;
  - **medical:** rags and vodka, gauze, sterile kits, drugs.

## 3. Where things come from (the taps)
- **Your cover job** (day): a small wage, plus first pick of one material family. Each night you choose how much you **steal from work**: nothing, a little, or a lot. More stolen means more material and better grades, but **work suspicion** rises. Too much means an audit, being fired, or a call to the Bureau.
- **Hacking jobs:** intel to sell; redirect a delivery (materials appear somewhere you can pick them up); empty payroll.
- **People:** exploit or bribe a contact whose job gives what you lack:
  - the neighbour at the depot brings parts;
  - the nurse brings drugs;
  - the cop... (the police station beat).
  Each favour costs dirt, money or trust, and pushing too hard creates a grudge.
- **Going out (when you're good enough):** lockpicking and breaking into places (a hands-on scene, like the benches) to take exactly what you want. Lock tiers gate the good stuff, and pick tiers (bobby pins, a pick set, bump keys, an electric pick) open them.
- **Ops:** loot, if you held the field.
- **The black market (earned):** buy almost anything at a price that rises the more you buy. You unlock it by proving yourself, e.g. by selling enough intel to the fixer or doing a job for lantern's network.

## 4. Where things go (the sinks)
- **Crafting** eats materials.
- **Ops** eat supplies (rounds, meds, flashes), and the dead lose their kit.
- **Tools and bench upgrades** cost money and rare parts.
- **Bribes** (lower heat, buy silence), **rent and safehouses,** and **black market prices.**
- **Your people's upkeep:** food and pay; recruits who aren't paid drift away.

## 5. Your day job (random every game)
| Job | Gives | Costs |
|---|---|---|
| **Hospital** (orderly or nurse) | Medical materials (gauze, antiseptic, drugs), a better med table early, and you can treat your own wounded | Night shifts eat actions; the police bring wounded in and look around |
| **Steel mill** | Metal stock, access to the mill's machines (a drill press early), so better weapons early | Hard shifts: fewer good nights; loud and watched |
| **Textile mill or clothing store** | Cloth grades (canvas, webbing), a sewing machine early, so better rigs early | Low pay |
| *Later options* | Trucker at Pavel's yard (smuggling, vehicles); electrician (electronics); print shop (forgery) | |

The grade your workplace yields is rolled per game: this run the mill turns out 3-star steel; next run it's 2-star. You trade or steal for what your job doesn't give.

## 6. Keeping it scarce ("not too much of one thing")
- **Each tap is small and has a ceiling:** a few units a night, and suspicion grows fast if you push it.
- **Variety comes from mixing taps,** not from farming one.
- **Prices move:** the more you sell of one kind of intel, the less it pays; the more you buy of one thing, the more it costs.
- **The world reacts:** a big theft wave leads to audits at work and checkpoints on the road.

## 7. A night, end to end (the clock decided: nights where only big things cost)
- **Day (automatic):**
  - your cover job pays;
  - you chose this morning how much to steal;
  - suspicion ticks.
- **Evening (free):**
  - the PC, the box, small crafting, the gear cage;
  - talking to contacts by phone.
- **Night (a couple of big actions):**
  - a hacking job;
  - an outing (a break-in, meeting a contact, a delivery pickup);
  - an op;
  - a long craft.
- **Overnight:**
  - the world turns: news, prices, the Bureau's moves, your workshop's batches;
  - the morning card shows what changed.
EOF
echo ok
## 8. Decided (user, 2026-11-22)
- **Day job:** pick one of three random offers each game (with random material grades). You can quit and switch later, at a cost: lose that access, start a new trial period.
- **Material grades:** per source, per game. Each source has its range this run (the mill makes 3-star steel this game; the shop down the road only 1-2 star cloth). You learn your map of who has what, and trade or steal for the rest.
- **Stealing from work:** a morning choice (nothing / a little / a lot) with risk. More means better grades and more stuff, but suspicion climbs: an audit, getting fired, or a Bureau call.
- **The black market:** earned by proving yourself to a fixer (met through Pavel's network or the hidden StateNet page). Trust tiers unlock better stock; burn him and it's gone.
- **Upkeep:** yes, food plus a cut per person per night. Unpaid, their loyalty drops and they may walk or talk.
- **Lockpicking:** hands-on in 3D like the benches: feel each pin (tension, set), against a patrol timer. Better picks make it easier; lock tiers gate the good places.
- **Exploiting a person:** a short talk with angles. Your cards are what you know (dirt, favours, money, charm), played against their guard and weak spots (family, debt, pride, fear). Push too hard and they remember. It ends in a deal ("bring me parts every week", "give me the keys").
- **Money pace:** tight. Early nights give enough for one meaningful purchase; you're always choosing between a better rig, a pick set, and paying your people.
- **Also from the user:** the garage first (honing it, plus the face-lift) before more combat; the combat face-lift list is in COMBAT_SLICE section 11; the police-station robbery is a job chain (steal a cop's keys, rob the station) that gets you your first real guns.

## 9. Build order Claude suggests
1. **The economy core:**
   - material families with grades;
   - the cover-job pick at a new game;
   - the morning card's steal choice and work suspicion;
   - wages, upkeep and money;
   - recipes gated by material grade (the rig cell count and ergonomics come from the cloth grade).
2. **The easy first mission** (the bar or a small roadblock), so new teams can be tested without the depot.
3. **Lockpicking** (the first going-out scene) and **exploiting a person** (the neighbour bringing parts).
4. **The fixer and the black market.**
5. **The garage face-lift** (POLISH.md, when the user says go) and the combat face-lift.
