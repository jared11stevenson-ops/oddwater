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

## Status (pass 3)
**Days 1, 2 and 3 are playable end to end**, each driven by `data/days.json`: Wake & Snoop -> Perform (conversations, vignettes) -> Step Off (Remnant) -> Night (search + event) -> Case Board -> the 4:12 Slack -> next day.
- Day 1 Mags: dental X-ray overlay (S25), ledger (S23)
- Day 2 Jo: two-lane rhythm gig; the Reply at the Grange basement (S20)
- Day 3 Tobi: Honesty Pull in dialogue; Small Paths eavesdropping; Playhouse Prompt Book (S29)
- A **robot player** (`tests/bot.gd`) plays Days 1-3 through the real UI in `tests/smoke.gd`.
Tests: `run_tests` 101, `dialogue_tests` 48, `dental_tests` 23, `board_tests` 13, `rhythm_tests` 11, `day23_tests` 187, `town_tests` 9,653, `smoke`.
Next: Day 4 Delphine (speech vignette, vault: S16 / S17), Day 5 Vern (radio, Hymn #212: the Act I climax), spatial Case Board, walkable world.
Known: screens are functional menus with a shared ink/paper theme; no portraits, audio or walkable world yet; Slack is a text placeholder; nothing profiled on a device.

## Platform notes (honest)
- **Shipping target: mobile (iOS/Android). There is no Switch port.** Switch is only the quality and performance standard we hold ourselves to (Switch-class budgets: ~30 fps locked equivalent, tight memory).
- 4K: the UI is authored at 1920×1080 with `canvas_items` stretch, so it renders crisp at 3840×2160. 3D target budgets are in `02-gdd/01-core-systems-spec.md`.
- Nothing has been profiled on device yet; frame-rate targets (Switch-class budget; mobile 60 fps) are unverified.
