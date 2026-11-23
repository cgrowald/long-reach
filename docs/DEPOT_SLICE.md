# The depot slice: the first test of the whole loop (planned 2026-11-23)

The idea came from GPT's independent review: make the existing depot raid the place where the garage, the PC, the bench and the van first feel like one game. The user's answers to the review are below, and the build waits on the gap questions in section 3.

The test, from the review: after one evening, a player should be able to answer four questions.
- What did I make?
- Who used it?
- What did I learn on the PC that changed the raid?
- What will I do tomorrow because of Krall?

---

## 1. Decided (user, 2026-11-23)

**Production: mastery, then lots.**
- You make a new item by hand several times. Mastering it unlocks making it in a LOT.
- Upgrades raise how many a lot gives.
- New items always need several handmade crafts before lots unlock, so the game doesn't run out of hands-on work.

**The army grows slowly from your own people.**
- Leaders come from your early crew: the ones who survive become the leaders.
- Named leaders run district companies (rundown Q2 d).
- **You always keep your own squad**, the one you command through FIELD LINK. Otherwise you'd run out of things to do.

**Upkeep climbs the chain of command.** Each level is paid for in units of the level below:

| Your force | Upkeep paid per |
|---|---|
| up to a squad | person |
| a platoon | squad |
| a company | platoon |
| a battalion | company |

Lot upgrades are what make the bigger levels affordable.

**The depot brings back several things.**
- **Guard weapons:** poor pistols and SMGs, no plate armour.
- **A random bench upgrade, depending on the kind of depot.** There is one depot variant per bench (electronics, guns, cloth, medical). This feeds the roguelite structure.
- **A captured person**, who leads into a new interrogation section.
- **A place inside where your people get you in to hack** (an on-site hack in the middle of the op).
- **No vehicles from depots.** Vehicles come from something else, and they are what let you hit targets outside your town.

**Krall escalates in steps, from far away to close.**
1. Someone you know is questioned (fairly random at first).
2. Your delivery is intercepted.
3. The garage is searched.

The other ideas (a work audit, a checkpoint) all go in too. At first the consequences are far enough away that you don't care, but they get closer and closer to your op.

**EYES grows through upgrades. You have to hack to get it.**
- At first it is just another view into the mission.
- The base version: you see enemies your people can't see, so you can warn them and get them ready. Otherwise they're in trouble if there are too many.
- Upgrades add the rest: the objective's location, patrol timing, the alarm box, a camera loop that blinds the guards.
- The exact numbers are a variable to tune.

**Coming later (user):** GPT's inspiration research arrives with the big face-lift, done in pieces. It covers every item in the economy and every piece of gameplay as it would look.

---

## 2. What the slice builds (draft order)

1. **The depot plan file.**
   - GRAB on a depot gives a plan file.
   - Reading it draws the layout and the guard rotation on the ops board, and it stays drawn even if you sell or post the file.
2. **EYES, base level.** Linked cameras show enemies your squad can't see, marked on the board and in one camera tile, so you can shout a warning before they walk in.
3. **Depot variants.** Four kinds of depot (electronics, guns, cloth, medical), each with its own pool of bench-upgrade rewards and its own loot crates.
4. **The on-site hack in the middle of the op.** Your squad gets you to the dispatch terminal, and you run TUNE + INJECT while they hold the room.
5. **Loot.** Guard pistols and SMGs come home graded and worn; the bench upgrade is installed in 3D.
6. **The prisoner and the interrogation.** The format waits on G1 below.
7. **Items used by name.** "Ada used your field dressing (★★★, made day 2)."
8. **Injuries.** A recovery date per person, shortened by your dressings.
9. **Krall's ladder,** steps 1 to 3, each one announced before it lands.
10. **Mastery leads to lots.** The count to unlock and the lot sizes per upgrade come from G5.
11. **The echelon upkeep** (groundwork only; it pays off later).
12. **One named recruit from Nod**, tied to the depot.

---

## 3. Gaps to decide before building (questions with options)

**G1. The interrogation: what is it?**
- a) Papers, Please style: their story against your intel files. Catch the lies by matching names, times and places.
- b) A dialogue with a pressure meter: approaches (reason, threaten, bargain, kindness), with each person weak to one or two of them.
- c) What you hold over them: use the dirt you hacked on them or their family.
- d) An outcome choice at the end: turn them into an informant, trade them back, let them go (heat), keep them (upkeep and risk), or recruit them.
- e) A card or tile puzzle (like the hack) where questions open up facts.
- f) a+c+d: cross-check what they say, use your leverage, then choose what to do with them.
- **Tone limit:** pressure, bluffing and bargaining only, with no torture shown? Or harsher with a moral cost (people leave you, your followers drop)? This needs your line.

