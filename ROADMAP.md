# UNDERSTUDY — Build Roadmap

The hourly autonomous build takes the **first unchecked item** below, ships one small, tested, verified increment, ticks it off (or splits it), and pushes. Order matters: each milestone makes the next one playable.

Legend: `[ ]` todo · `[x]` done · `[~]` partly done (see note)

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

## M1.4 — Gameplay-first redesign (design: `02-gdd/03-gameplay-first-design.md`, supersedes the lore-led charters)
- [x] The Cause and STEER: nightly host choice from restlessness plus relative priority; comfort/unsettle night actions; observable tells; authored order holds over 20 seeds, two nudges steer (21 checks); host-by-life flow; Long Night screen
- [ ] The reactivity layer: conversations read the sim (memories, believed rumours, mood, money) so the town brings up what you did, in any body
- [ ] Case file: Pattern grid (host history x restlessness / last visitor / place), timeline, access chain, theory; predict tomorrow's host twice to prove the Rule
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
