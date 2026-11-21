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

## 5. Questions for the user

1. **The twist:** Pavel moved to the capital. Does that work for you, or should the first arc keep him in Kessel?
2. **Mrs. Duda** (Lena's teacher) as the clerk: a good small-world dilemma, or too cruel this early?
3. **Typed commands:** is the table above about the right amount of typing, or should commands be clickable buttons with typing optional?
4. **Lab length:** this one is about 10-15 minutes. Should most labs be shorter (5 minutes, several per week) or rarer and bigger?