**G2. "Your people get you in to hack": where are you?**
- a) You are in the squad: a fifth figure in the FIELD LINK feeds, escorted, and you carry the drop stick.
- b) You stay in the van. The squad plugs in your stick and you hack remotely, with the clock running while they hold.
- c) Your hacker (a person you recruit, like kettle) goes in, and you hack through their stick.
- d) It changes with the depot: some need you there.

**G3. The depot variants: how different?**
- a) The same building, with props and loot changed per kind.
- b) Four hand-made layouts, one per kind.
- c) Generated from parts (a yard, an office, a warehouse floor, a loading bay).
- d) Hand-made at first, generated later.

**G4. What does "roguelite" mean here?**
- a) Each depot raid offers 3 random upgrade picks, and you choose one (Hades or Balatro style).
- b) Random rewards per raid with no choice; the depot kind sets the pool.
- c) Depots refresh: hit one and it comes back stronger (more guards, better loot) a week later.
- d) A whole campaign run is the roguelite: lose and start a new country, keeping a few unlocks.
- e) a+c.

**G5. Mastery and lot numbers.**
- How many good handmade crafts to unlock a lot: 3 for tier 1, 5 for tier 2, 8 for tier 3? Or by stars (three 3★ crafts)?
- Lot sizes: 5 at first, then 10, 25, 50 with upgrades? Or set per item (5 rifles, 20 bandages)?
- Lot quality: your average mastered quality, minus a little? Or one quick hands-on check per lot?

**G6. How a survivor becomes a leader.**
- a) Automatically after N ops survived.
- b) You promote them (a choice; they leave your squad to lead).
- c) They ask for it (a story moment) when ready.
- d) Promoting someone means they leave your squad, so you train a replacement. Is that a cost you want?

**G7. Krall's ladder: the timing.**
- a) Days: step 1 after the first clue, step 2 about 3 days later, step 3 about 3 more. Each clue speeds it up.
- b) A clock on the corkboard: "Krall's next move: in 4 nights." Clean ops slow it, and WIPE pushes it back.
- c) It follows your op trail: each op you run leaves evidence that moves him a step.
- d) b+c.
- And who gets questioned at step 1: a coworker, a neighbour, one of your crew's family, the fixer?

**G8. Warning your people with EYES.**
- a) A shout on the wheel ("Contact behind the door!"), and they get ready: weapons up and a better first shot.
- b) Click the enemy on the board to tag it, and everyone knows where it is.
- c) Automatic: anything EYES sees, your team knows.
- d) a+b.

**G9. Guard loot.**
- a) One weapon per guard killed, worn (condition) and graded 1-2★.
- b) A loot crate per room, rolled.
- c) Only what you choose to carry home (weight limit on your squad).

**G10. Injuries.**
- a) Light (1-2 days) and heavy (5-7 days), with dressings cutting the time.
- b) Plus a scar on the face that stays.
- c) Plus a lasting trait sometimes (a limp, a shaky hand).

**G11. The depot recruit.**
- a) An ex-depot worker who answers on Nod: they know the layout (a free plan) and want revenge on the foreman.
- b) The captured person turned during the interrogation.
- c) Both, at different depots.

**G12. Order.** Build all 12 steps as one milestone (big, a long silent run), or split it:
- slice A (plan file, EYES, items by name, injuries, loot);
- slice B (variants, the on-site hack, upgrades);
- slice C (prisoner and interrogation, Krall, the recruit);
- slice D (lots and echelons)?

## 4. Answers (user, 2026-11-23)
- **G1, the interrogation:** you bring the person back to the garage. Pressure, bluffing, bargaining and leverage, as listed. It ends in one of three outcomes, each with its own pluses and minuses:
  - let them go;
  - kill them;
  - recruit them.
- **G2, the hack in the op:** you are never there in combat. It's one of your fighters with a USB or hacking device you handed them: "stick it in any computer you see".
- **G4, roguelite:** the user asked for better questions (asked in chat).
- **G5, the numbers:** start at 5 handmade crafts to master an item, then see if that's too easy. Lot sizes depend on the economy we build.
- **G12, the order:** one big build. The depot is the proof that the game is playable.
- **Rule:** questions always go in the chat, not only in docs.

## 5. Answers, round 2 (user, 2026-11-23)

**R1. Roguelite = every game feels new.**
- Everything is built modular.
- Only unlocks earned after a campaign persist: some cosmetic, some new starting classes.
- The whole in-game economy and every upgrade are earned again in each run.
- There is one depot per city, and other hits are generated.
- Every depot raid is different: guards, stores (meds, materials, weapons, gear and armour), rooms. This needs a **person generator**.

