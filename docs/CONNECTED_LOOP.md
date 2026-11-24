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
B2 BUILT 2026-11-24 (bot-tested, not played): the garage hub is art/garage_v3.glb walked in first person. v2/world/garage_world.gd: a capsule player (spawns by the house door, data/v2/stations.json "spawn"), one StaticBody3D per station with a box per mesh (collision + the view's pick ray, reach 2.3 m; rugs and ceiling things get none), kind_look.gd on the model, a light in every Hang_Bulb / Lamp_Bulb (a bench's desk lamp brightens while you work there), the sewing table's earned stage shown (Crafting.bench_stage), guide_to(id) turns the view to a station and makes it glow. v2/garage.gd: WASD + mouse look (cursor captured), the centre dot (hud.dot), E or left click uses, Esc pauses, Tab frees the cursor (to click the corner TONIGHT board); a card turns you to its station ("walk over and press E"). Station "board" (v2/stations/board.gd) shows the board big. stations.json: new coords, no facings; corkboard, clipboard, forgery desk, floor hatch hidden (the war room still opens from the PC); phone = PC_Phone, house door = the House_ meshes. The box's slots and gadget spots and the prisoner's seat come from stations.json. The prisoner's chair now faces the room (make_garage_v3.py). art/garage_v2.glb is unused now (delete once the user signs off B2).

## 8. The game answers you: raid notes for C and D (GPT, pasted by the user 2026-11-24)
User: "more concepts for when we hit these parts. When you start working on something, reference everything we've talked about and make sure you aren't missing something I've wanted added." Yardstick (user, a Gabe Newell clip, GAME_DESIGN decisions log): fun is how much the game recognizes and answers the player's choices and actions. **The response is dependable; the reward varies.**

The first depot raid must change something you can see, someone you care about, and a decision you make tomorrow. The biggest gap now: **the vault door.** Viktor opens it on his own, so the player never gets a choice the game can answer. Give that choice back, then make its consequences impossible to miss.

| When the player... | The game answers... |
|---|---|
| Orders Viktor to hold | He says "Holding", stops where you can see him stop, and stays until another order or a queued one takes over. "Holding" shows beside his portrait. If something makes him leave, he tells you why. |
| Tells Ada to use the depot PC | Ada acknowledges; the feed shows her turn to the terminal. The board shows which vault door you chose and what happened to it; the other doors visibly switch to "Locked out". The one-door rule is told before you choose. |
| Sees a round hit something | Plaster sheds dust and keeps a mark, metal sparks, armour has its own sound, a wounded fighter's posture and portrait status change. Marks last the whole raid. Readable hits come before tuning how many hits drop someone. |
| Packs a handmade dressing | It shows in the gear cage. When Ada uses it you hear her call it and see a crew member's status change. Back home it's gone from her rig and the report names what she used. |
| Leaves with the main supplies, skips the vault | Called a successful pickup; the Dobrev crate waits under a garage lamp. Someone hurt may be resting the next evening. You see what you gained and what the choice cost. |
| Draws Bureau attention | A specific note tied to what you did (the corkboard is hidden since B2: a TONIGHT card or a Bureau corner of that board, ask the user). Later a notice names tomorrow's consequence. Start with one cause and one visible follow-up, so Krall feels like someone answering you. |

The vault can hold junk, paperwork or a great find; every time you pick a door you see THAT door open, know what you got, and see it turn up where it belongs at home. The surprise is what's inside.

**Build first** (with C, then D): one choice the player commits to, one handmade item, one thing brought home, inside the depot run that exists. The target sequence: Viktor waits at the door because you told him to. Ada uses the dressing you packed because Ivo gets hurt. You leave with the main supplies and give up the vault. You walk into the garage: the carton is on the table and Ivo is resting. Every screen has a job: the overview is where you make the call, the helmet feed is where you see it happen, the garage is where the game remembers.

**Before starting C or D:** re-read sections 2 to 8 here, docs/COMBAT_SLICE.md, docs/DEPOT_SLICE.md section 8, the GAME_DESIGN decisions log and the ROADMAP parking lot, and list anything the user asked for that the plan misses.
