# The main attraction: how we show the fights (research, 2026-11-22)

*The user's prompt: in Iron Nest you never see the round land. You see something tracking it, you hear it, and then you get an updated recon photo of the damage. That's one angle. Look at what we CAN do before committing. Also still torn: going places in person and doing exploits, versus commanding your people. If going in person becomes an FPS, what is the other combat for? Maybe your people are watched through helmet cams. Nothing here is decided.*

---

## 1. What we already know we want
- You're in charge. You start alone (Antistasi) and the army grows. If you die, the run is over, which is the pressure to recruit (user, 2026-11-22).
- Fights run on their own with 2 or 3 call-ins (DRIVE, decided). Doctrine and the breach plan are the setup the user liked in the combat prototype.
- Everything you make should be a multiplier somewhere else (DRIVE section 2).
- One tactical engine for every mission type (CLAUDE.md rule 3). The prototype (`tactical/watch/`: room graph, squad brain) already resolves a fight.

## 2. The ways other games show a fight

| Angle | Who does it | What you see | How it landed | Cost for us |
|---|---|---|---|---|
| **A. Instruments only** | Iron Nest, Radio Commander, Radio General | A map with tokens, radio voices, sounds, a recon photo after | Iron Nest: Overwhelmingly Positive, but "repetitive" is the common complaint. Radio Commander: Mostly Positive, "not for people who just want to move counters". Radio General: Very Positive, small | **Lowest.** No animated people at all |
| **B. Feeds on a wall** | The Operator (desk work, Very Positive ~5,800), Drone Perspective (EA), Duskers (drone cams) | Grainy camera feeds from each fighter or drone, plus a map | The Operator proved desk-only work can be as gripping as being there; its runtime is short | **Highest.** Needs animated 3D fighters, though our dither hides a lot |
| **C. Top-down, plan then watch** | Door Kickers 2 (Overwhelmingly Positive, ~12k reviews), Frozen Synapse | The whole building from above, little soldiers executing your plan | The proven crowd-pleaser in this exact genre (CQB) | **Medium.** Our prototype already does this |
| **D. Deploy, then watch an auto-battle** | Mechabellum (Very Positive, ~17k), Just King, Super Auto Pets | Set up, press go, watch it play out, no control | The build is the game; the watching is the payoff | **Medium** |
| **E. Sound first** | Unheard (OpenCritic 73) | Nothing but audio; you work out what happened | Loved idea, thin as a whole game | **Low.** Works as one piece, not the whole fight |
| **F. You, in person (FPS)** | Ready or Not, bodycam shooters | First person, your own gun | Huge genre, huge cost, and it makes A to D pointless | **Very high.** The user's worry is right |

Highfleet is worth noting for the strategy map: you find enemies by radio intercepts, radar and recon, and visual contact is the last resort. Knowing where the enemy is gets earned.

## 3. The angle Claude would take: the view is gear (layered by progression)
Don't choose one presentation. **The fight is always the same simulation; what you can SEE of it depends on what you've built, hacked and recruited.** The view upgrades as the movement grows, and that upgrade is itself progression, a multiplier you earn:

1. **Alone (week 1):** you go in person, but it's never a shootout. Going out is hands-on scenes like the benches: pick a lock, plant a device, photograph a ledger. If it turns violent, you run, or you're caught. You dying ends the run.
2. **First cell:** you can't be there, so you sit at the radio or phone with a paper map. You only hear them and push tokens yourself (Radio Commander), plus sound. Cheap, and very tense.
3. **Things you make add views,** and each one is a bench item or a hack:
   - **Helmet cams** from the hacking bench: the camera's star rating sets the feed quality (fps, noise, range). A 1-star cam is a stuttering mess; a 5-star one is clear.
   - **A drone** gives the top-down view (angle C, the prototype).
   - **A hacked city camera or a stolen satellite pass** (hacking) gives the Iron Nest before and after photo.
   - **More radios and signals gear** give more call-ins.
4. **The war room (late):** a map table for big ops with several squads, tracking lines, sounds and after-photos (Iron Nest at army scale). Routine ops resolve off screen with a report (already decided).

**Why this fits:**
- Fog of war becomes gear: everything you make is a multiplier, and here the multiplier is information.
- It answers the in-person worry: you go in person to do the exploits (scenes, not shooting), and your people do the fighting.
- It's cheap to start: angle A needs no animation, so we can have a full loop soon and add the expensive views later.
- One engine underneath, many windows on top.

## 4. What it would cost to try
- **A first prototype of the cheap end** (radio + map + sound + an after-photo): one op, three fighters, run by the existing room-graph sim, shown only as radio lines, map tokens and sounds. About one build.
- **Then the helmet-cam wall** on the same op, reusing `tactical/watch/watch_cams.gd` in the dither look, so you can compare the two side by side.

## 5. Questions for the user (to talk through, not yet decided)
1. Does "the view is gear" feel right, or should one presentation be THE game?
2. Going in person: hands-on scenes with no shooting (you run or get caught), or do you want to be able to fight yourself sometimes?
3. You die = run over: a full restart, or does the movement carry on under someone else (a legacy, like Ball x Pit's base surviving a bad run)?
4. During a fight: just watch, 2 or 3 call-ins (decided), or more?

## Sources
- [Iron Nest review (PCGamesN)](https://www.pcgamesn.com/iron-nest-heavy-turret-simulator/review), [OpenCritic](https://opencritic.com/game/21129/iron-nest-heavy-turret-simulator), [Steam](https://store.steampowered.com/app/2950790/IRON_NEST/)
- [Radio Commander (Steam)](https://store.steampowered.com/app/871530), [Kotaku](https://kotaku.com/radio-commander-a-strategy-game-where-you-just-talk-on-1843234907), [GameGrin](https://www.gamegrin.com/reviews/radio-commander-review), [Vice](https://www.vice.com/en/article/radio-commander-review/)
- [Radio General (Steam)](https://store.steampowered.com/app/1011610/), [Common Sense Media](https://www.commonsense.org/education/reviews/radio-general)
- [The Operator (Steam)](https://store.steampowered.com/app/1771980), [God is a Geek](https://www.godisageek.com/reviews/the-operator-review/), [GOG](https://www.gog.com/game/the_operator)
- [Drone Perspective (Steam)](https://store.steampowered.com/app/2730700), [Duskers (Wikipedia)](https://en.wikipedia.org/wiki/Duskers)
- [Door Kickers 2 (Steam)](https://store.steampowered.com/app/1239080), [PC Gamer](https://www.pcgamer.com/au/door-kickers-2/), [Notebookcheck](https://www.notebookcheck.net/Ridiculously-fun-tactical-online-co-op-shooter-hits-Steam-charts-with-Overwhelmingly-Positive-reviews.959266.0.html)
- [Mechabellum (Wikipedia)](https://en.wikipedia.org/wiki/Mechabellum), [Steam](https://store.steampowered.com/app/669330/Mechabellum)
- [Unheard (PC Gamer)](https://www.pcgamer.com/this-new-detective-game-is-all-about-listening-to-solve-mysteries/), [OpenCritic](https://opencritic.com/game/7589/Unheard)
- [Highfleet intel guide (Cultured Vultures)](https://culturedvultures.com/?p=161087), [gameplay.tips](https://gameplay.tips/guides/12027-highfleet.html)
- Iron Nest's "you never see the round, then a recon photo" detail is from the user's own play. The search didn't confirm it beyond "recon photos over the topography".
