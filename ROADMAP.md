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

## M2 — A world you can walk in
- [ ] Third-person / diorama camera + character controller (touch stick + gamepad)
- [ ] Terrain: ridge falling to a curved shoreline; streets that follow the contour
- [ ] Painterly lake + shoreline; the lake waves back at 4:12
- [ ] Hand-built Pell Dentistry and Mags's home interiors
- [ ] Districts with distinct silhouettes (Lakefront, Main St, Chapel Hill, Orchard Lane, Dam Road)
- [ ] Fast travel (bike / the *Mercy Ann*)
- [ ] NPC schedules and idle lives (data-driven)

## M3 — Act I content (Days 2–5)
- [ ] Day 2 Jo: rhythm vignette + Reply Tape (S20), home, conversations
- [ ] Day 3 Tobi: small-paths camera, Honesty Pull, eavesdrop, home, conversations
- [ ] Day 4 Delphine: speech vignette, vault (S16 / S17), conversations
- [ ] Day 5 Vern: radio vignette, the Reel, Hymn #212 (Act I climax)
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
