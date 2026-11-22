# The drive (design pass, 2026-11-22)

*The user wants Balatro's and Ball x Pit's pull ("one more go, the numbers keep getting bigger") without their gameplay, spread across everything: benches (weapons, armor, meds), hacking, exploiting people, and a growing army that fights like an auto-battler. Start inside the garage and move out later; the whole game doesn't have to work yet. Nothing here is built. The questions in section 8 are the user's.*

---

## 1. What the "drive" actually is (it isn't the cards)

Pull Balatro and Ball x Pit apart and the hook is six things. None of them needs cards or balls:

1. **One small verb you repeat a lot,** and it feels great every time (a card flip, a ball bounce, a drill biting metal).
2. **Score = base × multipliers,** and the multipliers come from **things you've collected** (jokers). You aren't getting better at the verb so much as building a machine that makes the verb huge.
3. **Discovering synergies:** "wait, if this sits next to that..." That's the "OHHH" moment.
4. **Thresholds that keep climbing,** so the machine always needs to grow.
5. **Juice:** numbers cascading, a screen shake on the big multiplier, a rolling counter.
6. **Three loops nested:** ~10 seconds (the verb), ~10 minutes (a run), ~10 hours (the base). Ball x Pit's base means even a failed run moves you forward ([How to Market a Game](https://howtomarketagame.com/2025/12/01/ball-x-pit-my-game-of-the-year-2025/), [Hooked Gamers](https://hookedgamers.com/pc/ball_x_pit/review/article-2676.html)).

**For us:** the 10-second loop is a hands-on step (drill, file, sew, pick a card, place a soldier). The 10-minute loop is one evening's job or bench session. The 10-hour loop is the garage turning into a movement. **The jokers are everything you own**: tools, rig modules, the people who joined you, and what the other benches made.

## 2. The one rule that ties every bench to every other: everything you make is a joker somewhere else

| You make... | ...and it multiplies |
|---|---|
| A better drill press (weapon bench) | Every weapon craft: ×1.5 quality |
| A sewing machine (armor bench) | Rig crafts, and it unlocks bigger pouch grids |
| Clean bandages (med bench) | Your squad survives longer in fights |
| A keylogger gadget (hacking bench) | Gives the hack deck a card that scores ×2 on passwords |
| Dirt on a clerk (exploit a person) | Gives the market a discount, or a bonus card in the next hack |
| A legend (survived 5 fights) | Lets every recruit in their cell start at +1 star |

That web is the build-crafting. "I want a 5-star rifle, so I need the drill press, so I need money, so I hack the scrap yard's books first." Each night you pick what to grow next, the way Balatro has you pick jokers.

## 3. Benches: hands-on first person, then mastery, then automation

What you described: drill the metal, file it down, add parts you made, and you have an upper receiver. Armor starts out like Tarkov's "IKEA rig": random stuff cut and sewn to hold mags. Meds start as torn shirts sterilised with alcohol, and you work up from there.

**One bench engine, many recipes (data-driven):**
- A recipe is a **list of steps**. Each step is one short physical verb in first person at the bench, with the pixel hands:
  - **drill:** hold the mouse, keep the bit in the line, don't overheat;
  - **file:** drag back and forth until it fits the outline;
  - **cut:** follow a line;
  - **sew:** a rhythm of clicks;
  - **tear;**
  - **pour / soak:** stop at the mark;
  - **fit:** drag a part into place;
  - **test:** one function check.
- **Each step scores** (precision). The craft's **quality** = the steps' scores × **tool multipliers** × material grade. Quality sets the **stars** (1 to 5) and rolls a **perk** ("light", "tough", "+1 mag").
- **Recipes climb in tiers:**
  - Meds: torn-shirt bandage → field dressing → kit → surgery set.
  - Armor: IKEA rig → chest rig → plate carrier.
  - Weapons: a part, then the lower, then the whole gun.
- **Mastery (the Schedule I lesson):** the first time is fun by hand. Once you've crafted a recipe well 3 times, it can be **batched** without playing, at your average quality. Later, people and machines run batches overnight: the "standard issue" for your squads (decided 2026-11-21).
- **Weapon building stays stylised** (CLAUDE.md): real-sounding part names, gamified verbs, never real machining steps.

