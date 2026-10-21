# Knowledge architecture: the investigation must not know what the simulation knows

**Principle.** The murder simulation knows everything (who, why, how, when, where each person really was). The investigation system knows only what the detective has *observed or been told*, through channels that can be wrong, incomplete, or lying. If the investigation layer can read ground truth, the game is a scripted puzzle wearing a simulation's clothes. This document is the contract.

## Three layers, one-way flow

```
GROUND TRUTH  ->  TRACES & PERCEPTIONS  ->  KNOWLEDGE
(Truth, Ledger)   (emitters, filters)       (Notebook, theory)
      |                                            |
      +----------------- ADJUDICATION <------------+   (court only; the one place truth meets claims)
```

1. **Ground truth** (private): the real plan and the real night: killer, motive, method, weapon, the true movements (`sim.history`, `sim.night`), secrets of every suspect. Lives in `Truth` (stored on the game as `_truth`, never inside `game.case`). Only the *emitters*, the *perception filters* and the *adjudicator* may read it.
2. **Traces and perceptions** (the bridge): physical and social residue produced *by rules from what actually happened*: footprints exist because someone walked there in those shoes; prints exist because hands were bare; a witness reports only what a person at their real position, distance, light and attention could perceive, possibly mistaken (look-alikes, bad light, hazy memory) or false (their own secret, a grudge). Camera frames are sampled from real recorded positions with the camera's real clock offset. Records exist because transactions happened.
3. **Knowledge** (public): `game.case` is the *case file*: only what the Sheriff's call and the first scene give you (victim, place, time found, who found them). The notebook stores **observations**: `{source, channel, claim, certainty}` with no author-attached meaning. Meaning (does this tie X to the crime?) is derived by *rules of evidence* from the structured claim itself, never from a pre-written `supports` flag.

## Rules that keep it honest

- **R1. No truth in the case file.** `game.case` and everything the HUD/objective/narrator reads must contain no killer, motive, method, weapon location, suspect list, profiles, alibi kinds, clue supports or hidden flags. A test dumps it and fails if any appear.
- **R2. Claims, not conclusions.** Every observation is a structured claim: `{kind: seen|heard|found|recorded|said, subject, predicate, place, time, item, certainty, source}`. The notebook never says "this proves X".
- **R3. Proof is computed from claims by rules**, in one module (`Reasoning`): placing a person at the scene near the time of death is *opportunity*; an item a person owns at the scene is *link*; a quarrel is *motive*; a purchase is *means*; a verified elsewhere-claim is *exoneration*. Reliability discounts (weak light, hazy memory, a witness with a motive to lie). The same module serves the DA's qualitative advice ("this puts them there, but your witness saw them in the dark") without revealing truth.
- **R4. Truth enters only at adjudication.** Whether a claim is actually *true* is hidden in the claim's private `_truth_tag` (set by the perception filter at creation, stripped from anything the UI can read). The court uses it so that a mistaken witness can sink a case, and a false confession can convict the wrong person.
- **R5. Open candidates.** The detective may accuse *any* resident. "Persons of interest" are derived from the notebook (people named by claims, people you flagged), not from a generator-curated list. A killer is not guaranteed to be anyone you have met.
- **R6. Sources can be wrong.** Each channel (eyewitness, camera, forensics, records, confession, gossip) has its own error model. Lab results can be inconclusive; cameras have drift; witnesses mix up look-alikes; the same person can be seen twice and counted twice.
- **R7. Pressure and objectives use only knowledge.** `objective()` and hints derive from the notebook and case file; they never peek at truth to point the way.
- **R8. The firewall is tested.** `tests/firewall_tests.gd` (a) dumps `game.case`, the notebook, objective text and every HUD-facing getter and asserts no truth keys/ids leak, (b) scans investigation-side scripts (`scripts/ui/*`, notebook, objective, narrator beats) for reads of `_truth`, (c) checks that a detective who gathers nothing cannot be led to the killer by any UI-visible text, and (d) bots must solve cases only through claims.

## Implementation stages

