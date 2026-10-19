# Little Mercy: scale and layout (v0)

**Requirement:** the town is **double the size of the town in the South Park games.**

## The honest part
I don't have official dimensions for that town. The baseline is therefore an **estimate, marked as such in `game/data/town_spec.json`** (`reference_south_park`): about 400 m × 300 m and about 60 built lots. "Double" is applied to **both land area and lot count**. If you have a better figure, change that one block and the tests re-check everything.

## What is built
| Measure | Baseline (estimate) | Little Mercy v0 | Ratio |
|---|---|---|---|
| Land area | 120,000 m² | **595,200 m²** (960 × 620; spread out, v0.2) | 4.96× |
| Built lots | 60 | **128** (+ 52 gardens/greens) | 2.13× |
| Named landmarks | n/a | 24 landmarks + 25 homes for named characters | |
| Walk, Quay → Chapel | n/a | 119 s at 6 m/s | |
| Walk, Marina → Lakeview Rest | n/a | 181 s | |

Layout is generated from `data/town_spec.json` by `scripts/core/town_layout.gd` (deterministic, no randomness): five E-W streets, five cross streets, lots on both sides, the lake to the north. Every landmark in the lore has a place, every one of the 13 Lives has a home lot, and the Overlay mirror (Low Mercy under the lake) is a reversible function.

`godot --headless --path game -s tests/town_tests.gd` : 9,653 checks (no overlaps, all in bounds, nothing in the lake, all landmarks and homes placed, size ≥ 2× baseline).

Render: `res://scenes/town_overview.tscn`. Reference frame: `reference/town_layout_v0.png`.

## Known limits
- It's a **rigid grid**: it measures right, but it doesn't yet *feel* like a lakeside town on a ridge. The lake floats beside the land and there is no terrain.
- Everything is boxes. A walkable 3D town at this size will need streaming per district and an LOD plan; **none of that is profiled**.
- A 2× town is a lot of content to make charming. The plan is to hand-dress the ~30 landmarks and 25 homes and keep the other ~70 houses as a few reusable kits.

## Next
1. Terrain: a ridge that falls to a curved shoreline; streets that follow the contour; the Blue Line painted on the lower buildings.
2. Districts with their own silhouettes: Lakefront, Main Street, Chapel Hill, Orchard Lane, the Dam Road.
3. Hand-built Pell Dentistry and Mags's home so Day 1 plays in real space.

**v0.2 (spread out):** street spacing 80→120 m, lot pitch 26→44 m, cross streets every 180 m, same 128 lots. Land area is now ~5x the estimated baseline while building count stays ~2x, so the town is airy rather than dense. A 3-minute end-to-end walk means fast travel (bike / the *Mercy Ann*) is needed by design.