**Armor and rigs are a grid (Backpack Battles):** a rig is a small grid you lay pouches on. Where things sit matters ("dump pouch beside the mag pouches: faster reloads"). That same grid becomes the soldier's build in a fight. Tarkov's rigs plus Backpack Battles' item adjacency is a real "OHHH" space.

## 4. Fighting: an auto-battler with a commander's hand

You said it like Just King or other auto battlers, with the life Ball x Pit gives. Just King is a roguelite auto-battler where you hire and upgrade a small party around a fragile king, and the run ends if he dies ([Steam](https://store.steampowered.com/app/1059980/), [PC Gamer](https://pcgamer.com/for-dollar3-this-fantasy-autobattler-will-consume-your-entire-week)). Our "king" is **you, early on**: in the first fights, if you go down, it's prison.

- **Before:** pick the squad, check their rigs and gear (the grid), set the **stack order and the breach plan** (from the combat prototype you liked: doctrine as setup).
- **During:** they fight on their own in a small low-poly room, top-down, with the same look. You get **2 or 3 call-ins** per fight (smoke, flashbang, fall back, "push now"). It's watch-and-decide with fewer clicks.
- **The numbers show:** damage pops, a legend's perk firing ("Mira: double tap!"), a medic using *your* bandage (your bench work paying off on screen).
- **After:** the op report, loot, injuries, who levelled up.
- **Routine ops** (send-aways) resolve the same fight off-screen and give you the report (decided 2026-11-21).
- This reuses `tactical/watch/` (room graph, squad brain), with the micro-orders turned into call-ins.

## 5. Hacking: the same shape. Build it, launch it, watch it run

Hacking is the hard one. Here's a suggestion that keeps what you chose (one-use cards from techniques and gadgets, a network per target, the combo) and adds the "life" you liked in Packet Pit:

- **Build:** from your deck, slot cards into a **chain** (a short pipeline on the rig: scan → access → exploit → payload). Order and neighbours give the combos, like a Balatro hand.
- **Launch:** pull SEND. The chain runs as **a live thing moving through the network map**: packets crawling node to node, ICE fighting back, numbers popping. That's the Ball x Pit life.
- **Nudge:** one or two live actions while it runs (reroute, burn a gadget for a spike, a **typed flourish** at a login prompt for a bonus: the typing you loved).
- **Score:** nodes broken = the intel tier. The trace bar decides the **clues** for the hunt (docs/HUNT.md).

**Why:** it gives hacking and fighting the same rhythm (**set up → launch → watch → nudge → score**), so learning one teaches the other. The cards don't change; only "play a hand" becomes "build a chain and watch it go".

## 6. Exploiting a person: a negotiation you play against them

- The proven model is **Griftlands' negotiation**: a card battle where your arguments chip away at the other person's resolve, and they argue back. Also **Phoenix Wright's** "catch the contradiction", and The Red Strings Club's reading of people ([PC Gamer](https://pcgamer.com/what-the-red-strings-club-teaches-us-about-conversation)).
- **For us:**
  - The person has a **guard** (defence) and **tells** you can learn (their weak spots: money, family, pride, fear).
  - Your cards are **angles** from dirt, favours, things you know and charm.
  - The combo is the real-world logic: *rapport → find the weak spot → leverage → the ask.*
  - Push too hard and they **remember you** (the grudges in GAME_DESIGN, and the hunt's witnesses).
- It's the same engine as the hack, with a person as the "network". The inspector's interview (HUNT section 3) is this game in reverse.

## 7. The army grows like Antistasi, with a Ball x Pit base

- **You start alone,** and every early job is you, hands-on.
- **People join** (circle, followers, rescued, rented legends). Each one is a unit with traits and a **rig grid**.
- **The base layer:** your people and machines **work between your evenings** (batches, passive money). That's Ball x Pit's harvest: even a bad night moves you forward.
- **You stay in charge:** you pick targets, design the gear, set the doctrine. Later you watch the big ops and leave the rest to reports.

## 8. Decided (user, 2026-11-22)
- **Benches:** hands-on steps in 3D at the bench, first person with the pixel hands.
- **Mastery:** after 3 good crafts a recipe can be batched at your average quality; hand-made is the way to 5 stars.
- **Rigs are a grid, and the materials set the grid.** What you build a rig from grants or limits it: how many cells, which pouches fit, whether it takes plates and how good. Early rigs are cramped: little room for ammo *and* armor. Tarkov's constraint: you can get great armor early, but then you have little space. By the end you have a great rig that takes great plates with lots of room.
- **Fights:** top-down rooms (reusing the combat prototype), auto-battle with 2 or 3 call-ins.
- **Hacking:** try "build the chain, launch it, watch it run, nudge it" as a toy.

### The questions as asked
1. **Benches:** hands-on steps in 3D at the bench (pixel hands, the drill in the low-poly world, Gunsmith Simulator style), or 2D close-up panels like the solder stub? *Claude's take:* 3D close-up. It's the "first person aspect" you want, and the camera is already there.
2. **Mastery:** after 3 good crafts, can a recipe be batched without playing it? *Claude's take:* yes, at your average quality. Hand-made stays the way to get 5 stars.
3. **Rigs as a grid** (Backpack Battles) that becomes the soldier's fight build? *Claude's take:* yes.
4. **Fights:** top-down rooms in the combat prototype's look, auto with 2 or 3 call-ins? Or a side-on lane like Just King? *Claude's take:* top-down rooms. They reuse what you liked.
5. **Hacking:** try "build the chain, launch it, watch it run, nudge it" in place of playing a hand? *Claude's take:* yes, as a toy first.

## 9. What to build next (inside the garage, bits and pieces)
1. **(BUILT 2026-11-22, see SHELL.md "Build 2") The bench engine** (steps, scoring, stars, tool multipliers, data-driven recipes), with one recipe per bench: torn-shirt bandage (meds), IKEA rig (armor), a receiver part (weapons). Items go into a real **stash** on the shelves, and the stash saves.
2. **The rig grid:** lay pouches on the rig you just sewed.
3. **One auto-battle toy:** your 3-person cell in one room using the gear from 1 and 2.
4. **The hack chain toy** (section 5) and the person negotiation toy (section 6), as design passes first.

Each piece ends playable in the shell. Nothing else in the game has to work yet.

## Sources
- [Ball x Pit: my game of the year 2025 (How to Market a Game)](https://howtomarketagame.com/2025/12/01/ball-x-pit-my-game-of-the-year-2025/)
- [Ball x Pit review (Hooked Gamers)](https://hookedgamers.com/pc/ball_x_pit/review/article-2676.html)
- [Ball x Pit review (Nintendo World Report)](https://nintendoworldreport.com/review/72918)
- [Just King (Steam)](https://store.steampowered.com/app/1059980/)
- [Just King (PC Gamer)](https://pcgamer.com/for-dollar3-this-fantasy-autobattler-will-consume-your-entire-week)
- [Games like Balatro (Summer Engine)](https://www.summerengine.com/blog/games-like-balatro)
- [What The Red Strings Club teaches us about conversation (PC Gamer)](https://pcgamer.com/what-the-red-strings-club-teaches-us-about-conversation)
- [Conversation as gameplay (Emily Short)](https://emshort.blog/2019/01/20/conversation-as-gameplay-talk/)
- Griftlands, Backpack Battles, Schedule I, Gunsmith Simulator, Super Auto Pets: from Claude's own knowledge, not this search.

## 10. First bench playtest (user, 2026-11-22)
- **Verdict:** the tables are exactly what the user wanted; the feel is "pretty darn close for what they are, but still hella rough". This build is the new base of the game (tag `v2-base`).
- **Every step must say plainly "this goes here, then this".** Done the same day: one pink "act here" marker (ring, arrow, label, drag arrow) follows the next target on every verb.
- **Hacking bench:** green highlights on a green board were unreadable; soldering was spam-click until "cold joint". Done: darker board, copper pads, solder is now hold the iron on the lit pad and let go in the green.
- **Weapons:** drilling is good. Next: real tools the way they're really used, in tiers (hand drill, drill press, files, jigs, vise).
- **Rig:** should be cut strips, then an animation bending them, then sewing in the right places, then the pouches (the block placeholder is fine).
- **Meds:** fine, just hard to tell what you're doing (the marker should help; better models next).
- **The three blocks being placed** (the shared fit step) are fine for now.
- **Still to do:** better models for every bench piece and tool; the rig strip/bend/sew flow; tool tiers.
