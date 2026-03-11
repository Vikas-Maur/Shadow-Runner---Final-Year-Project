## Current Task

- [x] Create a reusable level system with separate level scenes.
- [x] Move the current playable setup into `level_1`.
- [x] Prepare empty `level_2` and `level_3` scenes so map content can be pasted in later.
- [x] Add a portal-based level transition flow with optional future cutscene/story support.
- [x] Rewire the main game scene to load the active level dynamically.

## Notes

- `game.tscn` currently mixes global gameplay nodes with level-specific content.
- `map.tscn` already contains most world data, coins, hazards, and the score label.
- Level transitions should keep room for a future intermediate story/cutscene scene.

## Implemented

- Added `LevelManager` as an autoload to track the active level and support future transition scenes.
- Converted `game.tscn` into a reusable gameplay shell that loads the active level scene into `LevelRoot`.
- Added a reusable `portal.tscn` + `portal.gd` interaction for level progression.
- Created `level_1.tscn` from the existing playable content and gave each level its own cloned map scene under `game/scenes/levels`.
- Added debug-only level jump shortcuts (`Ctrl+1/2/3`) and temporary main-menu level jump controls for development.

## Follow-up Fixes

- Fixed the main menu development button node paths after the first debug menu pass so the scene can resolve the new controls correctly.
- Updated `instruction.md` so future agents must record newly discovered steps/features and separate new functionality in `plan.md` for recovery context.
- Fixed a typed-GDScript warning in `LevelManager` by making the debug shortcut level lookup explicitly `int`.
- Moved level portals into each level map scene and removed temporary helper labels so portal placement is edited where the map is edited.
