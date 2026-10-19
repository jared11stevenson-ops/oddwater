# UNDERSTUDY — Godot project

Engine: **Godot 4.7 stable** (GDScript), Mobile renderer. Single-player, offline.

## Run
- Editor: open `game/project.godot`.
- Tests (headless):
  - `godot --headless --path game -s tests/run_tests.gd` — simulation core (101 checks)
  - `godot --headless --path game -s tests/smoke.gd` — boots the real scene and plays Wake & Snoop

## Layout
- `data/` — all tuning and content as JSON (40 seals, 13 lives + Prop Room, abilities, endings, tuning, homes)
- `scripts/core/` — engine-independent logic: Notes, CaseBoard (evidence → pins → links → seals → abilities), Suspicion, Remnants, GameState (day/phase loop, Overlap, endings, save)
- `scripts/ui/` — presentation: title, Wake & Snoop
- `tests/` — headless suites

## Status (pass 7): your own first day
You create a character, play a normal Day 1 in your own body (breakfast, neighbours, a Notebook, a Decision), then at 4:12 wake up as someone else. Your voice stays yours in every body: each reply is either `[You]` (your own voice) or `[As <host>]` (cover). The tutorial plants nine fair-play clues without naming any (a test enforces both). Day 2 is the first host. Suites: 13 (`./tests/run_all.sh`).

## (pass 6) gameplay first
Design of record: `02-gdd/03-gameplay-first-design.md` (lore is an idea bank). New: **STEER**. Every night the Cause takes whoever is most ready to change (authored priority + the sim's restlessness). On the Long Night screen you can comfort or unsettle people: two deliberate nudges change tomorrow's host, one never does. The authored order holds when nobody interferes.

## (pass 5) investigation, psyop and sim
Design direction: `02-gdd/02-investigation-psyop-sim-charter.md`. You are told you are an outside investigator hunting your own body. That goal is a role (the Briefing). The town lies to you through four propaganda streams plus the Hush.
Built and tested:
- **Sim kernel** (`scripts/sim/`): 28 people with needs, routines, autonomy, relationships, money, memory, rumours and restlessness; a Remnant who Decides is Struck; the Gazette softens what the ledger records.
- **Claims and contradiction**: record what NPCs say; press them with evidence from any body.
- **Evidence tampering**: at dawn the Hush edits cards your unsealed Seals depend on; photograph cards into the Notebook; corrupt cards fail their Seals.
- **Drift** (comfort raises it, investigative progress lowers it), **Alignment**, **Notoriety**; the Prompter (calm, steering) vs Wren (true).
- **Free Time** (Sims-style actions incl. irrevocable Decisions) and the **Town Report** every dusk.
- Days 1-5 (Act I) from earlier passes still play end to end; a robot plays them as a careful detective, a careless one and a comfortable one and the results differ as designed.
Tests: `./tests/run_all.sh` (10 suites + syntax check of every script). A parse error makes a headless run hang, so always run the syntax check.
Not built yet: per-victim timeline and means/motive/opportunity grid; planted-evidence provenance; Room 9 / the Settling; sim at ~120 people; walkable world; audio; portraits. Nothing profiled on a device.

## Platform notes (honest)
- **Shipping target: mobile (iOS/Android). There is no Switch port.** Switch is only the quality and performance standard we hold ourselves to (Switch-class budgets: ~30 fps locked equivalent, tight memory).
- 4K: the UI is authored at 1920×1080 with `canvas_items` stretch, so it renders crisp at 3840×2160. 3D target budgets are in `02-gdd/01-core-systems-spec.md`.
- Nothing has been profiled on device yet; frame-rate targets (Switch-class budget; mobile 60 fps) are unverified.
