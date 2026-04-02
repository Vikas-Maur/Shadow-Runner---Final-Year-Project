# Boss AI + ProcGen Refactor

## Before vs After

### Before
- `final_boss.gd` mixed movement, attacks, LLM prompting, and decision pacing in one script.
- The boss had no reusable environment query layer.
- Procedural regions were rendered visually, but the boss had no formal API to inspect generated tiles.
- The LLM decision path could directly drive action flags every request cycle, which made the fight look robotic.

### After
- `final_boss.gd` still owns movement and attack execution, but decision-making is split into modular layers:
  - `ProcGenAgentAPI`: tile/environment/tool queries
  - `FinalBossTacticalBrain`: weighted combat reasoning
  - `final_boss.gd`: state machine, execution, cooldowns, pacing
- The boss now runs a human-like loop:
  - `observe -> think -> act -> recover`
- Procedural regions register themselves on the level `TileMap`, so the boss can inspect generated geometry and hazards.
- LLM output is advisory, not a direct action pump.

## Integration Points

### Procedural Environment API
- File: `game/scripts/procgen/procgen_agent_api.gd`
- Purpose:
  - Query tile properties from authored TileMap cells
  - Query logical tiles from runtime procedural regions
  - Score tile risk
  - Simulate simple movement outcomes
  - Find low-risk safe positions

### Runtime Region Registration
- File: `game/scripts/level_3_proc_extension.gd`
- The procedural extension now stores:
  - `layout`
  - `origin`
  - `theme`
- These are attached to `TileMap` metadata under `procgen_runtime_regions`.

### Boss Tactical Brain
- File: `game/scripts/final_boss_tactical_brain.gd`
- Purpose:
  - Score actions using spacing, cooldowns, hazards, and safe footing
  - Add hesitation and imperfect decision noise
  - Produce reason traces and timing windows

### Boss Runtime Integration
- File: `game/scripts/final_boss.gd`
- The boss now:
  - Initializes `ProcGenAgentAPI`
  - Pulls environment snapshots from the TileMap/procgen metadata
  - Uses `FinalBossTacticalBrain` to choose actions
  - Runs an observe/think/act/recover combat loop

## Tool API

These are implemented in `ProcGenAgentAPI` and designed to stay composable.

### `get_nearby_tiles(world_position, radius_cells = 3, logical_layer = "ground")`
- Returns nearby tile payloads with:
  - `tile_id`
  - `collision_enabled`
  - `friction`
  - `visibility`
  - `danger`
  - `tags`
  - `source`

### `get_player_position(player)`
- Returns:
  - `visible`
  - `position`

### `evaluate_risk(tile)`
- Returns:
  - `score`
  - `reasons`

### `simulate_move(action)`
- Input:
  - `actor_position`
  - `move`
  - `distance_cells`
  - `jump`
- Returns:
  - `target_cell`
  - `target_tile`
  - `support_tile`
  - `target_risk`
  - `landing_safe`

### `get_safe_positions(origin_world_position, search_radius_cells = 6, max_positions = 5)`
- Returns low-risk standable cells for repositioning.

## Boss Reaction Example

Example: avoid danger tiles

1. `final_boss.gd` builds `environment_snapshot`
2. `ProcGenAgentAPI` reports:
   - current tile risk
   - nearby hazards
   - forward movement simulation
   - safe positions
3. `FinalBossTacticalBrain` sees:
   - hazard ahead
   - unsafe footing
4. It boosts:
   - `retreat`
   - `reposition`
   - `jump`
5. It reduces:
   - `stomp`
   - `fire` from bad footing

## Combat Loop

### Observe
- Sample:
  - player distance
  - current tile
  - nearby hazards
  - safe positions
  - cooldowns

### Think
- Score candidate actions:
  - fire
  - stomp
  - construct
  - jump
  - reposition
  - retreat
  - wait

### Act
- Commit one primary action and optional movement.

### Recover
- Hold or settle briefly before the next observation cycle.

## New Agent System Prompt

```text
You are the strategic combat planner for a 2D platformer final boss.
Output only compact JSON that matches the response schema. No prose. No markdown.
Behave like a tactical fighter, not a command executor.
Use this rhythm on every decision:
1. Observe the player, spacing, hazards, footing, and available safe tiles.
2. Think briefly and choose one strong action or a deliberate reposition.
3. Act with intent.
4. Recover for a short time before the next commitment.
The boss should feel dangerous but human:
- do not chain actions instantly
- allow short hesitations and recovery beats
- prefer one committed action over frantic multi-action spam
- accept imperfect but plausible decisions when two options are close
- respect hazards and unstable footing
Always face the player.
Include a primary_action.
Include a short reason_trace with observe/think/act wording.
Include non-zero observation_seconds, thinking_seconds, action_seconds, and recovery_seconds.
```

## Example Decision Trace

```json
{
  "primary_action": "retreat",
  "move": "left",
  "face": "keep",
  "jump_now": false,
  "fire_now": false,
  "stomp_now": false,
  "construct": {
    "spawn": false,
    "cells": []
  },
  "horizon_seconds": 0.28,
  "observation_seconds": 0.15,
  "thinking_seconds": 0.11,
  "action_seconds": 0.28,
  "recovery_seconds": 0.21,
  "reason_trace": [
    "observe: standing on floor with risk 0.90",
    "think: spacing_adjust, safe_landing",
    "act: retreat"
  ]
}
```

## Files Changed

- `game/scripts/final_boss.gd`
- `game/scripts/final_boss_tactical_brain.gd`
- `game/scripts/procgen/procgen_agent_api.gd`
- `game/scripts/level_3_proc_extension.gd`

## Notes

- The tactical brain is local and deterministic enough to work without Ollama.
- The LLM path is now advisory, so disabling it does not disable the boss fight.
- The tool API is suitable for future Ollama/tool-calling integration because the methods are explicit, composable, and query-based.
