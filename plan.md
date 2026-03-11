# Player/NPC Health Feature Plan

## Objective
Implement a reusable health mechanism for player and NPCs with UI visibility rules:
- Player health bar is fixed at top-left and always visible.
- NPC health bar appears at top-right only when:
  - the player is actively interacting with that NPC, or
  - that NPC is an enemy boss and a boss fight is active.

## Implementation Plan

- [x] Add player health model
  - Added `max_health`, `current_health`, and `health_changed`/`died` signals in `game/scripts/player.gd`.
  - Added `take_damage()`, `heal()`, and `is_dead()` helpers.

- [x] Add NPC health + state model
  - Added NPC health properties/signals in `game/scripts/npc.gd`.
  - Added interaction state tracking (`is_interacting_with_player`) and boss state tracking (`is_enemy`, `is_boss`, `boss_fight_active`).
  - Added methods for `start_interaction()`, `end_interaction()`, `start_boss_fight()`, `end_boss_fight()`, `take_damage()`, `heal()`.

- [x] Build health HUD
  - Created `game/scenes/health_ui.tscn` with top-left player section and top-right NPC section.
  - Created `game/scripts/health_ui.gd` to subscribe to player/NPC signals and apply visibility rules.

- [x] Wire interaction + fight flow
  - Added dialogue lifecycle signals in `game/scripts/dialogue_ui.gd` and end NPC interaction on close.
  - Updated `game/scripts/killzone.gd` to apply health damage and only reload when player dies.
  - Added `HealthUI` instance to `game/scenes/game.tscn`.

- [x] Configure a live enemy boss target
  - In `game/scenes/enemies/slime.tscn`, marked embedded NPC as enemy + boss and assigned boss health.

- [x] Validate and finalize
  - Confirmed signal wiring and visibility logic in scripts/scenes.
  - Marked this feature as DONE.

## Status
`DONE`

---

## Damage System Extension Plan

## Objective
Create a reusable damage pipeline that supports variable health reduction (fixed + percentage-based) and can be injected into hazards/attacks across the game.

## Implementation Plan

- [x] Add reusable damage payload model
  - Added `game/scripts/damage_payload.gd` as a shared payload resource with:
  - `flat_damage`
  - `max_health_percent`
  - `current_health_percent`
  - `minimum_damage`
  - Added `calculate_damage(max_health, current_health)` for consistent damage resolution.

- [x] Update health owners to consume variable damage input
  - Refactored `game/scripts/player.gd` and `game/scripts/npc.gd` with `apply_damage(damage_input, source)` to accept:
  - plain int/float damage
  - dictionary-based payloads
  - `DamagePayload` resources
  - Kept `take_damage(amount)` as backward-compatible wrapper.

- [x] Make killzones use injectable variable damage payloads
  - Updated `game/scripts/killzone.gd` to build and apply a payload instead of hardcoded fixed damage.
  - Added optional `damage_payload` Resource export for direct injection/reuse of shared damage configs.
  - Added configurable exports:
  - `flat_damage`
  - `max_health_damage_percent`
  - `current_health_damage_percent`
  - `minimum_damage`

- [x] Set main/bottom killzone to 100% health removal
  - Updated `game/scenes/map.tscn` main killzone values:
  - `flat_damage = 0`
  - `max_health_damage_percent = 1.0`

## Status
`DONE`
