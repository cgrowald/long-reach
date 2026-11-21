# The open PC, the market, benches, heat and the economy (design pass, 2026-11-20)

*The user's verdict on the PC intro: "way too scripted, not like a freely open PC". This doc turns the laptop into a systemic sandbox, adds the market, benches, heat and the economy, and lists the gaps that still don't mesh. Everything gameplay-real stays gamified: inspired by real kit, never real instructions.*

---

## 1. The OS: a drab state Linux

**Look and voice.** A state-issued Linux-like OS: terminals, package names, man pages, all in drab bureaucratic placeholder language.
- The file manager is **Files (Approved)**.
- The browser's home page is **PORTAL.GOV // CITIZEN SERVICES // PAGE 1 OF 1**.
- Error messages read like forms: *"ERR 0x0 - REQUEST NOT APPROVED. REASON: NOT APPROVED."*
- Package installs: `sudo citizen-get install ...` asks for your citizen number.
- A plain grey-beige palette with one state accent colour. Things feel cheap, slow and half-finished **on purpose**, which turns "unfinished game" into the joke.

**Programs per thing you want to do (no story driving it):**

| Program | What it's for |
|---|---|
| **Probe** | Hacking labs on targets you've found |
| **Market** | Buying parts, tools, kits, war materials. Legal shops on NetState, grey sellers on forums, the dark market later |
| **Nod** (state social media) | Post dirt and leaks, gain followers. The Bureau watches it |
| **Messages** | Your contacts. No scripted story: conversations come from systems (a contact offers a job, asks for money, warns you, vouches for someone) |
| **Map** | Your town: POIs, targets, people you're tracking |
| **Files** | Loot, documents, photos |
| **Darknet** (unlocked by joining an inner circle) | Data on people: addresses, routines, debts, dirt. Your targets come from here |
| **Workshop** | Queue and track bench jobs; lists what each station needs |

**Generated, themed internet:**
- **Page templates** (state news, shops, forums, citizen services, company sites, personal blogs), filled with generated people, businesses and events from the current run.
- **Search** returns generated results. Every run's internet is different.
- **Your own text** goes into the templates (writing guide); systems fill the slots.

**No story set pieces:**
- Messages are systemic.
- Big moments are short **clips or cards**: meeting the inner circle in a back room, a handoff of a USB stick, gaining a title ("Member of the Lantern Circle").
- The opening stories (Pavel) stay, but as **goals and events triggered by systems**, not scripted days.

---

## 2. The market and the gadget tree (inspired by real kit, gamified)

Everything is bought as **parts** and **kits** on the Market, or looted. Buying the kit for a station is how you "open" that station.

