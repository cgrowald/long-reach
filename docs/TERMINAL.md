# The terminal: design (2026-11-20)

*The user loves in-game computers (Welcome to the Game, Hacknet). The terminal is the first gameplay to build, on its own, to make sure it's fun to use. It must have its own quirks and secrets.*

---

## 1. Goals

1. **A toy you want to poke at,** not a menu. Windows you drag, typing that matters, sounds, little reactions.
2. **Diegetic:** everything is in-world. There are no game tooltips; the computer itself, its files and its people teach you.
3. **Learnable angles:** like Papers Please, you discover rules and tricks (metadata, logged searches, honeypots) by using it and getting bitten.
4. **Secrets:** hidden commands, the previous owner's leftovers, easter eggs that reward curiosity, some that matter for the campaign.
5. **Data-driven:** sites, messages, files, rules and secrets live in `data/terminal/` JSON so the content can grow without code changes.

---

## 2. The machine: "HEARTH OS 7" (in-world brand, placeholder)

A cheap secondhand laptop running the country's state-approved operating system.

- **Boot:**
  - a fake BIOS beep;
  - the state logo with a slogan (*"A connected citizen is a safe citizen"*);
  - a login screen;
  - **the password is real:** you choose it at the start. A **sticky note** on the bench (in the room) can hold it, which is convenient until the room is searched.
- **Hardware quirks:**
  - **The battery drains;** plug it in on the bench. At 5% it dims; at 0% it dies and **unsaved drafts are lost**.
  - **Fan noise** rises with heavy apps; the VPN slows everything.
  - **The Wi-Fi is weak** in the garage: loading bars, occasional drops, a signal icon. Later upgrades: an antenna, a better router, the café's connection.
  - The clock in the corner is the game clock, so the curfew is visible.
- **Look:** a crisp retro desktop: chunky pixel window frames, a slightly bent CRT-style shader option, a pixel wallpaper. Windows drag, minimize and close. A taskbar with a start menu.
- **Sound:** keyboard clicks, a modem-like connect sound, a soft "pip" for messages, the low fan hum.

---

## 3. Apps (first set)

| App | What it does | Quirks |
|---|---|---|
| **Messages** | Chats with contacts: typing dots, delays, read receipts (on or off), message history | Contacts have personalities: Hana types in lowercase; Josef writes paragraphs; the lantern never uses names. Messages can be **deleted for safety**, and the game remembers what you didn't delete. |
| **NetState** (browser) | The state internet: news, government portal, shops, a social feed, a search engine | **Searches are logged** (the eye icon). Blocked pages show a state warning, and visiting them is noted. Typed addresses work for sites you've learned. |
| **The forum** (via browser, after you learn the address) | The underground: posts, threads, replies, upvotes, private messages, your posts | Needs the password; **trolls, real leads, honeypots**; your posts gain followers. |
| **Files** | Your documents, photos, downloads, the previous owner's leftovers | **Metadata viewer** (and a strip tool once found); hidden files; an encrypted folder (see Secrets). |
| **Network** (unlocks after first recruits) | Your people as cards, linked, with what you know about them | You write your own notes on each person. |
| **Wallet** (unlocks later) | Money and transfers | Every transfer shows how traceable it is. |
| **Trash** | Deleted things | Not really gone until emptied, and even then "recoverable" if seized. |
| **Terminal** (command line, hidden at first) | A real shell with commands | Found through a secret (see 5). Power users get shortcuts: wipe, scan, trace. |

**Later apps:** VPN, the Map, a radio-scanner app, a drone feed, an encrypted drive tool, a dead-man switch.

---

## 4. Rules and angles the terminal teaches (the "Papers Please" layer)

Each is a hidden mechanic you discover, usually through a message, a news item or getting caught:
- **Searches on NetState are logged.** Use the forum's search or the café computer instead.
- **Photos carry metadata** (the camera serial, GPS, date). Strip it or you get traced.
- **The printer embeds a serial** in everything it prints.
- **Not every VPN is real.** Read the forum carefully: account age, who vouches for it, odd wording.
- **Delete vs. wipe:** deleted files sit in Trash; emptied files can be recovered from a seized laptop unless wiped.
- **Typing patterns:** posting at the same hour every night narrows down who you are. Vary it.
- **Reused passwords:** reusing the forum password on a state site links your accounts.
- **Contacts can be compromised:** a contact's writing style suddenly changes. (Is that really Hana?)
- **New daily rules** change these: *"VPN traffic is now throttled"*, *"all photos uploaded to NetState are scanned"*.

---

## 5. Secrets and quirks (for fun, some useful)

- **The previous owner:** the laptop's last owner never wiped it properly.
  - Their dog wallpaper, a half-written love letter in Drafts, a Trash full of job applications.
  - **An encrypted folder named `do_not_open`.**
  - Clues across their files (the dog's name, a birthday in a photo) lead to the password.
  - Inside: who they were. Someone who also disappeared? A cache location? A list? Different every campaign; generated from a small set of mysteries.
- **The hidden shell:** pressing a secret key combo on the login screen (hinted at in an old forum post) opens a command line. Commands:
  - `help`;
  - `whoami`;
  - `scan` (looks for spyware);
  - `ls -a` (hidden files);
  - `fortune` (underground jokes);
  - `wipe` (when the knock comes).
- **The state's spyware:** NetState has a background process, "CitizenCare". Find it, and you can leave it (safe, watched), disable it (suspicious if they check), or **feed it fake activity** (later, advanced).
- **Easter eggs:**
  - a pixel minesweeper clone called *"Field Clearance"* (approved by the Ministry of Defense);
  - a screensaver with a cat that occasionally appears in later rooms;
  - typing the Marshal's name into the shell gives a sarcastic reply;
  - a desktop clock that plays a tune at midnight on the leader's birthday;
  - the forum has a long-running thread about a legendary user nobody has ever seen.
- **The knock:** when the door is knocked during a raid, you get a few real seconds. Close the lid, run `wipe`, or pull the battery. What's on screen when they come in matters.

---

## 6. First prototype: T1 "the terminal on its own" (proposed scope)

Goal: **10–15 minutes of play on just the laptop**, enough to tell whether the terminal is fun. No country map, no room, no job minigame yet. Day transitions are a simple black screen with *"Tuesday"*, plus short text for what happens off the laptop.

**Included:**
- **Boot and desktop:** login with your own password, draggable windows, taskbar, clock, battery, Wi-Fi signal, sounds.
- **Apps:** Messages, NetState browser (news, search with logging, social feed, blocked pages), the forum (address and password learned in play), Files (with metadata viewer and strip), Trash.
- **Content:** Days 1–4 of the first week (Pavel's box, the lantern contact, Hana, the forum, Station 4), written as data.
- **One learnable angle that bites:** logged searches raise exposure; metadata on a posted photo raises it more.
- **Exposure meter:** shown only as the eye icon's intensity. No numbers; it should feel ominous.
- **Secrets:** the previous owner's files with the `do_not_open` puzzle (one mystery for now) and the hidden shell with a handful of commands.
- **Save/load of terminal state.**

**Not in T1:** the room around the laptop, the workbench, the country, recruits as a system, the job, the map.

**Done when:** you can play Days 1–4 on the laptop, find Pavel's name on the forum, get bitten by at least one rule, crack the previous owner's folder, and find the hidden shell. Then **you tell me whether it's fun to use.**
