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

## Status (pass 1)
Done: core loop state machine, Seal/Ability economy, Remnant + Overlap, endings ladder, save/load, playable Day 1 Wake & Snoop greybox (timer, Take Your Minute, large touch targets, focus navigation).
Next: Perform (dialogue + dental vignette), Night + Case Board UI, Slack scene, then 3D diorama art pass.

## Platform notes (honest)
- Godot does not ship Nintendo Switch export. Switch needs a licensed third-party port (e.g. W4 Games / Lone Wolf) and Nintendo developer-program access. Everything here is written to be portable; the Switch build is a later, external step.
- 4K: the UI is authored at 1920×1080 with `canvas_items` stretch, so it renders crisp at 3840×2160. 3D target budgets are in `02-gdd/01-core-systems-spec.md`.
- Nothing has been profiled on device yet; frame-rate targets (Switch 30 fps, mobile 60 fps) are unverified.
