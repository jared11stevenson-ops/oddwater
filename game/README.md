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

## Status (pass 4)
**Act I (Days 1-5) is playable end to end**, each day driven by `data/days.json`.
- Day 1 Mags: dental X-ray overlay (S25), ledger (S23)
- Day 2 Jo: two-lane rhythm gig; the Reply (S20)
- Day 3 Tobi: Honesty Pull; Small Paths eavesdropping; Prompt Book (S29)
- Day 4 Delphine: Town Hall speech (reading three crowd groups); the vault (S16, S17)
- Day 5 Vern: Dedication Hour (S12), WMRC archive (S21, S22), the Hymn #212 choice (Act I climax)
- A **robot player** (`tests/bot.gd`) plays Days 1-5 through the real UI in `tests/smoke.gd`.
Tests (9 suites): core 101, dialogue 48, dental 23, board 13, rhythm 11, day23 277, day45 29, town 9,653, smoke.
Next: Act I polish (Awakened NPC reactions to the Hymn; Encore days / Overlap), the S30 reveal gate, spatial Case Board, walkable world, Day 6 Gus onward.
Known: functional menu screens with a shared ink/paper theme; no portraits, audio or walkable world; Slack is a text placeholder; nothing profiled on a device.

## Platform notes (honest)
- **Shipping target: mobile (iOS/Android). There is no Switch port.** Switch is only the quality and performance standard we hold ourselves to (Switch-class budgets: ~30 fps locked equivalent, tight memory).
- 4K: the UI is authored at 1920×1080 with `canvas_items` stretch, so it renders crisp at 3840×2160. 3D target budgets are in `02-gdd/01-core-systems-spec.md`.
- Nothing has been profiled on device yet; frame-rate targets (Switch-class budget; mobile 60 fps) are unverified.
