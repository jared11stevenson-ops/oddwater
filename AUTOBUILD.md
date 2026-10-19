# Autonomous build — instructions for the hourly run

You are continuing UNDERSTUDY, a single-player, offline narrative mystery game in **Godot 4.7 (GDScript)**. Read `02-gdd/00-lore-loop-charter.md`, `02-gdd/02-investigation-psyop-sim-charter.md` (the current design direction: homicide-style investigation, psychological horror/psyops, Sims-depth simulation) and `ROADMAP.md` first. Canon is in `01-lore-bible/`. Quality bar: Nintendo first-party polish and a Switch-class performance budget (the *standard*, not a port target: there is no Switch release), 4K-capable, shipping on mobile (iOS/Android), accessible, cozy and funny on top, grief underneath.

## One run = one increment
1. **Set up** (the container is fresh each time):
   - Attach the repo if it is not present (`add_repo` for `jared11stevenson-ops/oddwater`, push access) and clone it to `/home/user/oddwater` (one clone, generous timeout).
   - Install Godot 4.7: `mkdir -p /opt/godot && cd /opt/godot && curl -sSL -o g.zip "https://downloads.godotengine.org/?version=4.7&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" && unzip -oq g.zip && ln -sf /opt/godot/Godot_v4.7-stable_linux.x86_64 /usr/local/bin/godot`
   - Import once: `godot --headless --path game --import`
2. **Baseline**: run `game/tests/run_all.sh` (it syntax-checks every script with `--check-only`, then runs every suite with a hard timeout). NOTE: a GDScript parse error makes a headless `-s` run HANG instead of failing, so always syntax-check first. If anything fails before you start, fixing it IS this run's increment.
3. **Pick** the first unchecked item in `ROADMAP.md`. If it is too big for one run, build its smallest valuable vertical slice and split the item into sub-items.
4. **Build it** properly: data-driven (JSON under `game/data/`), logic in `scripts/core/` (engine-independent, unit-testable), presentation in `scripts/ui|art/`. Match surrounding code style. Write tests for every new rule.
5. **Verify**: run all suites. For anything visual, render with `xvfb-run -a godot --path game --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1920x1080 ...` and **look at the screenshot**; fix what looks wrong. Never claim a visual works without looking.
6. **Document**: tick/split the roadmap item, add one line to its Change log, update `game/README.md` status if a capability changed.
7. **Commit and push to `main`** (small, descriptive message). Only push if all suites pass. Do not force-push. Do not open PRs.

## Rules
- Single-player and offline only. No accounts, telemetry, ads or live service.
- Be honest in commit messages and docs: say what was verified and what was not. Do not claim device performance or final-art quality you have not demonstrated.
- Do not rewrite canon in `01-lore-bible/`. Additive notes only; if the build needs a lore decision, write the question in `NOTES-FOR-USER.md` and carry on with the safest default.
- No new dependencies, binary asset downloads or network calls beyond the Godot download above. Never commit secrets. Generated assets must be original (no copied art, music or fonts).
- Keep the repo small: do not commit `.godot/`, screenshots larger than ~1 MB, or build outputs. Reference renders go in `03-art/reference/` only when they document a milestone.
- If blocked (failing environment, ambiguous requirement), do the safest useful smaller thing, record the blocker in `NOTES-FOR-USER.md`, and stop. Never loop retrying.
- Stop early if the roadmap's remaining items all need humans (see "Not achievable autonomously"): write a status summary to `NOTES-FOR-USER.md` and do nothing else.
- Budget: one focused increment of roughly 5–20 minutes of work. Prefer depth and correctness over breadth.
