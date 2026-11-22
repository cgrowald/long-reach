# The hunt (design draft, 2026-11-21)

*Answers CORE_LOOP section 5b, E: the pressure is the Bureau coming to find you. Plague Inc's cure meter, but a detective, and deeper than one meter. Nothing here is built. The questions in section 9 are the user's to decide.*

---

## 1. The one idea: Guess Who, played against you

**The Bureau doesn't know who you are. It knows a list of facts about "the suspect", and it's crossing off everyone in town who doesn't match.**

- The town is already generated (`sim/world_gen.gd`), so the **suspect pool is real people**: every adult in town who fits what the Bureau knows.
- Every job leaves **clues**. Each clue, once the Bureau has it, **pins a fact** ("the suspect lives in the Harbour district", "knows electronics", "is out late on weeknights").
- Each pinned fact shrinks the pool: **4,120 → 610 → 38 → 6 → you.**
- When the pool is small enough, they start **searching suspects' homes**. At one, they get a **warrant**.

This is the readable version of Plague Inc's cure meter. You always know the number, and you can see *why* it moved ("CCTV at the clinic: male, 30s, tall").

## 2. Two numbers, not one

| | **Attention** | **Profile** |
|---|---|---|
| What it is | How hard the Bureau is looking | How close they are to *you* |
| Shown as | The size of the case: one inspector, a task force, a ministry priority | The suspect pool and the corkboard of pinned facts |
| Goes up from | Impact and fame: Nod followers, big loot posted, embarrassing the regime, violence | Sloppiness: clues left behind on jobs |
| Does what | Speeds up everything: clues get collected faster, more cameras and checkpoints appear, more informants | Narrows the pool toward you |
| Goes down by | Lying low, quiet weeks, the regime getting distracted (another group's attack) | Cleaning clues, misdirection, moving, a new identity |

**Why two:** a famous but careful player is safe for a long time. An unknown but sloppy one gets picked up by a bored local cop. Both play styles are real, and the player can tell which problem they have.

## 3. The inspector (Nemesis-style rival)

The case belongs to **a named, generated inspector** with a face, a rank and traits.

- **Traits change how he hunts** (examples):
  - *Methodical:* clues stay collectible longer.
  - *Tech-minded:* hacks leave one extra clue.
  - *Vain:* hates being embarrassed on Nod; loses rank if you mock him, but gets meaner.
  - *Greedy:* can be bribed. *Zealot:* can't, ever.
  - *Lazy:* arrests the first person who fits.
- **You learn his traits** the way you learn anything: dirt, intel, a contact at the Bureau.
- **He changes over time:** promoted when he wins (more resources), demoted or replaced when you humiliate him, and the replacement might be worse.
- **He remembers.** Frame someone and he finds out, and he's angrier. Kill him and a much worse one arrives, with Attention spiking.
- **Later, the hunt grows into an org chart:** district inspector, then regional colonel, then the minister. Each one is a bigger target for your movement.
- **He comes to you.** At some point he knocks: on your door, at your cover job. That's an interview scene played on the **exploit-a-person job engine, in reverse**: you're the one who has to stay "guarded" while he looks for your tells. A typed lie that matches your cover story is a bonus card (typing flourish, conflict C).

## 4. Clues: what each job leaves behind

**The trace bar inside the job decides how many clues fall out.** Pull out early, leave fewer. A perfect job can leave none.

| Path | Clues it tends to leave | Facts they pin |
|---|---|---|
| Hack | Logs, a connection's rough location, the tool's signature | District, "knows electronics", which gear you own |
| Exploit a person | The person themself (they talk), a meeting place, your voice | Appearance, where you hang out, who you know |
| Break in | CCTV, fingerprints, a footprint, a witness | Build, age, sex, shoe size, a vehicle |
| Work there | The roster, the shift log | Your job (very dangerous: that's almost your name) |
| Buying grey gear, posting on Nod | Purchase records, writing style, posting times | Schedule, money habits, skills |

**Card choices change the clues**, which gives the cards a second job: brute force leaves a loud log, a cloned badge leaves a name (not yours), gloves stop fingerprints. Rig modules can be built to cut specific clue types ("Scrubber: your first log per hack is never written").

## 5. A clue's life (and when you can still get it back)

```
LEFT at the scene  →  COLLECTED by the Bureau  →  PINNED on the corkboard
   (1 to 3 days)            (1 to 3 days)               (stays)
```

- **While it's LEFT:** clean it up. Wipe the logs (a hack job), steal the CCTV tape (a break-in), pay the witness (a person job). Cheapest window.
- **While it's COLLECTED:** it sits in evidence. Bribe the evidence clerk, or break into the precinct. Harder, more heat.
- **Once it's PINNED:** you can't remove it. You can only **muddy it** with a contradicting fake clue (the pool grows back), or **make it stop being true** (move house, change jobs, sell the car, new identity).
- **Attention speeds up** both windows. A big case collects clues the same night.

**The key thing:** every counter-move is a job on the same engine. Cleaning up your mess is gameplay, not a menu button. It costs hours, so it competes with doing more damage tonight.

## 6. What you do back

| Move | What it does | Costs |
|---|---|---|
| **Clean** | Removes a clue before it's pinned | Hours tonight; a job that can itself leave clues |
| **Lie low** | Attention falls. No new clues | Days with no progress; your people get restless |
| **Misdirect** | Plant a fake clue: the pool shifts and grows | A job; needs knowing what they already have |
| **Frame** | Point the pool at one real person until they're arrested. Attention drops a lot | Dark. The inspector may find out. That person's family remembers (grudges, GAME_DESIGN) |
| **Bribe** | Lose a collected clue, or buy a peek at the corkboard | Money, or dirt on the officer. A *Zealot* can't be bought |
| **Move** | Address facts stop being true. The pool grows back a lot | Family, contacts, whatever you can't carry |
| **New identity** | Almost a reset | Very expensive, late game, needs the network |
| **Embarrass him** | Post his failures on Nod: he gets demoted or replaced | Attention goes up |

## 7. What you get to see (always warned, never a random death)

- **Always visible:** the pool size, and a warning ladder you can't miss. A neighbour says "police were asking about a tall man in a grey coat". Bureau letters. Patrols on your street. A search at a neighbour's house.
- **The corkboard is loot.** By default you see rumours. Hack the Bureau's case server, bribe a clerk or turn an officer, and you see the **actual corkboard**: every pinned fact, every clue in evidence, his next planned move.
- **The night ledger** lists the Bureau's moves each night: "Collected: clinic CCTV. Canvassing Harbour district. 38 suspects."
- **Before any raid there's a warning** (the radio scanner, a contact, a neighbour's call) and **the scramble** (decided 2026-11-20). How much warning you get depends on what you've built.

## 8. How it grows with the movement

- **Your people are a risk.** Anyone arrested gets interrogated and **leaks the facts they know about you.** Someone who's been in your garage knows your address. A cell member who only met a courier knows almost nothing.
- **So cell structure IS your defence.** That's the real-world logic, gamified: the "OHHH, that's why resistance cells work like that" moment.
- **Informants:** some Nod followers and recruits are Bureau plants (decided 2026-11-20). They feed the corkboard until you find them.
- **The Bureau's moves become the morning rules:** "New checkpoints in Harbour", "All electronics purchases now registered". You see the hunt reshape the town.

## 9. Decided (user, 2026-11-21)
- **Visibility:** earn it. Pool size and the warning ladder always; the real corkboard only through Bureau access.
- **Inspector:** a named rival with traits who remembers you.
- **Innocents:** yes, the Bureau can arrest an innocent adult who fits.
- **Pacing:** sloppy every night = a raid warning around day 8 to 10; careful = safe through week one.

### The questions as asked

1. **How much do you see by default?**
   *Claude's take:* the pool size and the warning ladder always; the corkboard only once you've earned access. Getting inside the Bureau becomes one of the best early goals.
2. **The inspector: a named rival, or a faceless Bureau?**
   *Claude's take:* a named rival with traits who remembers you. Maybe you write some of his lines (WRITING_GUIDE).
3. **Can innocent people get taken?** When the pool is small and the inspector is lazy or impatient, he arrests whoever fits best. If it's not you, Attention drops and someone's life is ruined because of you.
   *Claude's take:* yes, it fits the bleak regime and makes framing feel heavy. Only adults (tone rule).
4. **Pacing for the first week.** How fast should a careless player be caught?
   *Claude's take:* sloppy every night = a raid warning around day 8 to 10. Careful = safe through week one, but the pool is visibly shrinking.

## 10. The slice (fits CORE_LOOP section 6)
- One inspector with two traits.
- The pool computed from the generated town; five fact types (district, build, age, skill, schedule).
- Clues from the two paths in the slice (hack, exploit a person), dropped by the trace bar.
- One counter-move job: clean (wipe logs) as a hack job. Plus lie low.
- The night ledger shows the Bureau's moves; the warning ladder ends in a raid warning and a placeholder "game over" screen.
