# Market research: one-room and terminal games, and what they mean for us

*2026-11-21. Written because the user felt we were building too many parts without a loop ("it needs to play like Iron Nest, or other games with terminals as a main source of gameplay... the workbenches supply the troops you need to overthrow the government"). Read this, then we decide the loop, then we build only that.*

---

## 1. The short version

Every game below that works has **one small room, a few verbs you get good at, and a clear tally at the end of each shift**. Every one that gets criticised fails in the same place: **the verb stops changing**, or **the player can't see why they lost**.

We have the opposite problem right now: lots of verbs (Market, Workshop, Nod, Map, Probe, combat), but no shift, no tally, and no reason to do any of them tonight.

Your sentence already contains the fix: **you are the supplier.** The troops are out there; you're in the garage. They ask for things, you find, make and send those things, and you watch what they do with them. That's a loop we can build and test in a week.

---

## 2. The games

### Iron Nest: Heavy Turret Simulator (2026)
- **What it is:** you are a crew inside a heavy turret / walking bunker. You never leave. You measure bearing, work out elevation, choose powder charges and load by hand, then watch the shell land through a periscope.
- **Why it works:** the procedure *is* the game. Reviewers call it "organization as a deadly skill". Manually loading gives every shot weight, most of all late on, when time is short.
- **The problem:** repetition. The core loop (enter data, aim, fire, repeat) barely changes all campaign. Some reviewers say it gets monotonous; others say it doesn't, *because the missions keep changing the conditions* and push you out of your comfort zone. No mid-mission save at launch was also a complaint.
- **For us:** one room, physical, hands-on procedures, and you see the result through a camera. Variety comes from **changing conditions** (the regime's rule of the day, a rushed order, a broken tool), not from adding systems. This is the strongest model for our garage.

### Papers, Please (2013)
- **What it is:** one desk, one verb (inspect papers), one shift a day.
- **Why it works:**
  - **A new rule every day** raises the pressure and steers the story without new mechanics. Lucas Pope said this bureaucratic structure made it easy to keep adding rules.
  - **The end-of-day ledger:** pay depends on how many people you processed correctly. Then rent, food, heat and medicine for your family come out of it. You see exactly what you can't afford.
  - **The moral squeeze:** following the rules feeds your family; helping people costs you.
- **The problem:** it's finite and scripted. Once you've seen the endings, you're done.
- **For us:** we already have the rule-of-the-day card. What's missing is **the ledger**: the nightly tally of what came in, what's owed and who goes without. That's our pressure, and it's cheap to build.

### Welcome to the Game I and II
- **What it is:** a fake desktop and deep-web browsing, while someone may be coming to your room.
- **Why it works:** the terminal is boring on purpose. The dread comes from the room around it: noises, the door, the clock.
- **The problems:** players say it's unintuitive without a guide, and deaths feel like dice ("skill has marginal impact... largely RNG"). Bugs.
- **For us:**
  - The garage around the laptop is where tension comes from (the Bureau van outside, footsteps, your kid at the door).
  - **Every threat must be readable and warned.** Never kill the player with an invisible roll. We decided this for raids already (warning signs, scramble); it must hold everywhere.

### Hacknet (2015) and Uplink (2001)
- **What they are:** the classic hacking games. You type commands, crack servers, take contracts.
- **The problem, which both have:** hacking gets rote. One reviewer said only one late-game Hacknet hack differed from the hundred before it. Uplink's generated missions "don't offer a lot of variety", and the back doors are always basically the same.
- **What Uplink did better:** contracts pay money, money buys hardware upgrades, and upgrades open harder contracts. Hacknet's contracts only paid reputation, so the loop felt flat.
- **For us:**
  - **Hacking can't carry the game alone.** It has to *feed* something else (orders, the troops, the benches).
  - Generated hacks need real differences (we have patterns and conditions in the lab engine; they must vary).
  - Pay in things that change your options, not just points.

### Orwell (2016) and Beholder (2016)
- **What they are:** surveillance desktops. Orwell: search websites and chats for the state. Beholder: landlord who spies on tenants for the regime.
- **The problems:**
  - Orwell "lives or dies on the strength of its plot", since the core activity is searching websites.
  - Beholder: the loop is install a camera, talk, file a report, and spying rarely leads to surprises. A reviewer said there's a ceiling on how good a game with that loop can be. It was best when desperation set in.
- **For us:** this is the trap our open PC is closest to. Reading and searching is not a game on its own. **Information must turn into surprises and choices**: dirt that changes what a person will do for you, a lead that opens a target nobody expected. Desperation (the ledger) makes it good.

### Duskers (2016)
- **What it is:** you command drones through derelict ships **only through a command line and sensor maps**. You never see the drones directly. Typing `navigate 1 r3` sends drone 1 to room 3; you can chain commands and make aliases.
- **Why it works:** reviewers say the console makes you feel powerful when the drones obey, and terrified when the sensors show something you can't see. Resources degrade over a run.
- **For us:** this is the missing link between the laptop and the war. **Your people fight out there; you command and watch them from the laptop**, through cameras, radio and short typed or clicked orders. It's the same idea as our watch-and-decide combat, but it fits the one-room game: you never have to leave the garage to run an op.

### Schedule I (2025)
- **What it is:** make product, sell it, reinvest, expand. Crafting is a set of small hands-on minigames.
- **Why it works:** a very readable supply/demand loop and a constant sense of progress. PC Gamer: it works "because it knows crafting sucks unless you turn everything into a fun minigame".
- **The problems:** a mid-to-late grind (the same deliveries over and over), and automation that's tedious and poorly explained.
- **For us:**
  - Benches as minigames, yes.
  - **Plan the hand-off from day one:** what you make by hand early, workers make later, and your job moves up a level (from making to supplying to commanding). This is your "Sinclair" late game, and it's the cure for the grind.

### Balatro (2024)
- **What it is:** a few minutes per round. Play a hand, beat a target score (the blind), shop, repeat. Boss blinds change the rules.
- **Why it works:** the number you must beat is always on screen, rounds are short, and every shop is a small build decision that snowballs.
- **For us:** a short cycle with a visible target. **The night is the hand, the week is the blind**, and the regime's rule is the boss.

### Antistasi (Arma 3 mod)
- **What it is:** our groundwork. Start from nothing, steal and build gear, grow into an army while the regime escalates.
- **The problems:** I found little written criticism. Players complain the regime's counter-attacks can feel one-sided ("Antistasi is playing us"). From what's commonly said about it: a slow early game, and long sessions where little happens.
- **For us:**
  - Keep the arc and the escalating regime.
  - Compress the slow start into short shifts with something due.
  - Make counter-attacks readable (warnings, a meter you can see).

---

## 3. Patterns

| What works | Where we see it | Do we have it? |
|---|---|---|
| One room, hands-on procedures you get good at | Iron Nest, Papers Please, Duskers | Half: the garage exists, the benches are instant |
| A daily rule that changes the conditions | Papers Please, Iron Nest missions, Balatro bosses | Yes (the morning card), but it changes nothing yet |
| **An end-of-shift tally with something owed** | Papers Please, Balatro | **No** |
| Remote command through a screen | Duskers | Prototype only (combat), not connected to the laptop |
| Make → supply → reinvest, then automate | Schedule I, Uplink | Make and buy exist; nothing consumes what you make |
| Readable threat with warnings | (WTTG fails here) | Heat exists; it does nothing |

| What fails | Where | Our risk |
|---|---|---|
| The verb never changes | Iron Nest (for some), Hacknet, Uplink, Beholder | High if hacking or crafting stays one procedure |
| Reading websites isn't a game | Orwell, Beholder | **High: this is the open PC today** |
| Late grind, unclear automation | Schedule I | Later, if benches never hand off |
| Deaths feel random | Welcome to the Game | Medium (raids, arrests) |
| Too many systems before one is fun | (us) | **Now** |

---

## 4. The loop this points to: "the supply room"

> **Your people ask for things → you find and make them in the garage → you send them out → you watch the op through the laptop → what comes back feeds the next, bigger order.**

**One night (the shift):**
1. **Morning card:** today's rule (a condition, like "drills now reported", "power cuts after 22:00") and what's due this week.
2. **Orders come in** on the laptop from your people: "Need 2 radios and a badge for the depot on Friday." Early on the "people" are just you and one or two friends; later, cells.
3. **Source the parts:** the Market (legal and traced, or grey and hot), hacking (to get badges, codes, schedules), or loot from earlier ops.
4. **Make it at a bench:** a short hands-on minigame. Good work means better gear.
5. **Send it:** a dead drop or a hand-off. Risky, so heat.
6. **Watch the op** on the laptop when it runs: camera and radio, a few calls (Duskers + watch-and-decide). Or skip it and read the report.
7. **Ledger at bedtime:** what came back (loot, money, recruits, territory), what heat rose, what's still owed, who got hurt.

**One week (the blind):** a target the movement needs to hit by Sunday (an op that needs specific gear), plus rent and family needs. Miss it and something bad happens: the op fails, a friend is taken, the cell loses faith. The rule of the week is the boss.

**The arc:**
- Early: you make everything by hand and hack your own parts.
- Middle: workers run benches, and you choose what gets made and where it goes.
- Late: you're Sinclair, keeping an army fed and armed through supply lines, watching the war on screens.

The same loop, with your hands further from the work each time.

**What happens to what's already built:**
- **Market:** the parts source, as is.
- **Workshop:** becomes the order board and the benches.
- **Probe and the labs:** the hacking verb that gets parts, codes and intel for orders.
- **The combat prototype:** the "watch the op" step, viewed through the laptop.
- **Messages:** where orders and family needs arrive.
- **Nod:** recruitment and sympathy. Later, not in the first loop.
- **The Map:** where ops happen. Later, not in the first loop.

**What the first build would be (only this):** one week, three orders, one bench minigame (assembling a device), one hack that gets a part, one op you watch, a ledger each night and a blind on Sunday. Placeholder everything else.

---

## 5. Questions for you after reading

1. **Does "you are the supplier, the troops are out there" feel right as the core**, or do you want the player to go on ops in person early (the first-person scenes)?
2. **Who sends the orders in week 1**, before you have a movement? (My idea: Viktor and Hana, the inner circle, and the first op is about Pavel.)
3. **What should miss the weekly blind cost?** A failed op, a captured friend, lost trust, money, or a mix?
4. **Which bench minigame first:** electronics (assemble and solder a device) or gunsmith (finish a receiver)?
5. **Is there a game you love that's missing from this list?** (Not For Broadcast, Do Not Feed the Monkeys, This War of Mine, Frostpunk, Bitburner and Grey Hack are candidates if you know any of them.)

---

## Sources
- Iron Nest: [PCGamesN review](https://www.pcgamesn.com/iron-nest-heavy-turret-simulator/review), [ixbt review](https://ixbt.games/en/reviews/2026/08/19/eto-ne-voennoe-prestuplenie-esli-vy-umeete-dumat-obzor-simuliatora-artillerista-iron-nest.html), [GameBrief](https://www.gamebrief.net/blog/iron-nest-heavy-turret-simulator-review-2026), [OpenCritic](https://opencritic.com/game/21129/iron-nest-heavy-turret-simulator), [Steam review summary](https://vaporlens.app/app/2950790/iron_nest_heavy_turret_simulator)
- Papers, Please: [Game Developer: designing the bleak genius](https://www.gamedeveloper.com/design/designing-the-bleak-genius-of-i-papers-please-i-), [Game Informer: 10 years later](https://www.gameinformer.com/2024/01/02/papers-please-10-years-later), [NPR](https://www.npr.org/sections/alltechconsidered/2013/11/10/244413539/papers-please-puts-your-loyalty-sympathy-to-the-test)
- Welcome to the Game II: [Steam](https://store.steampowered.com/app/720250/Welcome_to_the_Game_II), [GameBrain summary](https://gamebrain.co/game/welcome-to-the-game-2), [Fandom wiki](https://welcometothegame.fandom.com/wiki/Welcome_to_the_Game_II?oldid=4234)
- Hacknet / Uplink: [Scientific Gamer on Hacknet](https://scientificgamer.com/thoughts-hacknet/), [PopMatters on Uplink](https://www.popmatters.com/uplink-hacker-elite-2496228540.html), [Pocket Gamer](https://www.pocketgamer.com/articles/042042/uplink/), [GameSpot](https://www.gamespot.com/reviews/uplink-review/1900-2835507/)
- Orwell: [PC Gamer](https://www.pcgamer.com/orwell-review), [GameSpot](https://gamespot.com/reviews/orwell-review/1900-6416580/), [Game Informer](https://www.gameinformer.com/games/orwell/b/pc/archive/2016/12/16/spy-and-click.aspx)
- Beholder: [GameSpot](https://www.gamespot.com/reviews/beholder-review/1900-6416610/), [Nintendo World Report](https://www.nintendoworldreport.com/review/49261), [Metacritic](https://www.metacritic.com/game/beholder/)
- Duskers: [PC Gamer](https://pcgamer.com/duskers-review), [GameSpot](https://gamespot.com/reviews/duskers-review/1900-6416465/), [GamingOnLinux](https://gamingonlinux.com/2016/05/duskers-leaves-early-access-heres-a-review)
- Schedule I: [PC Gamer on its minigames](https://pcgamer.com/games/sim/schedule-1-is-great-because-it-knows-crafting-sucks-unless-you-turn-everything-into-a-fun-minigame), [OpenCritic](https://opencritic.com/game/19422/schedule-i/reviews), [Steam review summary](https://vaporlens.app/app/3164500/schedule_i)
- Antistasi: [Steam Workshop discussions](https://steamcommunity.com/sharedfiles/filedetails/discussions/2867537125)
- Balatro: from general knowledge, no source fetched.
