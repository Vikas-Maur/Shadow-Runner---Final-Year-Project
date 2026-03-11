## Level System

- [x] Create a reusable level system with separate level scenes.
- [x] Move the original playable setup into `game/scenes/levels/level_1.tscn`.
- [x] Prepare `level_2` and `level_3` scenes so their maps can be edited independently.
- [x] Add portal-based progression to the next level with room for future cutscenes/story scenes.
- [x] Rework `game/scenes/game.tscn` into a gameplay shell that loads the active level dynamically.

## Level Structure Implemented

- Added `LevelManager` autoload in `game/project.godot` and `game/scripts/level_manager.gd`.
- Added reusable portal scene/script in `game/scenes/portal.tscn` and `game/scripts/portal.gd`.
- Added dynamic level loading in `game/scripts/game.gd`.
- Split the world into:
  - `game/scenes/levels/level_1.tscn`
  - `game/scenes/levels/level_2.tscn`
  - `game/scenes/levels/level_3.tscn`
- Moved the per-level maps into:
  - `game/scenes/levels/level_1_map.tscn`
  - `game/scenes/levels/level_2_map.tscn`
  - `game/scenes/levels/level_3_map.tscn`
- Added debug-only development shortcuts:
  - `Ctrl+1`, `Ctrl+2`, `Ctrl+3` to jump levels
  - debug-only main-menu level jump controls

## Follow-up Fixes

- [x] Fix `LevelManager` typed warning on debug shortcut lookup.
- [x] Fix main-menu development button node paths.
- [x] Move portals into the editable per-level map scenes.
- [x] Remove temporary helper labels from Level 2 and Level 3 scenes.

## School Map Collision Pass

- [x] Inspect the cropped Level 2 and Level 3 school maps and confirm the new school tiles were visual-only.
- [x] Add collision polygons to the embedded school tileset atlas entries used by `level_2_map.tscn`.
- [x] Add collision polygons to the embedded school tileset atlas entries used by `level_3_map.tscn`.
- [x] Keep the collision inside the level map scenes themselves so future map edits stay local to each level copy.

## Collision Notes

- Level 2 and Level 3 each now have embedded collision polygons added to their duplicated school atlas sources inside:
  - `game/scenes/levels/level_2_map.tscn`
  - `game/scenes/levels/level_3_map.tscn`
- The collision pass targeted the school atlas cells referenced by the current cropped maps, including mirrored coordinate cases present in the duplicated atlas data.
- Resulting rectangular collision polygon count per map scene is now `92`.
- Godot runtime validation could not be executed in this environment because no `godot` executable is available here.

## Player Combat Follow-up

- [x] Add jump feel improvements with coyote time, jump buffering, and short-hop release.
- [x] Add dash and air stomp controls to the player.
- [x] Fix air stomp resolution so valid downward contacts prefer damaging enemies instead of the player.
- [x] Add a sword attack input, hitbox, and generated sword sprite asset for the knight.
- [x] Update `player.md` with stomp and sword controls.

## Player Combat Implemented

- Added coyote time, jump buffering, and short-hop release handling in `game/scripts/player.gd`.
- Added dash movement with exported tuning values and input bindings in `game/project.godot`.
- Added an air stomp attack that dives downward and bounces the player up on a successful hit.
- Adjusted stomp validation to compare the player against the enemy hurt area directly for more reliable downward stomp hits.
- Added `attack` input and a front-facing sword swing in the player controller.
- Added `game/assets/sprites/sword.png` and attached it in `game/scenes/player.tscn`.
- Added `player.md` in the project root to document movement, stomp, dash, and sword controls.
