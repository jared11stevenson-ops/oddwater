# UNDERSTUDY — Core Systems Spec (GDD v0.1)

> Builds on `00-lore-loop-charter.md`. Data-driven throughout: every number below lives in JSON under `game/data/`, not in code. Engine: Godot 4.7 (GDScript).

## 1. Game state

| State | Scope | Notes |
|---|---|---|
| `Day` (1–15) | Global | Fixed spine; `Life[day]` is authored |
| `Notes{Warmth,Candor,Nerve,Curiosity,Fidelity}` | Per Life | −100..100, accrued by choices; hardens into the Remnant at dusk |
| `Suspicion[npc]` | Per NPC | 0..100; decays overnight (faster in clear weather, not in fog) |
| `Relationship[a,b]` | Pair | −100..100; the edge table in `04-relationship-web.md` seeds it |
| `Remnant[life]` | Per Life | Notes snapshot + flags; drives NPC behaviour from the next day |
| `Evidence[id]` | Global | 90 fragments (LF-001…090) plus world objects |
| `Pins`, `Links`, `Seals[40]` | Global | The Case Board |
| `Abilities` | Global | Derived from Seals (charter §6) |
| `TownMood` | Global | 0..100; drives weather and Hush strength |

## 2. WAKE & SNOOP

- 75-second search (adjustable 40–150 s, or untimed in accessibility mode). **Take Your Minute** adds 10 s.
- 12 interactables per home: 3 *Props* (clues, one is always a lore fragment), 2 *Role objects* (teach who you are), 1 *Pet check*, and decoys with jokes in them.
- Tactile: drawers physically open, items are picked up, flipped and read. Each has a haptic signature. No object is dead: every interactable has a reaction.
- The **mirror check** is the first action of every day: it shows the Life's face, and once Tell Sight is unlocked, the tells on your own hands.
- Output: a **Role Brief** assembled from what you found. If you found little, you get a vaguer brief and a higher starting Suspicion. *Not a fail state; a different state.*

## 3. PERFORM

- **Dialogue**: authored beats with 2–3 choices, each tagged to Notes. NPC replies depend on `Suspicion`, `Relationship` and the Remnants they've met.
- **Suspicion rises** when the player contradicts the Life's established habits (stored as `Habits[]` on the Life) or when *Bleed* leaks. It never causes a hard fail. At ≥80 an NPC "stages a test" (a short dialogue puzzle).
- **Vignette**: one per Life (charter §4). 90–150 s, with a *Cozy* difficulty (can't lose) and a *Stage* difficulty (scored). Score → **Applause**, which unlocks cosmetics and props, never Seals.
- **Proof Tool moments** appear inside the vignette as optional, highlighted opportunities (an X-ray that doesn't match, a locked vault).

## 4. STEP OFF

At dusk a **Notes card** shows what you left behind in the Remnant, in one line each. With **Shed** unlocked, the player picks which Note to *keep* and which to *leave*. The Remnant is spawned into town with that profile.

## 5. NIGHT

- Five locations, 4–5 minutes each; three open per night (rotating by Day and by Seals).
- The night self is visible only to the Awakened, animals and Wren. Being seen by anyone else triggers an *Encounter* (a chase-free, stealth-light conversation).
- **Slack scene.** The night ends when the Town Hall clock holds at 4:12. For 30 seconds the Hush loosens: tells show in water, the lake waves back. This is the "rewarding" beat and always contains one reveal.

## 6. The Case Board (the clue economy)

1. **Evidence** is collected and automatically placed as a card.
2. **Pin** a card to a *Question* (Who? What? When? Why?).
3. **Link** two cards when the player draws a string. The game never says "correct"; it says "interesting."
4. **Test.** When a plausible link or a set of ≥2 cards matches a Seal's conditions, a **Test** appears at the next opportunity where the Proof Tool exists (the role, the place, the day).
5. **Seal.** Pass the 20–40 s test: the Seal sets, a Model piece lands, Wren says one line.

Rules: no Seal can be missed *permanently* before a New Run starts; the Prop Room on Day 14 reopens up to 6 unfinished Tests as "rehearsals," because we never lock the story behind a bad day.

## 7. Presentation hooks tied to systems

- `TownMood` → weather, fog, music detune (adaptive score picks up underwater layers as Seals rise).
- `Hush strength` → shader on NPC faces (soft focus when strong), audio low-pass.
- The lake is always on screen or audible. It *waves back* when you wave.

## 8. Controls

| | Touch | Joy-Con / Pro |
|---|---|---|
| Move | Virtual stick (floating) | Left stick |
| Interact | Tap object; long-press to inspect | A / hold A |
| Search | Drag drawers; pinch to zoom | Stick + ZR to grip, ZL to zoom |
| Dialogue | Tap choices; swipe to skip | A / B |
| Vignettes | Designed per tool; always one-thumb playable | Per-tool mapping |
| Case Board | Drag cards and strings | Cursor snap; X to pin |

## 9. Accessibility

Text scale 100–200%; three colourblind modes (tells have shape cues, not colour only); timer slider (0.5×–3×, or off); full subtitles and sound captions; reduced motion; haptics slider; one-handed mode; high-contrast board. **Take Your Minute** is the in-world face of the timer slider.

## 10. Scope and performance budget

- Full game: 15 days × ~14 min + Day 15 finale ≈ **4 hours** first run; **7–8 hours** to see everything.
- Targets: Switch locked 30 fps docked and handheld; mobile 60 fps. Diorama town of ~120 buildings, ≤180 k tris on screen, baked GI + one real-time light.
- Memory plan: stream per-day; keep the Model scene resident.

## 11. Vertical slice mapping

7 days, 4 roles, 10 NPCs, 5 night locations, **22 Seals available**:

| Day | Life | Seals reachable |
|---|---|---|
| 1 | Mags | S01–S06, S23, S25 |
| 2 | Jo | S07, S20 |
| 3 | Tobi | S29, S35 (partial) |
| 4 | Delphine | S16, S17 |
| 5–7 | Encores (Mags, Jo, Delphine) with Remnant changes | S30, S33, S15 and the reframe |

Night locations: the lakeshore, the Playhouse, Town Hall (after hours), the Grange basement, Mags's practice. The slice ends on **S30: the Day-1 appointment book vs. the Prompt Book**, the reveal that reframes Day 1.

## 12. Next in line

Deliverable 3 (Act I script, all 90 fragments) writes against these Seals: every line of Day 1–5 dialogue is tagged with the Seal it feeds.

**Single-player only.** No online features, accounts, shared state or live service. Save data is local.
