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

## Status (pass 2)
Done: core loop state machine, Seal/Ability economy, Remnant + Overlap, endings ladder, save/load; Wake & Snoop; **Perform** (data-driven dialogue with Notes/suspicion/evidence effects, Day 1 conversations: Silas, Bea, Cal); style shaders wired live to game state (`hush`, `truth`); UI sits above the print pass so text is never smeared; 2x+ town layout (spread out: 128 lots over ~595,000 m2).
Tests: `run_tests` 101, `dialogue_tests` 48, `town_tests` 9,653, `smoke` plays Day 1 from waking to dusk through the real UI.
Next: the dental vignette (X-ray overlay Proof Tool), Night + Case Board UI, the 4:12 Slack scene, terrain, hand-built Pell Dentistry.
Known: dialogue screen is functional but plain (no portraits or comic framing yet).

## Platform notes (honest)
- Godot does not ship Nintendo Switch export. Switch needs a licensed third-party port (e.g. W4 Games / Lone Wolf) and Nintendo developer-program access. Everything here is written to be portable; the Switch build is a later, external step.
- 4K: the UI is authored at 1920×1080 with `canvas_items` stretch, so it renders crisp at 3840×2160. 3D target budgets are in `02-gdd/01-core-systems-spec.md`.
- Nothing has been profiled on device yet; frame-rate targets (Switch 30 fps, mobile 60 fps) are unverified.
