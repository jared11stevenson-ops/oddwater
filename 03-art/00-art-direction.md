# UNDERSTUDY — Art Direction v0.1: "Ink & Odd Water"

> A foundation, not the final look. Comic-book printing and anime-style staging are **inspiration only**. Nothing here copies a series, character or logo. The look is built from the game's own idea, and the people in it stay simple and normal.

## The idea

**Little Mercy is printed. The lake is painted.**

- **INK** = the town's surface, the Hush. Dry, flat spot colour, hard cel steps, Ben-Day halftone in the half-shadow, crisp black line, newsprint grain. Everything cozy lives here.
- **WASH** = the lake, the truth. Wet, soft, translucent teal that bleeds past the lines and seeps through the paper.

The two are never mixed arbitrarily. Both are driven by two numbers the simulation already has:

| Driver | Source | Visual |
|---|---|---|
| `hush` (1→0) | `GameState.hush_strength()` (town mood) | 1 = plates in perfect register. 0 = the colour plates drift apart, grain rises, the page looks cheap and unsteady (the town is afraid; fog) |
| `truth` (0→1) | share of Seals proven | 0 = pure comic ink. 1 = the lake's wash bleeds into the ink: softer, bluer, richer, while black lines stay crisp |
| `impact` | scripted | Comic burst lines for reveals, the 4:12 Take |

So **the game visibly changes style as you understand it**: it begins as a clean, funny printed page and ends as something deeper and wetter. A casual player feels a mood shift. An obsessive player can read the Seal count off the picture.

Reference frames: [`reference/states_ink_to_wash.png`](reference/states_ink_to_wash.png) (left to right: hush 1/truth 0, hush 0.35/truth 0.35, hush 0.1/truth 1 with burst) and [`reference/lab_4k_downscaled.png`](reference/lab_4k_downscaled.png).

## Rules

1. **Simple, normal people.** Ordinary proportions, ordinary hair and clothes, dot eyes, a short brow line, minimal mouth. The acting is posture, silhouette and brow. No exaggerated anime features, no spiky hair, no costumes. Readable at handheld size.
2. **Understudies are drawn wet.** Walk-ons and the Held have a line that breathes (`wobble`). It's the one tell you can see across a street, and the reason Tell Sight can be a pure rendering effect.
3. **One strong line, three weights.** Outer silhouette heaviest, form lines medium, detail lines light. Constant on-screen width (inverted hull), thinner at 4K viewing distance.
4. **Shadows are printed.** Light step, then a halftone band, then solid ink-leaning shadow. Never smooth gradients on the town.
5. **The lake is always on screen or implied.** It is the only surface with wash at `truth = 0`, so the player learns early that water means something.
6. **Colour is a short list.** See tokens below. Mercy Red is rare and always means *someone was here* (the ribbon, doors, the Seal stamps).
7. **UI is the page.** Caption boxes, lettering and panel borders belong to the same printed world. Seals are red stamp impressions on the Case Board.
8. **Camera.** Long lens (FOV ~26°), raised three-quarter view: a tabletop diorama, which is also the Model in the Prop Room.

## Palette tokens

| Token | Hex | Use |
|---|---|---|
| Ink | `#14121c` | Lines, deep shadow, type |
| Paper | `#f3e9d2` | Page tint, captions |
| Lake | `#2f8f9d` / deep `#14455a` | Water, wash, tells |
| Mercy Red | `#e23d3d` | Ribbon, doors, Seals |
| Marigold | `#f5b82e` | Lamps, windows (warmth) |
| Roof / wall / grass | `#b4584a` / `#efe0bd` / `#71915a` | Town base |
| Slack violet | `#4a3f7a` | Shadow tint, 4:12 |

## Motion and presentation (plan)

- Characters animated "on twos" (12 fps pose changes inside a 30 fps frame), with smear frames on fast moves.
- Dialogue portraits are static, hand-inked poses with expression swaps.
- Cutscenes are comic panels that animate within their frames; the 4:12 Take breaks the panel borders.
- Type: one friendly serif for narration, one loud brush face for sound lettering; both to be chosen and licensed.

## What exists now (`game/`)

| File | Purpose |
|---|---|
| `shaders/toon_ink.gdshader` | Spatial cel + halftone + wet rim (`truth`) |
| `shaders/ink_outline.gdshader` | Constant-width ink line; `wobble` for understudies |
| `shaders/page_post.gdshader` | Full-screen print pass: misregistration, grain, brightness posterise, wash bleed, burst lines |
| `scenes/style_lab.tscn` | Diorama test bench with screenshot mode (`-- --hush= --truth= --impact= --shot=`) |

Render a frame: `xvfb-run -a godot --path game --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 3840x2160 res://scenes/style_lab.tscn -- --shot=out.png`

## Honest status and next fixes

- Everything is **primitive geometry**: houses are boxes, people are capsules. This proves the *rendering language*, not the final art.
- Frames were rendered by **software GL** (Mesa llvmpipe) at up to 3840×2160. That proves the shaders are correct at 4K. **It says nothing about performance** on mobile or Switch-class hardware.
- The post pass uses `hint_screen_texture` mip blur and one full-screen pass. It's designed to be cheap, but is **unprofiled on device**.
- Known flaws: the angled brows read angry (need neutral), the lake is a flat disc (needs animated wash and shoreline), characters need proper silhouettes, no real backgrounds or textures yet.
- Next art passes: (1) neutral-brow face set and 6 body silhouettes, (2) painterly lake and shoreline, (3) one hand-modelled home interior (Mags's bedroom) with the Wake & Snoop camera, (4) comic-panel cutscene framework, (5) wire `hush` and `truth` to `GameState`, (6) device profiling.