**R2. Three locked doors in the most secure section.**
- You only have time to open one. Unlocks may allow more later.
- Each door is random, but enough hacking beforehand can tell you which door you want.
- Your team escorts the loot out.
- A **timer for backup** runs, and upgrades can push it back.

**R3. After a raid the depot gets too hard to hit.**
- It has a reset timer.
- Next time they have covered the exploits you used: the enemy learns from how you win.
- You capture it for good when you capture the town.
- No grinding it for gear: you must feel you can't risk being in the same place twice.

**R4. Upgrades with quirks (c).**
- You can learn to use a quirk right.
- **Blueprints for sure.**
- Bench upgrades are found in depots.
- The feel to aim for: Dungeon Crawler Carl's system AI. It sort of gives you what you need, with lots of junk in between, so a raid can end with "OH YES WE GOT SOMETHING GOOD THIS TIME".

**R5. Upgrades combine across benches (b).**

**I1/I2. The interrogation outcomes carry risk.**
- **Kill:** your people may not like it.
- **Let go:** raises the Bureau's hunt on you.
- **Recruit:** a risk too: recruits are more likely to dislike your decisions.

**I3. A death is off-screen** (a ledger line). "We don't need to glorify killing people that can't fight back."

**S1. The hack in the op.**
- By hand it is risky: the longer you take, the sooner reinforcements come.
- Auto-hackers of varying quality get some, half or all of it.

**S2. The fighter with the stick.**
- They need a minimum tech background. Almost everyone has some; higher is faster and lets them pick better devices.
- The device sits in their inventory.
- In the op: "Hey boss, I see a PC to exploit, want me to hit it?" Yes or no. On yes you tell the squad to hunker down.
- **You can fight your way out against reinforcements, but it needs meds, good guns, good people and good gear.**

**G3. One hand-made layout now.** Later the building is generated, a new one EVERY time.

**G6. Leaders are a mix.**
- People are only considered after a certain number of ops.
- They can ask for it (noted for later, not built now).
- You can only assign them when your organisation can support a new team, squad or platoon. They can be ready while you aren't.

**G7. Krall's ladder: a clock you can push back (b), plus each op moves it (c).**
- Anyone you've been near can be questioned: a shop worker, a coworker, a neighbour, family, one of your soldiers.
- Some ops push him back (destroying evidence).

**G8. Warnings: tag and shout (a + b).**
- A ping, as in Battlefield or Wardogs, only ALERTS them.
- The shout wheel makes them TARGET it.
- The squad AI has a priority list and ALWAYS values its own lives first, even to the point of disobeying you.

**G9. Loot is what they can carry.**
- Each fighter has a Tarkov-style grid, so they only take what fits.
- They can swap a bad weapon for a guard's nicer SMG, but with little ammo: risky if a guard was missed.
- Guards are always badly equipped (for balance). Guards have infinite ammo but must reload. You never get access to what they have; a guard's kit is not like ours, or it could be exploited.

**G10. Injuries: all three (a, b, c), Tarkov-like.**
- Better gear can fully repair a limb.
- Bandages work as in most games: they heal health during the raid, and only take a day or so off the recovery.
- The op report shows missing health, turned into injury days.
- A deeper health system can come later.

**G11. Both (c).**
- Most buildings have holding cells: the regime jails people for the smallest rule.
- Or an ex-worker who heard from a friend ("hey, we're hitting the old warehouse").

## 6. Answers, round 3: the vault (user, 2026-11-23)

**V1. The vault doors open by a hack.**
- Cables visibly connect all three doors to something on the network.
- The USB carrier plugs into the computer that controls them. The system allows ONE door before it locks out, so you can't hoard.
- Later in the game: explosives blueprints, or found explosives, to open all three.
- One day you might find the man who made the doors, who teaches you to pick them for a price (could be its own hit). → Parking lot.

**V2. The backup timer starts once you go loud.** Two levels, like Payday, or Ghost of Tsushima where a guard runs for the radio or the alarm:
1. A guard goes for the alarm, and you can stop them. Stopping them kills that alarm.
2. From the first gunshot, neighbours eventually call it in no matter what. So you can never loot the whole place.

**V3. The quick van hack is a small PATCHBAY (just the code chain), with the backup timer as its trace.**

**V4. All of the above.**
- The vault doors push you forward, like Dungeon Crawler Carl's system AI.
- They are NOT generated to give you what you need: there's a real chance it isn't great, but you still try because it can be amazing.
- The vault isn't the main reason for the hit. It sits in the room with the main supplies you came for (meds, guns, materials).
