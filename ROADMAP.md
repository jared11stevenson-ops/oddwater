# UNDERSTUDY — Build Roadmap

The hourly autonomous build takes the **first unchecked item** below, ships one small, tested, verified increment, ticks it off (or splits it), and pushes. Order matters: each milestone makes the next one playable.

Legend: `[ ]` todo · `[x]` done · `[~]` partly done (see note)

## PRIORITY NOW — the Town Sim (no lore until the sim is great; direction from the user, 2026-10-20)
The product comes first as a Sims-like town you play from inside: a town 2x South Park's size, every resident a possible body-swap host, every resident living a similar-but-different life. The lore/story layers are parked; they return "way later". Design of record: `02-gdd/04-town-sim.md`.
- [x] Everyday population: ~217 residents in households (singles, couples, families, roommates, elders), ages, jobs at the real workplaces, days off, hobbies, haunts, quirks, relationships (`sim/population.gd`, 20 checks)
- [x] Weekdays and weekends; shift-based work and school; haunts and hobbies drive where people spend their free time
- [x] Body swap for ANY resident: briefing on waking (`sim/brief.gd`), the Cause in open mode (restlessness + noise + cooldown), steering with Calm/Scare visits, the Lives report (`sim/town_game.gd`, 31 checks)
- [x] Talking (`sim/talk.gd`): 8 topics, answers shaped by relationship, mood, needs, job, hobby; reactions to what you did in earlier bodies
- [x] Town screen (`ui/town_sim_ui.gd`, `ui/town_map.gd`): live map (pan/zoom/tap, people walk between places), time, needs, actions, people here, big moves, night, morning card; 1280x720 phone-sized canvas (43 UI robot checks)
- [x] Persistence (`TownGame.save/load_game`, 13 checks): the whole town, host history, wishes and news; atomic writes; autosave at night, dawn, menu and app pause; Continue on the title; a loaded game continues exactly like the original
- [x] Sims depth pass 1 (`sim/wishes.gd`, `sim/relationship.gd`, weather and weekly rhythm; 21 checks): three personal wishes a day with rewards and a printed end-of-day report; relationship stages and family roles; deterministic weather (clear/cloudy/rain/fog) that changes where people go; Saturday market on the green, Sunday church; rain/fog/stalls/walking bob on the map
- [ ] Sims depth, next: multi-step travel visible on the map, per-person daily schedule view, houses with rooms/objects, cooking/shopping/bills, jobs and promotions, relationships with stages (friend/crush/partner/rival), births/ageing/deaths over time, weather, town events (festival, market day)
- [ ] The swap, perfected: a first-swap sequence that feels good, a persistent "you" (name, voice) across bodies, host handover animation, per-host goals/wishes (Sims-style) with rewards, a journal of every life
- [ ] Performance: profile the town on a mid-range phone; spatial hashing for interactions; ~400 residents
- [x] Art pass 1 (see `03-art/00-art-direction.md`): procedural portraits for every resident, inked map with roofs/shadows/lake wash, day-night light and lit windows, print pass, Bangers + Lora UI as a printed page, speech balloons (22 checks)
- [ ] Art pass 2: distinct landmark silhouettes, walk animation on twos, interiors, weather, audio, event lettering
- [ ] Then, later: re-introduce the story layers (Cause, Case Board, lore) on top of the sim

