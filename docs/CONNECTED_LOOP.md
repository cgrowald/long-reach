# The connected loop (plan, 2026-11-24)

User, 2026-11-24: *"You're lacking in connecting all of our systems."* *"Keep all of this super readable, I never want anyone to feel lost."* *"The whole garage needs a do-over in the direction you took the bench: wide and open, and fun."* The GPT review notes (pasted by the user) are folded in below. Garage concept art: docs/refs/Garage/ (01 overview with labels, 02 wide walk-in, 03 sewing bench status sign, 04 before / back home, 05 the TONIGHT board, which the user likes best).

## 1. What's wrong now
Every system works on its own (benches, PC hacks, markets, the cage, the raid, the prisoner, Krall), but nothing **tells** the player what one system means for the next. You can finish a craft and not know who needs it, come home and not see what changed, open the garage and not know what to do tonight.

## 2. The rule: always show what's next
- **The TONIGHT board** (concept 05): a big corkboard by the roller door. Three to five pinned cards, written from the game state, plain words: `BENCH: rig ready`, `CREW: Ivo resting (2 nights)`, `DEPOT: plan file found`, `MARKET: strap arrives tomorrow`. Click a card and the camera turns to that thing.
- **Status signs on every station** (concept 03): a small board beside each bench listing what it can do right now: `STARTER RIG  READY`, `CHEST RIG  NEEDS 1 STRAP`, `REPAIR JACKET  READY`. The same at the PC (`DEPOT HACK READY`), the cage (`ADA HAS NO DRESSING`), the roller door (`DEPOT OPEN` / `LOCKED 3 NIGHTS`).
- **Things sit where you'll use them** (concept 04): after a raid, the Dobrev carton is on the table, the torn jacket lies under the sewing lamp, a bench upgrade waits beside its bench to be walked over and installed. You see two things worth doing the moment you walk in.

## 3. The loop, link by link (each link shows on the next)
1. **Evening starts:** the TONIGHT board sums up what changed.
2. **Benches:** their signs say what's ready and what's missing. Making things takes no time (user 2026-11-24).
3. **Missing part:** the market answers it two ways: order it (arrives tomorrow evening, it pops up on the board) or go to the Tram Yard tonight (costs the evening, a chance to find it now).
4. **The gear cage, with tonight's job selected:** a few facts beside the roster: `Ada carries the drop stick`, `Ivo resting`, `Nobody has a dressing`. Click one to jump to the person or slot that fixes it.
5. **The raid** (section 4): you direct it.
6. **Coming home:** the haul is placed in the garage (section 2), the report names your items ("Ada used your field dressing, 3 stars, made day 2"), torn gear shows its tears.
7. **The next evening answers the last:** every raid leaves one visible follow-up: a recruit who messages you, an upgrade to install, a Bureau clue that changes tomorrow's plans.
8. **One item's story across the loop:** the jacket you patched shows in Ada's helmet feed, comes back torn, gets mended again; the dressing you packed is named when it's used.

## 4. Combat: you direct it (GPT notes, to be decided with the user)
- **The main screen:** an elevated 3D view of the building (only the layout and what the crew has found) with **one live helmet feed pinned beside it**. Click a portrait: select that fighter and switch the feed. Zoom toward the selected fighter for a moment so the gear shows.
- **Orders:** Move, Hold, Interact, Withdraw. The squad moves together by default; select one fighter to send Ada to the PC or keep Viktor with Ivo. Pause any time and queue orders.
- **What the crew does on its own:** routine movement, covering, reloads. **What needs you** (or a plan you approved): opening the next unknown door, using the objective, carrying on after someone goes down.
- **Pushback becomes a choice:** "Ivo can walk. I can get him out, but we leave the freight." Two buttons: `Bring Ivo out` / `Finish the pickup`.
- **The crew tells you what matters:** automatic callouts of real changes (heard while you watch another feed), each fighter's last reported status next to their portrait, distinct silhouettes for kneeling, reloading, down (docs/refs/combat: walk, kneel, flinch, swaps, impacts).
- **Leaving is a decision you feel good about:** three outcomes the game recognises: `Out with the freight`, `Stayed for the vault`, `Got everyone out now`. Backup shows as possible or confirmed. A clean pickup with all three vault doors shut is reported as a success.
- **Hits you can read before hits that hurt more:** an armour sound and flinch, a wounded posture and a status line at the portrait, short tracer streaks. Then test lethality: an unarmoured guard drops in one or two clean hits; our fighters are wounded by the first serious hit and can go down on the second; a downed fighter can be carried out at a cost.
- **Later test item:** a riot shield (one fighter's job; slows them, takes a carry slot, wears visibly).
- **First test:** one depot room, two fighters, one objective, one disruption. Play it twice. The goal: "This time I held Viktor back and sent Ada to the PC."

## 5. The garage do-over (concepts 01, 02)
Wide and open, a warm room you want to be in: the sewing table by the house door (front left), the med table along the left wall, the roller door in the middle of the back wall with the TONIGHT board beside it, the electronics desk with the Veltin CRT back right, the equipment bench on the right, the gear cage front right, a rug down the middle, plants, a lamp over each station. Every station has its status sign. The new sewing table (art/sewing.glb) fits here at full size.

## 6. Order (user 2026-11-24)
Answers: A first, then B, then C, then D. The new garage is walked around in first person. Combat: the 3D overview with a pinned helmet feed. Lethality: GPT's values only for vital hits (head, torso); arm and leg hits take more.
A. The TONIGHT board and station signs, fed by the systems that already exist (cheap; fixes "lost" right away). **Built 2026-11-24:** v2/sim/tonight.gd (board + signs from benches, mending, crew, drop stick, dressings, depot lock, plan files, orders arriving, the chair), v2/ui/tonight_board.gd (corkboard top left in the garage; click a card to turn to that station), and each station's sign under its hover tag (READY in amber, what's missing in grey). Moves into the 3D garage as real boards with B.
B. The garage rebuild from the concepts (big; the board and signs move into it).
C. The combat test room: orders, the 3D view, the pinned feed, pushback choices, leaving outcomes.
D. Coming home: the haul placed in the garage, one follow-up per raid.

## 7. B, the garage do-over: answers and build plan (2026-11-24)
Answers: concept 01's placement; first person, WASD + mouse look, a centre dot, click or E to use; a wide double garage (~8 x 10 m); fewer stations (the TONIGHT board replaces the corkboard and clipboard, the war room is on the PC, the forgery desk and floor hatch wait until they're used).
Layout (top view, the roller door in the middle of the back wall):
- back wall: shelves with boxes (left), the roller door (middle), the TONIGHT board beside it (right), the electronics desk with the Veltin CRT = the PC + the box + the phone + the hacking bench (right corner);
- left wall: windows; the med table (middle); the house door (front) with the sewing table beside it (front left); the prisoner's chair in the back-left corner under its own bulb;
- right wall: the equipment bench = the gun bench (middle); the gear cage and the stash shelves (front right);
- the middle: a long rug, open floor to walk through; a lamp over every station; plants on the high shelves.
B1 BUILT 2026-11-24 (art/src/make_garage_v3.py -> art/garage_v3.glb, not in the game yet; too dark and empty next to the concepts: B4). Build steps: B1 the room and every station's starter model (art/src/make_garage_v3.py; the sewing table reused from make_sewing.py; the other benches' starters from their GPT stage sheets in docs/refs/benches/); B2 first-person walking, the centre dot, using stations, the old station screens opened from it; B3 the TONIGHT board and the station signs as real boards in the room; B4 lights, sound, clutter, screenshots against the concepts.