### Hacking tools (the default lean)
| Tool (in-game) | Inspired by | What it unlocks in the world |
|---|---|---|
| **Data siphon** (USB) | Keystroke-injection and data-grab USBs | Plug into any PC you can touch for 10 seconds: pull everything (big loot from offices, a clerk's desk) |
| **Rogue hotspot** | Rogue Wi-Fi access points | Sit near a cafe or office: catch logins and devices that connect |
| **Pocket multitool** | Multi-radio hacker gadgets | Open simple gates, garage doors, read cheap access badges, replay remotes |
| **Badge cloner** | RFID/NFC cloners | Copy a guard's or clerk's badge when you get close (on the bus, in a queue) |
| **NFC skimmer** | Contactless card skimmers | Skim payment cards and phones in crowds: money and identities |
| **Keypad reader** | Thermal-camera code tricks | Read a door keypad's code after someone uses it |
| **Car relay** | Keyless-entry relay kits | Unlock and start a target's car (follow them, plant a bug or tracker, steal it) |
| **Camera blinder** | IR LEDs, camera loopers | Make a camera see nothing or yesterday |
| **Radio scanner** | Software-defined radio | Hear police dispatch: early warning of raids and patrols |
| **Fake cell tower** | IMSI catchers | Late game: track phones and read texts in an area |
| **Jammer** | Signal jammers | Kill radios and phones in a building during an op (yours too) |

**Physical entry** (overlaps with the hacking table): lockpick set, bump keys, under-door tool, bolt cutters.

**The combo you described:** your target walks home. On the bus you clone his badge (badge cloner). At his door you read the keypad code (keypad reader). His car you unlock with the car relay and bug it (espionage table). Each tool is one move; together they're a heist.

### Gunsmith (late early-game, the road to the army)
Starts with buying basic tools, then grows:
- **Tools:** drill, hand files, vise, clamps, then a drill press, then a small lathe, then a CNC mill or 3D printer much later.
- **Jigs and blanks:** partly finished parts bought online (grey market), finished on the bench.
- **Reloading press:** ammunition from components (rhythm minigame).
- **Upper and lower receivers, barrels, triggers:** made from refinery metal, bought, or looted.
- **Maintenance:** cleaning and repair keep looted guns working.

All stylized steps, never real procedures.

### Espionage table (its own table)
- **Bugs and hidden cameras:** build, then plant during visits or break-ins.
- **GPS trackers** for cars.
- **Burner phones:** cheap comms that expire.
- **Forgery:** ID badges, letters, permits (a Papers, Please game in reverse).
- **Disguises:** uniforms, hi-vis vests, a clipboard.
- **Dead-drop kits.**

---

## 3. Benches: all there from the start, you buy the kits

- **Every station is in the garage from day one, labelled and empty:** HACKING, GUNSMITH, ESPIONAGE, (later) MEDICAL, PRINTING.
- **Buy the kit** on the Market to open a station, and parts to make things. Better tools improve the station.
- **Each station has one core hands-on minigame,** simple and fun (section 5). Teach a recruit and it runs on its own later.
- **Workshop app** on the laptop: what each station can make, what parts are missing (one click buys them on the Market).

---

## 4. Heat: the Bureau (this world's secret police)

- **Name:** placeholder "**the Bureau**" (Bureau of Civic Order).
- **Heat comes from** posting dirt on Nod, buying grey or illegal gear, hacks that leave logs, getting seen in person.
- **Levels:**
  1. **Noticed:** a polite automated warning in your inbox.
  2. **Warning:** a letter; your posts get throttled.
  3. **Visit:** an officer at the door; you have seconds to hide things (the room event).
  4. **Search:** they **seize illegal items** they find. Hidden caches and stations disguised as hobbies protect you.
  5. **Raid:** everything at home is taken. You may have to start from scratch somewhere else.
  6. **Arrest:** prison.
- **High profile:** once you're known, darknet and posting must happen **in person or from public machines** (coffee shops, computer lounges, burner laptops). At home is too dangerous.
- **Prison:** escape is possible but hard. Most players will **fast-forward the sentence** while the world moves on (your cells may break up, your family struggles).
- **Egregious crimes end the game:** killing civilians on camera, a massacre.

---

## 5. Bench minigames: simplified and fun

| Station | Core minigame | Like |
|---|---|---|
| **Hacking** | **Assemble and solder:** place components on a board (drag into outlines), then quick solder joints (click when the iron's glow hits the sweet spot), then flash the firmware (a short pattern of keys) | PC Building Simulator, ReStroy |
| **Gunsmith** | **Fit and finish:** drill to a depth line, file until the part slides in, assemble in order, function check | Gunsmith Simulator, House Flipper |
| **Reloading** (part of gunsmith) | **Rhythm press:** load, press, eject in a beat. Speed up as you get better | Rhythm games |
| **Espionage: forgery** | **Copy the original:** match fonts, stamps and photo placement against a real one; mistakes get noticed | Papers, Please in reverse |
| **Espionage: bugs** | **Hide it well:** pick a spot in a room, small hidden-object-style placement | Hitman planting, hidden-object games |
| **Lockpicking** (in the world) | **Pins:** feel each pin, set it, don't overset | Thief Simulator, Skyrim |

**Schedule I's lesson:** the first time is hands-on and fun, the 20th time you want it automated. Mastery cuts minigame time; recruits take it over completely.

---

## 6. The economy: keep it to three resources

| Resource | What | Where it comes from | What it's for |
|---|---|---|---|
| **Money** (cash + crypto) | The universal | The cover job, selling loot, skimming, fronts, sponsors | Buying everything on the Market, bribes, upkeep, training |
| **Parts** (items, not a currency) | Boards, metal stock, chemicals, springs, components; **rare parts** (high-grade metal, special chips) | Bought, looted from raids (gun store, refinery, depot), salvaged | Crafting at stations |
| **Intel loot** (items with stars) | Data, dirt, leaks, credentials | Labs, break-ins, skims, darknet | **Post** it (followers + heat), **sell** it (money), **use** it (targets, leverage), **spend** big ones on path support for your troops |

**Upgrading soldiers** (keep it sane):
- **Gear** comes from your stations (rifles, plates, radios), using money and parts.
- **Training** costs time and money.
- **Rare parts** make **better gear** (a legendary rifle, top plates) for your named legends.
- Loot doesn't upgrade soldiers directly; it pays for and unlocks things.

**Answer to "are materials their own currency?"** I recommend **no**. Parts are items with categories. Money is the only currency. That keeps it readable.

---

## 7. Decisions (user, 2026-11-20)

- **Going out:** click a POI or target on the town map, play a **short hands-on scene** there (a minigame or a small first-person spot), then come back.
- **Economy:** **3 resources.**
  - Money is the only currency.
  - Parts are items by category, with rare parts for top gear.
  - Intel loot is posted, sold or used. It never upgrades soldiers directly.
- **Time:** an **hours budget per day.** Every action costs hours; the job eats the daytime unless you skip it.
- **Followers on Nod pay off in all four ways:**
  - followers become **recruits** who contact you;
  - they send **donations**;
  - big followings make raids costly (**crowd protection**);
  - groups notice you and **invite you into inner circles.**

### Round 2 (user, 2026-11-20)
- **Heat goes down** all four ways:
  - lie low (time);
  - bribes (money, or dirt on the officer);
  - move / new identity (resets most of it, costs family and contacts);
  - frame someone else (effective, dark, makes grudges).
- **Raids are softened by:**
  - **Warning signs** (the radio scanner, a contact). The warning starts a **timed scramble**: destroy illegal items, or transfer SOME of them out. Get really good and fast and you can save it all. **This is the pucker factor** when your operation grows faster than your places to hide it.
  - **Hidden caches.**
  - **Hobby covers:** stations disguised as legal hobbies only lose the illegal parts.
  - **The crew keeps some gear** in their own homes.
- **Early money:** the **cover job** plus **repair side jobs** at the bench (fix the neighbours' phones, radios, laptops for cash; bench practice that pays). No skimming or selling Pavel's things for the first kit.
- **First recruits:**
  - from your circle;
  - from followers (some are Bureau informants);
  - people you rescue or free;
  - **rented operators from an inner circle,** after completing quests for them. They're limited use: already high-level, like the legends, but **yours for about 3 days.** "Like a rented high-rated FIFA card."

## 9. Gameplay gaps: where things don't mesh yet

1. **Going out into the world.** Skimming on the bus, keypads, cars, POIs, the coffee shop computer: how is "being out" played? The biggest missing piece.
2. **Time.** A night on the laptop, a bench job, a trip to the hospital, a raid: what does each cost in hours? Without a time budget there's no tension.
3. **Early money.** Before any loot, money comes from the job. Is that enough to buy the first kit? The first hours need a clear income path.
4. **The bridge from you alone to a squad.** When and how do the first recruits arrive, and where do they live?
5. **Why hit a gun store vs a refinery vs a ministry?** Each target type must feed a different station or need, or targets blur together.
6. **Heat recovery.** How does heat go down? (Lying low, moving, bribes, good cover.) Otherwise it only rises.
7. **Followers vs heat.** Is Nod worth it? Followers must buy you something concrete (recruits, donations, protection by crowds) to justify the heat.
8. **Seizure without hopelessness.** A raid that takes everything can make players quit. Caches, insurance and fronts need to exist.
9. **The PC must stay useful late.** When you command an army, what do you still do on the laptop? Logistics, intel, comms.
10. **Your skills vs your gear vs your people's skills.** Three progressions; make sure each is visible and doesn't overlap.