1. **Separate and enforce.** Introduce `Truth` and the public case file; move the generator output into `_truth`; give the HUD a `CaseFile` view; add the firewall test; convert `suspects()` into persons of interest from the notebook; accuse any resident.
2. **Claims and rules.** Replace `supports` on clues/facts with structured claims; add `Reasoning.proof_against` and DA advice; adjudicator uses truth tags; update bots to reason from claims.
3. **Perception model.** Replace hand-picked witnesses (`vn`, `kn`, authored knower lists) with perception sampling from `sim.history`/`sim.night` and the plan's movements: distance, light, line of sight, attention, memory decay, misidentification, lies. Traces emitted from the ledger of deeds.
4. **Emergent plans.** The killer executes a plan as an agent (approach, wait, enter, strike, dispose, return) through the sim, so traces are a by-product of actions, not authored per puzzle. Variation in method, haste and mistakes produces unscripted cases.

Stage 1 and 2 remove the scripting from the *investigation* side; stages 3 and 4 remove it from the *generation* side.

## Status: stages 1 and 2 are implemented

**Stage 1 (separate and enforce).** `DetectiveGame._truth` holds the whole generated case (killer, motive, method, profiles, facts, clues, latents, cameras, the claim-tag map). `DetectiveGame.case` is the public case file, rebuilt by `_sync_case()` from `CaseEngine.PUBLIC_KEYS` only (id, day, seed, victim, scene, scene_kind, found_by, found_hour, found_rel, status, accusations, accused, closed_day). Saves keep both (`case` and `truth`); an old save with one big `case` dictionary loads and is split on the way in, and old notebook entries keep their worth as `legacy_*` claims. The HUD, `objective()`, narrator beats and cold open read only `case` and the notebook. Engine modules (CaseOps, Cctv, Prints, Confessor, Justice, Serial, Cold) are handed `_truth` and return observations. `suspects()` is a thin alias of `persons_of_interest()` (the finder, everyone a claim names, everyone questioned or `flag_person`ed); any living resident can be accused (searchable picker in the Accuse tab). Doorbell cameras are listed only once their owner has been spoken to. The funeral no longer names the killer.

**Stage 2 (claims and rules).** Every clue and fact is written by the generator as claim templates (`claims.gd`: kind, subject, predicate, place, time, until, item, certainty, plus a private `_truth_tag`). `Claims.emit` is the only door into the notebook: it strips everything private, gives the claim an opaque id (`k17`) and files the tag in `_truth["claim_tags"]`. `reasoning.gd` computes opportunity/means/motive/link/exonerate from predicate rules, the death window, certainty discounts, the public case file and the town's trades (`Detective.proof_against` delegates to it) and also gives `da_read` (qualitative advice, shown in the Court and Accuse tabs; no numbers). `CaseOps.judge` turns away any name the notebook cannot charge ("insufficient", the same for everyone); only when there is a case does the court look at the truth. `Justice.trial` uses the tags so a mistaken or lying witness, a clock that was out, a partial print or a false confession moves the jury (defence attacks are shown as text, never as numbers). `tests/firewall_tests.gd` (registered in `run_all.sh`) enforces R8 and runs the claims-only bot (`tests/case_bot.gd`, public API only) over ordinary seeds and the forced serials 110, 120, 101, 105, 115 through accuse, arrest, trial and jail, plus the null and lazy detectives.

**Knowingly left leaking (for stages 3 and 4).**
- Witnesses, cameras and traces are still authored per puzzle (`vn`, `kn`, `owner_item_knowers`, the killer's walk on tape); the killer is always findable by those paths. Stage 3 replaces them with perception sampling from `sim.history`/`sim.night`.
- Empathy reads (`hiding something` / `an open face`), the interrogation tells and the killer's own philosophy lines are keyed on guilt.
- `DetectiveGame.serial`, `haunting` and `repeat_killer` still hold the killer id and signature (the HUD reads only `news`, `pressure`, `nick`).
- The court's answer to an accusation with a real case behind it (`wrong` vs `released`/`convicted`) still tells you whether you had the right person; a pure jury verdict would hide that.
- `accuse()` returns `right_person`, `score` and similar keys for tests and the episode; the HUD shows none of them.
- Authored claim values are still tidy (identified suspects, fixed certainties); stage 3 should derive certainty from distance, light and attention.

**Stage 3 needs:** a perception function `observe(witness, event) -> claim` (distance, light, line of sight, attention, memory decay, look-alikes, lies from the witness's own secret) replacing the hand-picked fact list, and traces emitted from a ledger of deeds. **Stage 4 needs:** the killer as an agent executing a plan through the sim, so claims and traces are by-products and `CaseEngine._facts_and_clues` can be deleted.
