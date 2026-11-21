# Proof and intel: the first need with every path (design, 2026-11-20)

*The template for every other need (meds, money, weapons): one need, four connected paths, and you physically play the one you lean into. Everything here is gamified: fun systems and invented commands, not real techniques.*

---

## 1. What the need is

The regime's weapon is **"there is no record"**. Your weapon is **proof**: something people can't call fake. **Intel** is the quiet version of proof: what you need to know to act (schedules, names, locations, passwords).

**Things you collect** (each is an item in Files or a paper in your toolbox):

| Item | Examples | What it's for |
|---|---|---|
| **Records** | Station 4 intake ledger, payroll, arrest lists | Proof for propaganda (big credibility), finding people (Pavel) |
| **Photos** | Checkpoint vans, a minister's mistress, a mass grave | Proof (credibility depends on metadata and source) |
| **Schedules** | Guard rotations, convoy times, the bridge shift change | Planning missions and break-ins |
| **Credentials** | A clerk's login, a door code, keys you copied | Opening other paths: a credential from one path makes another easier |
| **Dirt** | Debts, affairs, bribes | Exploiting people (path 4) |
| **Names** | Informants, who signed what (Maj. Stanek) | Targets, grudges, warnings |

**Every item has three numbers:**
- **Weight:** how much it proves.
- **Freshness:** intel goes stale; schedules change.
- **Trail:** how much of you is on it (metadata, the copier's serial, who saw you take it).

The laptop's Scrub tool and careful handling reduce the trail.

**Where proof goes:**
- **Post it** (followers, sympathy, credibility). A post with big weight and no trail is the dream.
- **Hold it** (blackmail, bargaining, the right moment).
- **Use it** (plan a mission, find Pavel, unlock a person).

---

## 2. The four paths

For each path:
- **Lean in:** you play it by hand; this is how it gets better.
- **Order it:** a quick choice, a recruit does it, or a dice roll with clear odds. Worse results, more risk, no growth.

### Path A: Hack it (the default protagonist's angle)
- **What:** break into a state system from the laptop and pull records.
- **Lean in:** a hacking lab (section 3): a map of the target network, short typed commands, hints. You can see exactly what you're doing and how loud it is.
- **Order it:** "find someone who can do it" (a forum contact, for money or a favor). Slower, and it adds their trail to yours.
- **Risks:**
  - a **trace meter** fills while you're connected;
  - patched holes after daily rule changes;
  - honeypots (like SafeTunnel).
- **Connects to:**
  - **credentials from path C or D** skip steps in the lab;
  - a forum reputation (kettle and oldfox teach you new tricks);
  - your VPN and laptop upgrades.
- **Gets better by doing:** you remember devices you've seen, learn new commands, get faster scans, and keep "fingerprints" of each system type. Your notes app fills up with what you know.

### Path B: Break in (physical)
- **What:** go into the building at night and take the paper.
- **Lean in:** a short top-down stealth mission (later milestone) or a tense "night run" event chain with choices at each door.
- **Order it:** send a recruit (needs one with nerve), or pick a route on a floor plan and roll.
- **Risks:** guards, cameras (which path A can turn off first), getting seen, injury, arrest = game over early on.
- **Connects to:**
  - **a hack can loop the cameras**;
  - a job (path C) gives you keys and the floor plan;
  - a clerk (path D) tells you the guard's coffee break.
- **Gets better by doing:** quieter, faster at locks, you notice cameras earlier.

### Path C: Work there (cover job)
- **What:** take a job with access: janitor at the Kessel Annex, records clerk, hospital orderly.
- **Lean in:** the job minigame each day (cleaning rounds, filing). Small daily chances to copy something, see a name, overhear.
- **Order it:** you work but don't look. Steady pay, no proof.
- **Risks:**
  - each copy raises suspicion at work;
  - a big theft burns the job (you must quit, design rule from earlier);
  - your boss or a coworker can become a grudge.
- **Connects to:**
  - keys and floor plans for path B;
  - logins you shoulder-surf for path A;
  - coworkers to exploit for path D.
- **Gets better by doing:** trust at work (more access, a promotion), better at not being noticed.

### Path D: Exploit a person
- **What:** get it from someone who already has it: a clerk, a guard, Elena's old coworker.
- **Lean in:** a conversation game in Messages and in person. Find their pressure point (debt, love, fear, belief), then choose how to use it:
  - **bribe** (money);
  - **befriend** (time);
  - **blackmail** (dirt, creates a grudge);
  - **recruit** (belief; they may join you).
- **Order it:** "lean on them" picks the blunt option. More grudges, less loyalty.
- **Risks:** they talk, they report you, they become an informant, their family remembers.
- **Connects to:**
  - dirt from path A or C;
  - your circle (Viktor's keys are the extreme case);
  - the grudge ledger.
- **Gets better by doing:** you read people faster (see their pressure point sooner), you get more options in conversations.

### Mixing paths is the point
Example, the full Station 4 ledger:
- **A alone:** a hard lab.
- **C first:** a week as a janitor at the Annex gets you the floor plan and a sticky-note password from a clerk's monitor. Then **A** becomes easy, or **B** becomes safe.
- **D first:** the clerk who sits next to the archive owes money. Pay the debt and she copies it, but now she knows your face.

---

## 3. "Leaning in" grows by doing (decided)

- Each path has a hidden skill that rises when you **play it by hand** (not when you order it).
- **Thresholds unlock things you can feel:**
  - a new command;
  - a faster lockpick;
  - a new conversation option;
  - a new kind of target you can see on the map.
- **The laptop shows your lean** in a tiny "habits" panel. It's diegetic: it's your browser history, your toolbox, your contacts. Players see their run's identity forming.
- **Ordering is always available,** so you're never forced into a minigame you don't like.

---

## 4. One hacking lab, start to finish: "The Annex" (Kessel records office)

**Why you're here:** after the forum and Elena's folder, you know a full intake ledger exists at the Interior Ministry's Kessel Annex. Elena's copy is from March. You want the current one. Is Pavel still listed?

**How you get in:** a forum post by kettle says the Annex runs a public "Citizen Records Kiosk" in the lobby, connected to the same network. Its web page is on NetState. That's your door.

### The map (what you see)
A dark network map in a new laptop app, **Probe**. Nodes appear as you find them:

```
[ you ] --- (NetState) --- [ KIOSK ]
                                |
                       [ ANNEX OFFICE NET ]
                     /        |          \
             [ PRINTER ]  [ CLERK-PC-3 ]  [ CAMERA-HUB ]
                               |
                        [ ARCHIVE-SRV ]   <- the ledger
```

**Trace meter** on top: it fills a little per command, a lot for loud ones. At 100% the connection drops, a trail is left (exposure up), and the Annex patches the hole tomorrow.

### The steps (with the invented commands)

| # | You do | What the game shows | Hint (if stuck 30 s) |
|---|---|---|---|
| 1 | Open the kiosk's NetState page, click **Probe this** | The KIOSK node appears | — |
| 2 | `scan kiosk` | "Citizen Records Kiosk v1.2. Maintenance login: ENABLED. Last updated: 2033." | "Eight years without updates. Anything still on factory settings?" |
| 3 | `login kiosk maintenance` | Password prompt. Typing `maintenance` works (factory default) | "The manual for this kiosk is on NetState. Factory password on page 2." |
| 4 | `scan network` | Three new nodes: PRINTER, CLERK-PC-3, CAMERA-HUB | — |
| 5 | Choose your way to the archive (the fun part): | | |
|   | **a)** `scan printer` → it stores the last 200 scanned pages. `pull printer` | You get **fragments**: 3 random ledger pages. Quiet but incomplete | — |
|   | **b)** `scan clerk-pc-3` → "user: m.duda, password: ******". If you have the sticky-note password from the janitor job (path C), `login clerk-pc-3 m.duda` just works. Otherwise `guess` (loud, 3 tries) | Clerk's PC opens. Mapped drive: ARCHIVE-SRV | "Clerks write passwords down. Do you know anyone who cleans that office?" |
|   | **c)** `scan camera-hub` → `loop camera-hub` (optional) | Cameras show yesterday's footage for 10 minutes: makes a later break-in (path B) safe tonight | — |
| 6 | `open archive-srv`, then `search halden` | **The current ledger.** Pavel: *"0402 Halden, P. Block C. Transferred: CAPITAL, Facility 1, 03 Oct."* | — |
| 7 | `pull ledger` (loud: +30% trace) or `read` only (quiet, you only get what you note down yourself) | The file lands in Files (with the clerk's workstation in its metadata) | "Pulling the whole file is loud. Do you need all of it, or just one name?" |
| 8 | `logout` / `wipe logs` (if learned) | Trace meter stops. Unwiped logs leave a trail for the investigator tomorrow | — |

### What makes it fun (the design goals)
- **Every step reads like hacking but is a choice, not a skill test:** quiet vs complete, now vs later, alone vs with another path's help.
- **The twist:** Pavel was **moved to the capital** on 3 October. The lab doesn't just give you an item; it moves the story and raises the stakes.
- **Connections:**
  - the janitor job (C) makes step 5b trivial;
  - the camera loop (5c) sets up a break-in (B);
  - **m.duda is Lena's teacher, Mrs. Duda** (from Lena's homework), a part-time Annex clerk. She becomes a path D target. Small world, real dilemma.
