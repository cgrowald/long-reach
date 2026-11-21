# The room and the workbench: design (2026-11-20)

*The garage is the hub of the early game: where the laptop lives, where you build things, where people knock. This doc covers how the room works (T2a, being built now with placeholder Blender models) and the first bench minigames (T2b, next).*

---

## 1. The room: how you use it

**You sit at the bench.** Seated first person, pixel-art 3D. You don't walk; you turn and lean.

| View | What's there | What you can do |
|---|---|---|
| **Laptop** (default) | The laptop on the bench, the lamp, the mug | Click the laptop to **use it**: the camera leans in until the screen fills your view, and the OS takes over. Leave with Esc or right-click (lean back) |
| **Bench** (turn left) | Pegboard with tools, toolbox, Pavel's box, vise, parts | Pick up Pavel's notebook. Work on things (T2b: the bench minigames) |
| **Door** (turn right) | The side door to the house, the coat hook (Pavel's jacket), Lena's bike | Who's knocking? Hide things before the door opens (later) |
| **Window** (turn right, look up) | Rain on the glass, the street, Bruno's window across the road | See who's outside: a car that parks too long, Bruno's light on. (Later: a source of warnings) |

**Controls:**
- A/D or the arrow keys turn between views; the mouse at the screen edge shows arrows to click.
- Click objects to interact. Esc or right-click leans back.
- The laptop keeps running while you look away: messages pip, the clock moves.

**Things on the bench are real objects:**
- the notebook (click to read);
- the sticky note with your password (if you wrote one);
- the charger plug (click to plug or unplug; the cable shows);
- the laptop lid (close it to end the night).

---

## 2. Mood (placeholder now, your tweaks later)

- **Lighting:**
  - night, a warm bench lamp, the laptop's cold blue glow;
  - deep shadows in the corners;
  - a dim streetlight through the window.
- **Pixel-art 3D:** rendered at low resolution and scaled up with hard edges. The laptop OS stays crisp when you're using it.
- **Story clutter:**
  - Pavel's box;
  - his jacket on the hook;
  - Lena's bike;
  - a calendar with the Marshal's face;
  - a coffee mug;
  - a toolbox.
- **Later:** rain on the roof (sound), the lamp flickering when the power dips (regime outages), breath in the cold.

**Gap question for the user:** send screenshots of games or art whose look you love for this room. They set the palette and the light.

---

## 3. Events that use the room (later milestones)

- **A knock at the door.** You have a few real seconds:
  - close the laptop lid;
  - throw the notebook in the toolbox;
  - cover the bench.
  
  What's visible when the door opens matters: Mira, Lena, Viktor, Bruno, or the police.
- **Lena wanders in** looking for her bike.
- **A car on the street** with its engine running for 20 minutes.
- **A power cut:** the lamp dies, the laptop runs on battery.

---

## 4. The workbench (T2b: the first bench minigames)

Rule: **by hand → master → automate** (design pillar 2). Each bench job is a short, tactile, stylized minigame, not a real procedure. Like Schedule I's mixing: satisfying to do, quick once you know it.

**First bench jobs (from the first week):**

| Job | How it plays | Teaches |
|---|---|---|
| **Fix Pavel's phone** | Unscrew the back (click the screws in order), pop the cracked screen, fit the scrap screen, reconnect the ribbon cable (drag), screw it shut. Too rough, and you crack the new one | Basic bench handling: tools, order of steps, care |
| **Strip a photo's "backpack"** | Not on the bench: in the laptop, via Scrub. Stays a laptop thing | — |
| **Fix a radio** (Agnes's) | Find the loose wire by testing points with the meter, solder it | Using the meter; later used for bugs and radios |
| **Clean and repair a bought pistol** | Strip it into parts, clean, replace a worn part, reassemble in order | The first step toward the weapons workshop |
| **Load ammunition** (later, once buying gets hard) | Rhythm minigame on the hand press | The first thing you'll teach a recruit to do |

**Workstations you buy later:**
- a press (ammo);
- a soldering station (radios, bugs);
- a printer you can trust (flyers, papers);
- a lathe (parts).

Each one adds a new bench view and a new job. Teach a recruit a job and it runs while you're at the laptop.

**Parts and materials** come from the plant's scrap bin (risky), the market (Ruslan "can find things"), and the shop on the laptop (leaves records as the rules tighten).

---

## 5. Build plan

- **T2a (now):**
  - placeholder garage models from Blender (`art/garage.blend` + `art/garage.glb`);
  - the 3D room with pixel rendering and lighting;
  - the four views;
  - the laptop zoom with the existing OS;
  - the notebook, sticky note, charger and lid as clickable objects.
- **T2b:** the bench minigames (Pavel's phone first, inside the Tuesday story), then Agnes's radio.
- **T2c:** room events (knock, Lena, the car outside, power cut).