## PRIORITY NOW — Little Mercy: a detective RPG (direction from the user, 2026-10-20)
You are the lead and only detective of Little Mercy; the town is riddled with strange murders, conspiracies, paranormal activity and cults. Everything built so far is the base. Design of record: `02-gdd/05-detective-rpg.md` (the living town is the crime's ground truth: real alibis, fair deduction, people who lie for reasons, an RPG that gates perception not progress).
- [x] 1. Sim history + night record + death (real alibis; `SimWorld.where_was/who_was_at`, 10 checks)
- [x] 2. Case engine (`scripts/detective/case_engine.gd`, `case_ops.gd`, `detective.gd`; 110 checks): picks a victim/killer/motive from the real relationships, writes the past into the sim, decides the night, builds clues/witnesses/lies; a solver bot cracks 24/24 generated cases, a lazy one 0/24; 5 motives, 4 methods, home/work scenes; RPG gates (skills, stress, warrants, lab, XP)
- [x] 3. Detective state and `DetectiveGame` (fixed host, a murder already waiting on Day 1, saves; 16 checks)
- [x] 4. 3D integration (`ui/detective_hud.gd`, 22 robot checks): crime-scene marker (tape and beam), scene examination menu, notebook, interrogation (alibi/victim/who/saw/where was.../show them.../be friendly), lab, warrants, search, people tab, accusation and verdict, your sheet (skills, stress, XP), objective tracker, nights and mornings, continue
- [~] 4b. Procedure and justice (done: CCTV with doorbell cameras and clock offsets, fingerprints with gloves, partials and false matches, samples and refusals, families who cover for their own and break under footage, 'tell me about...', the storytelling layer: cold open, the detail that didn't fit, interludes, episode archive; plus arrest with probable cause, the interview room (rapport/evidence/pressure) with true and false confessions, the trial (defence attacks, uncleared suspects, unreliable evidence, uncalibrated cameras), the jail and the Gallery with visits, lore from inmates, and appeals for the wrongly convicted; 18 checks. To do: informants, plea deals, more crime types) (`02-gdd/06-procedure-and-justice.md`): CCTV, fingerprints (with gloves, quality and false matches), interrogating neighbours/connections/family (families cover for their own), formal interrogation with held-back details and false confessions, arrest/custody/charge/trial (chain of custody, alternate suspects), the jail and the Gallery of convicted suspects, informants, appeals
- [~] 5. Escalation and reputation (done: one reputation ledger, serial killers with unique signatures, the Courier and a pressure meter with a deadline, the accusation pipeline with three accusations and escalating costs, cold cases, town business, voice banks, newcomers, misdirection, the horror layer, false confessors who the held-back test exposes). To do: cult case; lake case; the overarching conspiracy; more crime types
- [~] 6. HUD, tutorial and polish (done: objective tracker with costs, notebook, people, lab, jail and the Gallery, the paper, a first-case tutorial overlay, window lights that follow who is home). To do: office and upgrades; interiors for scenes

## PRIORITY NOW — 3D (direction from the user, 2026-10-20)
The game is **3D**, graphics standard **Peak** (stylised, saturated, soft-lit), characters are **normal humans**. This is the benchmark to get the full game running, not the final look. Design: `03-art/02-3d-direction.md`.
- [x] 3D pass 1 (`scripts/world3d/`, 27 robot checks): the whole town in 3D (houses, landmarks, park, lake, hills, forest), sky/sun/moon/weather, 217 residents with bodies that walk the streets as the sim directs, you in the host's body (thumb stick, look pad, third-person camera), real-time clock, walk up to doors and people, enter buildings to act, talk, night and morning flow, save/continue
- [ ] 3D pass 2: interiors (room kits) and enter/leave transitions; sitting, sleeping, eating, working animations
- [ ] 3D pass 3: character polish (faces, hair, clothes), distinct landmark models, props, vehicles, foliage, clouds, birds
- [~] 3D pass 4: device performance. Done: the procedural town is baked into chunked meshes and multimeshes with draw-distance budgets, pooled lamp lights, cheap window lights (a top-down home map repainted each half hour, no per-frame cost), a capped crowd with no per-person process. To do: profile on a real device (S25), occlusion, resolution scale, load time
- [ ] 3D pass 5: the sim in the world: visible daily lives (people actually work, eat, sleep inside), crowd events (market, church), houses with owners' belongings, reactions to what you do in sight of others

### Detective RPG: status and what remains (2026-10-20)
Done and tested: serial killers with unique signatures; news and pressure with a deadline; the accusation pipeline (3 accusations); false confessors (wrong details, exposed by the held-back test, a wrongful conviction costs reputation and the killer strikes again); cold cases; town business; voice banks; newcomers; misdirection; the horror layer; the new HUD and tutorial; the procedural 3D town; window lights tied to who is home.
Remaining, honestly:
- [ ] Cult and lake case strata and the 1961 conspiracy as real cases (today they are lore lines and one stopped-clock detail)
- [ ] Informants, plea deals, custody clock, chain-of-custody exclusion, more crime types
- [ ] Office and upgrades; interiors for crime scenes
- [ ] Audio and narrated episodes (the cold open and episodes are text only)
- [ ] Device profiling and a playtest pass for tuning (pressure, confessor frequency, reputation costs)
- [ ] Art: distinct landmark models, character polish, weather beyond the sky and rain
Note: the legacy body-swap/Understudy milestones below are parked, not abandoned.

## M0 — Foundations (done)
- [x] Lore bible, cast, relationship web (`01-lore-bible/`)
- [x] Lore–loop charter, 40 Seals, abilities, core systems spec (`02-gdd/`)
- [x] Godot 4.7 project, data-driven core, 101 + 48 + 9,653 headless checks
- [x] Wake & Snoop (Day 1), Perform dialogue, Silas / Bea / Cal conversations
- [x] Ink & Odd Water shaders, style lab, town layout at 2x+ scale

## M1 — Day 1 fully playable (one complete loop)
- [~] Dental vignette: X-ray overlay Proof Tool done (sets S25, playable in Day 1 flow, shared paper/ink UI theme). Still to do: steady-hand drill UI (core `steadiness.gd` is done and tested), S23 via the Amos ledger
- [x] Seal Test flow: board lists testable seals; the test passes when the right tool exists, evidence is pinned and the strings join it (S23, S25 proven in Day 1). Model piece placement still to do
- [~] Case Board UI: cards, pins, ties, visible list of strings, Seal tests (functional, list-style). Still to do: a true spatial board with drawn strings and drag
- [~] Night phase: Pell Dentistry after hours (8 searchable items, 3 evidence). Still to do: eavesdrop, 4 more locations, being seen by the Awakened
- [~] The Slack (4:12): text sequence, tomorrow's face revealed last. Placeholder presentation (black screen); needs art, bell audio and the lake waving back
- [ ] Save/load UI and autosave at each dusk
- [x] Day 1 → Day 2 transition with the Notes card ("what you left behind"); Day 2 home for Jo is the next build

## M1.3 — Your own first day (design: `02-gdd/03-gameplay-first-design.md` §1b)
- [x] Character creator (name, pronouns, speaking style, catchphrase); persona consistent across every body
- [x] Dialogue modes: `[You]` (your voice, costs an eyebrow vs the host's style) vs `[As host]` (cover, erodes your self); drift reworked around cover vs self
- [x] Day 1 tutorial in your own body: home, 3 conversations, photograph, free time, the Decision, the 3 a.m. ribbon-and-clock night; your body is Taken at 4:12, no Remnant
- [x] Nine fair-play foreshadow beats, tested present and tested un-named
- [x] Watch the street (Long Night): see the ribbon tied on tomorrow's host's door, too late to change it
- [ ] Day 1 art pass: your home, neighbours, a real morning (menus now)
- [ ] The first swap scene (cinematic) and a short "what just happened" beat that doesn't explain
- [ ] A visible portrait of YOUR character in every UI (so you always know who you are)
- [ ] Recognise-yourself clues: your own house, notebook and cat, found as another host (your body's trail)

## M1.4 — Gameplay-first redesign (design: `02-gdd/03-gameplay-first-design.md`, supersedes the lore-led charters)
- [x] The Cause and STEER: nightly host choice from restlessness plus relative priority; comfort/unsettle night actions; observable tells; authored order holds over 20 seeds, two nudges steer (21 checks); host-by-life flow; Long Night screen
- [x] The reactivity layer (`core/reactions.gd`, `data/reactions.json`, 14 checks): people open by bringing up what the host did to them or in front of them (theft, insult, gift), rumours they believe, gossip, friends who are gone, mood and money; suspicion shifts with it. A different body is not blamed for the theft, but the rumour follows
- [x] Case file, part 1 (`core/casefile.gd`, 16 checks + smoke): Pattern grid on the Board (who was taken, on the edge the night before?, decision found in their home?, ribbon seen?); guess tomorrow's host on the Long Night; two EARNED hits (the person was visibly on the edge) prove the Rule and unlock a forecast of the Cause's order; saved
- [ ] Case file, part 2: per-victim timeline, access chain, theory/accusation
- [ ] Night visits to past lives and the end-of-run Reckoning (long-arc payoff for the sandbox player)
- [ ] Body search: access chain and the Visit; the body's condition worsens as a clue
- [ ] Confrontation puzzle that uses the sim; endings: Long Day / Home / Case Closed / Cost / Settled
- [ ] Eligibility: every simulated person becomes a possible host as days are authored (currently 5)

## M1.5 — The investigation, the psyop and the sim (design: `02-gdd/02-investigation-psyop-sim-charter.md`)
- [x] Sim kernel: 28 people, needs, schedules/autonomy, relationships, money, memory, rumours, restlessness, Decision/Strike, Gazette vs ledger (66 checks)
- [x] Claims you can contradict with evidence from any body; "Show them something..." in conversation (6 claims)
- [x] Evidence tampering: the Hush edits cards at dawn (targets what your unsealed Seals need); photographs in the Notebook; corrupt cards fail their Seals
- [x] Drift (comfort is the trap), Alignment, Notoriety; the Prompter's lures vs Wren's truths; friendly drift label
- [x] The Briefing (the false goal); Free Time (Sims-style actions incl. irrevocable Decisions); Town Report at dusk
- [ ] Case file structure: per-victim timeline reconstruction and means/motive/opportunity grid; naming a suspect
- [ ] Planted evidence with provenance (who left it, who gains); the four propaganda streams in play
- [ ] The Room 9 trap (Lakeview Rest): the offered body; the Settling ending; its reveal
- [ ] Sim depth: ~120 people (ambient walk-ons), jobs and wages, shops open/closed, weather, events, houses; sim state saved
- [ ] Walk-on tells emerging from the sim (hums, damp cuffs) rather than scripted
- [ ] Sim-driven Day content: consequences of your free-time acts (theft discovered, quarrels, rumour fallout) shown in later days' conversations
- [ ] Drift tuning against a 15-day run; Settling threshold

## M2 — A world you can walk in
- [ ] Third-person / diorama camera + character controller (touch stick + gamepad)
- [ ] Terrain: ridge falling to a curved shoreline; streets that follow the contour
- [ ] Painterly lake + shoreline; the lake waves back at 4:12
- [ ] Hand-built Pell Dentistry and Mags's home interiors
- [ ] Districts with distinct silhouettes (Lakefront, Main St, Chapel Hill, Orchard Lane, Dam Road)
- [ ] Fast travel (bike / the *Mercy Ann*)
- [ ] NPC schedules and idle lives (data-driven)

## M3 — Act I content (Days 2–5)
- [x] Day 2 Jo: home, 3 conversations (Daniel, Lux, Fitz), two-lane rhythm gig, the Reply (S20) in the Grange basement at night
- [~] Day 3 Tobi: home, 3 conversations (Adaeze, Ms. Calloway, Roy), Honesty Pull, Small Paths eavesdrop, Playhouse night (Prompt Book, S29). Still to do: child-height camera and walkable paths (it's menu-based now)
- [x] Day 4 Delphine: home, 3 conversations (June, Hank, Harlan), Town Hall speech vignette (three crowd groups, resignation flag), Town Hall vault at night (S16, S17)
- [x] Day 5 Vern: home, conversations (Dolores, Silas), Dedication Hour (spells FAIR WATER, S12), WMRC archive at night (S21, S22), the Hymn #212 choice with consequences (Act I climax)
- [ ] Encore days: Remnants run their old tools (Overlap)
- [ ] Slice ending: S30 reveal (Day 1 was a casting call)

## M4 — Art pass
- [ ] Neutral-expression face set + 6 body silhouettes + hair kit
- [ ] Portrait system for dialogue; comic-panel framing and cutscene framework
- [ ] Lighting by time of day; weather driven by town mood
- [ ] Understudy "wet line" and Tell Sight rendering
- [ ] Props / foliage kits; the Model (diorama of Low Mercy) in the Prop Room

## M5 — Audio
- [ ] Adaptive music system (layered stems, detune/underwater layers rise with `truth`)
- [ ] Placeholder synthesised score + SFX generated in code; hook points for final assets
- [ ] The 4:12 bell, lake ambience, per-location soundscape
- [ ] Haptics map

## M6 — Acts II and III (Days 6–15)
- [ ] Days 6–10 (Gus, Priya, Marcus, Billie, Inez): homes, vignettes, conversations
- [ ] Days 11–13 (Dottie, Oren, Ellis)
- [ ] Day 14 Prop Room; Day 15 the Raising (four endings)
- [ ] Fragments LF-001…090 authored and placed; 30 cross-references wired
- [ ] New Run (offline New Game+)

## M7 — Product systems
- [ ] Settings: text scale, colourblind modes, timer scale, subtitles, haptics, reduced motion
- [ ] Localisation pipeline (string tables, VO-ready script export)
- [ ] Input rebinding; touch and Joy-Con layouts verified
- [ ] Pause / title / chapter select / photo mode

## M8 — Performance and release
- [ ] Profiling scripts and frame-time budget tests (Switch-class budget as the bar; mobile 60 fps target)
- [ ] LOD / streaming per district
- [ ] Export presets (Android, iOS); CI that runs every suite
- [ ] Release checklist for iOS and Android stores (**needs developer accounts: human step**)

## Not achievable autonomously (tracked, not forgotten)
- Final hand-drawn/modelled art, professional VO and a composed score: need artists, actors, composers. The build produces placeholders and clean hook points.
- Real-device profiling and certification: needs hardware and platform accounts.
- Store submission: needs Apple and Google developer accounts.
- Playtesting with real players.

## Change log
(Each autonomous run appends one line: date, what shipped, test counts.)
- 2026-10-19: Dental overlay Proof Tool + shared UI theme; Day 1 plays waking -> dialogue -> overlay -> Seal S25 -> dusk. Suites: core 101, dialogue 48, dental 23, town 9653, smoke OK.
- 2026-10-19: Night, Case Board, Seal tests, the Slack; Day 1 loop playable end to end (S23, S25). Suites: core 101, dialogue 48, dental 23, board 13, town 9653, smoke OK.
- 2026-10-19: Data-driven days (days.json); Days 2 and 3 playable; rhythm game, eavesdrop, Honesty Pull; robot-player smoke test plays Days 1-3 through the real UI. Suites: core 101, dialogue 48, dental 23, board 13, rhythm 11, day23 187, town 9653, smoke OK. Note: S30 (Day 1 was staged) is provable from Day 3 by tying the appointment book to the Prompt Book. Decide whether to gate it later.
- 2026-10-19: Act I complete (Days 1-5): speech, radio, vault, Hymn choice; 11 seals reachable by Day 6 in the robot run. Suites: core 101, dialogue 48, dental 23, board 13, rhythm 11, day23 277, day45 29, town 9653, smoke OK. Fixed dark-on-dark text contrast on radio and night screens. Known: night search screens are a bare scatter of buttons; the Hymn's consequences (mood, suspicion, Slack text) exist but no Awakened NPC behaviour yet.
- 2026-10-19: M1.5 started: sim kernel, claims, evidence tampering, drift/hints, Briefing, free time, Gazette. Suites (10): core 101, dialogue 48, dental 23, board 13, rhythm 11, day23 278, day45 29, sim 66, investigation 55, town 9653, smoke OK (careful vs careless vs comfortable bots). New runner: `game/tests/run_all.sh` (syntax-checks every script first: a script parse error makes headless runs HANG, not fail).
- 2026-10-19: Gameplay-first redesign: STEER (the Cause, Long Night). Lore is an idea bank until gameplay is honed. Suites (11): + cause 21. Found: bounded levers are good (two deliberate nudges steer, one never does); priority must be relative to who's left; sim restlessness needed overnight relief to produce observable tells.
- 2026-10-19: Day 1 is now your own created character in your own body; persona and dialogue modes; tutorial with nine foreshadow beats; all days shifted by one (Day 2 = first host). Suites (13): + persona 23, tutorial 1217; smoke plays tutorial + Act I with careful/careless/comfortable/steering bots. Bug caught by the robot: 'any' proof tool was being switched off.

- **Serial killers (done):** rare (~12% of cases), careful (gloves ~88%, no family cover, no neighbour witness, forced window), same sign at every scene, strike every 2-3 nights until caught. After the third death: the Courier front pages, radio, letters, a pressure meter (reputation drain, deadline 8 days, then the state police take over). Catching them resets the meter with a big reputation/XP payoff. See `scripts/detective/serial.gd`, `news.gd`, `tests/serial_tests.gd`.
- **Serial rarity and a growing town (done):** serial killers are ~1 in 50, each with a unique signature (a lone folded sock, a nine of clubs...) and nickname. Two days after a case is fully solved a new resident moves into the emptiest house with their own job, hobby, quirk and ties (saved with the game).
- 2026-10-20: False confessors (`detective/confessor.gd`, `data/detective/confessors.json`, `tests/confessor_tests.gd`, 31 checks) exposed by the held-back detail test; fixed trial adjustments being dropped (lambda by value); window lights follow who is home (`window3d.gdshader` home map, 8 new world_polish checks); GDD 05 and 06 and this roadmap brought up to date.