- **Leaning in:** after this lab you know the "kiosk", "printer" and "clerk PC" device types. Next time `scan` tells you their weak spots at once, and you've learned `wipe logs`.

### Failure is interesting, not a game over
- **Trace fills:** you drop out, the Annex patches the kiosk, and you need another way in (job, break-in, person). The investigator gets a lead: "someone in Kessel used the kiosk at 23:40".
- **Wrong guesses** lock the clerk's account. Mrs. Duda gets questioned at work tomorrow (and she might remember who asked about her password).

---

## 5. Answers (user, 2026-11-20)

1. **Pavel moved to the capital:** yes, great twist.
2. **Mrs. Duda as the clerk:** "GREAT dilemma this early, exactly the kind of thing I mean." Keep it.
3. **Typing:** keep typing, it makes you feel like a hacker. But some players won't want to think that hard, so add an **assist option with buttons that autofill**. You still have to know what to do. It should feel like you've **memorized the pattern** (like the steps to get around a two-factor login). See section 6.
4. **Lab length:**
   - **short labs** for smaller loot (espionage on a political target, a schedule, a credential);
   - **big missions** for high-tier loot, with procedurally generated rarity (5-star blackmail, leaks), with the looting thrill of the *Dungeon Crawler Carl* books but our own rarity system;
   - big loot is a huge upgrade, and it pushes you to unlock that path's support for your troops. See section 7.
