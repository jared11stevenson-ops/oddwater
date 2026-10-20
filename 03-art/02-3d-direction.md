# UNDERSTUDY — 3D direction (2026-10-20)

**Decision from the user:** the game is 3D. The graphics benchmark for now is the game *Peak*: chunky, stylised, saturated, soft-lit, with a big readable world. Characters use **normal humans** as the design reference (ordinary proportions, ordinary clothes, no exaggeration). This is the standard to get the **full game running**, not the final look; the earlier 2D "Ink & Odd Water" style stays as the portrait/UI language and as a candidate for the final look.

## What is built (3D pass 1)

| Piece | File | Notes |
|---|---|---|
| Batching kit | `scripts/world3d/mesh_kit.gd` | MultiMesh batches with per-instance colour: hundreds of buildings, trees and props in a handful of draw calls. Colours are typed as sRGB and converted. |
| Town | `scripts/world3d/town_builder.gd` | Built from the same lot layout as the sim. 104 houses (varied walls, gable roofs, chimneys, doors, lit windows, gardens), 23 landmarks (awnings, signs in Bangers, chapel steeple, town hall clock tower, school flag, clinic cross, the dam), park with pond and gazebo, streets with sidewalks and dashed lines, street trees and lamp posts, a pier with the Mercy Ann, 700 forest trees, colliders. |
| Land | `town_builder.gd`, `shaders/terrain3d.gdshader` | Flat plateau under the town, a lake basin to the north, hills and snowy mountains in the haze. Patchy ground shader so flat grass reads as grass. |
| Lake | `shaders/water3d.gdshader` | Layered teal, ripples, sparkles, foam at the shore. |
| Windows and lamps | `shaders/window3d.gdshader` | Dull glass by day, warm light at night; per-window "someone is home". |
| Sky and light | `scripts/world3d/sky_cycle.gd` | Sun path, dawn/day/dusk/night colour keys, moon, fog, weather grading, drives the window glow. |
| Humans | `scripts/world3d/human.gd` | Procedural normal-proportion bodies from the same traits as the 2D portrait (skin, hair style and colour, glasses, beards, hats, work clothes, expressions, child/teen/adult/elder scale). Procedural walk cycle and talking gestures. |
| Routes | `scripts/world3d/path_grid.gd` | Sidewalk routing along the street grid. |
| Residents | `scripts/world3d/npc_manager.gd` | All ~217 residents have a logical position; only the ~70 nearest get bodies. After each tick they walk where the sim sends them, then stand around outdoors or go through a door. |
| You | `scripts/world3d/player_rig.gd`, `ui/virtual_stick.gd`, `ui/look_pad.gd` | Floating thumb stick, drag-to-look, pinch zoom, third-person camera with wall avoidance. |
| The game | `scripts/world3d/town_world.gd`, `ui/town3d_hud.gd` | Real-time town clock (18 s per half hour, x1/x3/x8), walk up to a door or person for a context button, enter buildings to act, talk, minimap, panels, night and morning flow, weather (rain particles), save/continue. |

## Honest status
- This is a **blockout-quality** world: boxes and prisms with good colour and light. It proves the loop and the scale. It is not yet at Peak's polish (no hand-modelled assets, no foliage detail, no animation beyond a walk cycle, no interiors).
- Faces are small primitives; expression reads up close only.
- Nothing is profiled on a phone. The world builds on load (a loading screen is shown); expect a few seconds on device.
- Interiors do not exist yet: entering a building is a menu with the person hidden.

## Next 3D passes
1. Interiors (a handful of reusable room kits) and a proper enter/leave transition.
2. Character polish: face textures, hair shapes, clothing detail, idle and work animations, sitting, sleeping, eating.
3. World polish: distinct landmark models, fences, cars, props, grass and flower scatter, better trees, clouds, birds, ripples.
4. Performance on device: LOD, occlusion, shadow budget, 3D resolution scale.
5. Day/night and weather polish; seasons later.