5. **The terminal UI's vibe needs work** (known, WIP). Do a look pass later, with the user's references.

---

## 6. Typing and the assist option: you remember patterns

- **Typing is the default.** Commands are short and forgiving: autocomplete with Tab, typos suggested ("did you mean `scan printer`?").
- **Assist option** (a setting, can be toggled any time): command **chips** appear under the prompt for commands you **already know**. Click to autofill, Enter to run.
  - Chips only show commands you've learned. New commands still come from hints, the forum, kettle, and experimenting.
  - Chips never show *which* target or *what order*. You still have to know the plan; the assist only saves typing.
- **Patterns (the "memorized" feeling):**
  - After you beat a kind of defense by hand once, the sequence is saved as a **pattern** in your notes, e.g.:

    ```
    PATTERN: two-factor bounce
    1. login <target> <user>      (the code goes to their phone)
    2. spoof sms <user>           (needs their phone number)
    3. replay code
    ```

  - Next time you meet that defense, the pattern is a one-click chain: the steps type themselves fast, with a satisfying rattle.
  - **Patterns can break:** a daily rule ("two-factor codes now expire in 30 seconds") makes an old pattern fail halfway. You learn the new version and the pattern updates. This is the Papers, Please "new angles each day" feeling, applied to hacking.
- **Leaning in:** more patterns, longer chains, faster replays. Your pattern book is your hacker identity for the run.

---

## 7. Loot and rarity (short labs vs big jobs)

**The feeling:** opening a drop and seeing it's rare. Big, readable, a little ridiculous. Your own side's voice (darkly funny) announces it.

### Rarity tiers (ours)

| Stars | Tier | Example drop |
|---|---|---|
| 1 | **Scrap** | A canteen menu, a misfiled form. Flavor, small sympathy |
| 2 | **Lead** | A guard rotation, a clerk's login, one name |
| 3 | **Story** | A payroll showing ghost workers, a photo of the grey vans with readable plates |
| 4 | **Scandal** | A minister's bribe ledger, the full Station 4 list |
| 5 | **Bombshell** | Proof that topples someone: the Marshal's health records, a massacre order with a signature |

### Where loot comes from
- **Short labs** (about 5 minutes, several a week): espionage on a political target, a district office, a police inbox. Drops 1-3 stars. Leads, credentials, small dirt. They unlock things: a person to exploit, a door code, the next lab.
- **Big jobs** (a long lab, a break-in, a multi-step operation): drops 3-5 stars, generated from the target. A 5-star drop is rare and changes your run.

### Each drop is generated
- **Target:** who or what it's about (a person, an institution).
- **Type:** blackmail, leak, credential, schedule, money trail.
- **Stars:** the tier, rolled from the job's difficulty and how well you played (quiet, complete, fast).
- **Traits**, rolled per drop. Examples:
  - **Verified:** credibility up when posted;
  - **Hot:** decays fast, use it this week;
  - **Chain:** points to another target, a new lab unlocks;
  - **Personal:** using it creates a grudge;
  - **Traceable:** your trail is on it, scrub it first;
  - **Leverage:** can turn the target instead of exposing them.
- **The announcement:** a card flips open with the tier color, the name and the traits. The forum's grumpy archive bot (lantern's "the Archivist", our own voice) grades it with a dark one-liner.

### What loot is for
- **Post** it: followers and sympathy. Higher stars mean bigger swings; Bombshells can flip a whole district.
- **Use** it: blackmail or turn a person, plan a mission, find Pavel.
- **Sell or trade** it: to foreign press or a sponsor for money and favors.
- **Unlock path support for your troops** (the long-term upgrade):
  - spending big loot on a path makes that path available to your people, not just you;
  - examples:
    - a 4-star police payroll leak → your cells get "known guards" (safer break-ins in that district);
    - a Bombshell on the telecom ministry → every cell gets safer channels for a month;
  - this is how leaning in becomes the movement's strength.

---

## 8. Still open
- Rarity names: Scrap / Lead / Story / Scandal / Bombshell, or something else?
- The Archivist's voice: who writes its one-liners (user, or Claude in the user's style)?
- How often should a 5-star drop happen in a 10-hour run? (Proposal: 1 to 3.)
