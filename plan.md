## Current Task: Player Attack Fixes For Slime

### What will be changed
- [x] Expose slime root damage methods so generic hit detection can damage the enemy reliably.
- [x] Add typed attack damage for sword, stomp, and stomp shockwave so enemy scenes can tune damage response by attack type.
- [x] Spawn a stomp shockwave that damages nearby enemies on stomp impact.
- [x] Show the slime health bar when the player is close, not only during dialogue or boss-only flows.

### What was implemented
- [x] Forwarded `apply_damage()`, `take_damage()`, and `is_dead()` from the slime root to the nested `NPC` health node.
- [x] Extended `NPC` combat handling with per-attack damage multipliers and a proximity signal for UI updates.
- [x] Updated player attacks to send typed damage payloads and added a reusable `stomp_shockwave` scene/script.
- [x] Tuned the slime scene to use slime-specific multipliers for sword, stomp, and shockwave hits.
- [x] Updated health UI selection logic so nearby enemies can surface their health bars.
- [x] Fixed dynamic enemy health UI registration so level-loaded slimes are tracked after they join the `health_npcs` group.
- [x] Added a distance-based enemy damage pass to the stomp shockwave so a single nearby slime still takes shockwave damage even if overlap timing is missed.
- [x] Increased enemy health-bar appearance range by separating it from the close interaction radius.

### New functionality added
- [x] Reusable stomp shockwave effect scene at `game/scenes/effects/stomp_shockwave.tscn`.
- [x] Reusable enemy-side attack multiplier exports in `game/scripts/npc.gd`.

### Validation
- [x] Read back all edited scripts/scenes and checked the wiring/diff manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Persistent Progress, Continue Flow, and First-Enemy Hint

### What will be changed
- [x] Persist open-count plus the player's last level and `x,y` position so `Continue` can restore the run.
- [x] Autosave progress from gameplay and resume from saved position only when `Continue` is used.
- [x] Show a one-time stomp tutorial message when the player first reaches Vilemurk.
- [x] Add a dev-only menu button to reset saved game state.

### What was implemented
- [x] Extended `LevelManager` into the persistent game-state owner for session count, saved progress, and one-time tutorial flags.
- [x] Updated `Game` to restore saved position, autosave the loaded level/position, and show a reusable tutorial hint banner.
- [x] Updated `MainMenu` so `Continue` only enables when saved progress exists and added a dev reset button.
- [x] Wired the Vilemurk encounter to show the stomp hint once, backed by the persistent one-time flag store.

### Validation
- [x] Read back the edited scripts/scenes and manually checked resume/autosave/menu wiring.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Persist Enemy Kills and Score

### What will be changed
- [x] Persist defeated enemies so killed enemies stay gone after reopening and continuing.
- [x] Persist collected coins and score so points survive reloads and continues.
- [x] Bind world-state persistence to stable per-level node keys.

### What was implemented
- [x] Extended `LevelManager` to store persistent score, defeated enemy keys, and collected item keys in the same save file.
- [x] Updated `GameManager` to read/write score through `LevelManager` instead of a per-level transient counter.
- [x] Updated `coin.gd` to skip already-collected coins and only score once when the coin is first collected.
- [x] Updated `slime.gd` to remove already-defeated slimes on load and register the defeat when Vilemurk dies.

### Validation
- [x] Read back the edited persistence, score, coin, and slime scripts and manually checked the node-key flow.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Persist Player Health

### What will be changed
- [x] Persist the player's current health in the same continue-state save as level and position.
- [x] Restore saved health when loading through `Continue` and keep the HUD in sync.
- [x] Preserve compatibility with older save files that do not yet contain player health.

### What was implemented
- [x] Extended `LevelManager` to save, load, and clear `player_health` alongside the saved level and `x,y` position.
- [x] Updated `Game` autosave and resume flow to pass player health into the persistent save and restore it when resuming.
- [x] Added `restore_saved_health()` to the player so restored health clamps correctly and re-emits the health-changed signal for UI refresh.

### Validation
- [x] Read back the edited save/load/player scripts and checked the resume-state data flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Knight Shooting Power

### What will be changed
- [x] Add a dedicated shooting input and projectile power for the knight alongside stomp and sword.
- [x] Keep shooting behavior constrained with clear combat-state rules and reusable projectile wiring.
- [x] Extend typed enemy damage so projectile hits can be tuned separately from sword, stomp, and shockwave.
- [x] Document the new shooting control and combat rules for future agents and tuning passes.

### What was implemented
- [x] Added a reusable `knight_projectile` scene/script that flies forward, damages the first valid target, and expires on impact or timeout.
- [x] Updated `player.gd` with exported shooting damage, speed, lifetime, cooldown, and spawn offset values plus shoot-state gating.
- [x] Added a new `shoot` input action mapped to `L`.
- [x] Extended `npc.gd` with `projectile_damage_multiplier` for per-enemy tuning of ranged damage.
- [x] Updated `player.md` with the new shooting control and explicit shooting ground rules.

### Validation
- [x] Read back the edited scripts/scenes/docs and checked the projectile wiring manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Interaction And Shooting

### What will be changed
- [x] Give `final_boss.tscn` the shared NPC interaction and health wiring used by other composite enemies.
- [x] Add a dedicated hostile fireball attack so the final boss can damage the player from range.
- [x] Make the boss always face the player's side while leaving extension points for future AI phases and actions.
- [x] Keep the boss compatible with existing enemy defeat persistence and dialogue systems.

### What was implemented
- [x] Added `final_boss.gd` as the root behavior script with player-facing updates, default ranged AI, defeat forwarding, and reserved AI hook methods for future boss logic.
- [x] Added a dedicated `final_boss_fireball` effect with reddish visuals and raycast-based player/world hit detection.
- [x] Rebuilt `final_boss.tscn` as a composite enemy with an embedded `NPC`, widened interaction radius, boss metadata, and explicit projectile spawn/AI hook nodes.
- [x] Wired the boss root to forward `apply_damage()`, `take_damage()`, and `is_dead()` to the nested `NPC` so existing player attack systems keep working.

### Validation
- [x] Read back the edited boss scripts/scenes and checked the interaction, facing, and projectile wiring manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Movement

### What will be changed
- [x] Convert the final boss into a physics-driven actor that can walk and jump instead of staying static.
- [x] Keep the movement AI compatible with the existing boss-fight, interaction, and future AI hook structure.
- [x] Add a contained collider sized for the boss so world collisions support movement without an oversized hitbox.

### What was implemented
- [x] Changed the final boss root script to `CharacterBody2D` behavior with exported walk, jump, gravity, stop distance, and obstacle probe tuning.
- [x] Added default chase-and-jump AI so the boss walks toward the player during the boss fight and jumps when the player is above or a wall blocks the path.
- [x] Added a root collision shape in `final_boss.tscn` so the boss can collide with the level while preserving the separate NPC interaction area and future AI nodes.

### Validation
- [x] Read back the updated movement script/scene and checked the chase, jump, and world-collision wiring manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Activation Fix

### What will be changed
- [x] Remove the accidental dependence on a tiny scaled interaction trigger before the boss can start acting.
- [x] Keep NPC interaction available while making combat activation distance-based and robust to scene scaling.
- [x] Restore a practical interaction radius for the scaled boss instance.

### What was implemented
- [x] Added distance-based combat engagement in `final_boss.gd`, with start/end range tuning and auto-aggro when the player damages the boss.
- [x] Changed boss movement/shooting gating to use the root engagement state instead of relying only on `NPC.player_in_range`.
- [x] Re-added explicit `NPC` interaction-area overrides in `final_boss.tscn` with a much larger collision radius so interaction still works after scaling the boss scene down.

### Validation
- [x] Read back the activation script/scene wiring and checked the engage/disengage flow statically.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Gravity Fix

### What will be changed
- [x] Stop relying on root-node scaling for the boss physics body.
- [x] Preserve the smaller visual size while restoring normal gravity and floor collision behavior.
- [x] Keep projectile spawn and body proportions aligned with the downsized presentation.

### What was implemented
- [x] Captured the placed scene instance scale in `final_boss.gd`, reset the `CharacterBody2D` root scale to `1,1`, and reapplied the size reduction to presentation/collider child nodes instead.
- [x] Resized the boss collision shape, sprite, combat pivot, and projectile spawn from shared base values so the smaller boss still lines up visually after removing root scaling.
- [x] Updated facing logic to preserve horizontal flipping with the presentation-scale approach.

### Validation
- [x] Read back the gravity-fix script changes and checked that the body scale reset happens before runtime physics logic.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Ground Alignment Fix

### What will be changed
- [x] Correct the visual floating gap between the boss and the floor without disturbing the already-fixed physics body.
- [x] Keep the fireball spawn aligned with the lowered presentation layer.

### What was implemented
- [x] Measured the standing-frame alpha bounds and confirmed a large gap above tiny bottom pixels in the spritesheet.
- [x] Added a base sprite Y offset in `final_boss.gd` so the visible boss body sits lower while the collider remains unchanged.
- [x] Shifted the combat pivot by the same presentation offset so ranged attacks still originate from the correct height.

### Validation
- [x] Read back the presentation-offset changes and verified the lowered sprite and pivot share the same offset source.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Stomp And Fireball Hit Fix

### What will be changed
- [x] Add a close-range stomp pattern so the boss can jump and slam when the player is directly under it.
- [x] Reuse the landing shockwave pattern for boss stomp damage instead of inventing a separate one-off damage path.
- [x] Make boss fireballs visually smaller but much more reliable at hitting the player.

### What was implemented
- [x] Added a stomp state machine in `final_boss.gd` with trigger radius, jump-up, forced dive, landing shockwave, and cooldown tuning.
- [x] Reused the shared `stomp_shockwave` effect for boss landings and widened its collision mask so it can damage the player as well as enemies.
- [x] Changed `final_boss_fireball.gd` from a thin ray hit check to a swept circle collision query, and reduced the fireball draw radius while increasing its effective hit radius.

### Validation
- [x] Read back the stomp/fireball script changes and checked the state gating and collision query flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Player Death Restart Fix

### What will be changed
- [x] Make player death restart the level regardless of which damage source reduced health to zero.
- [x] Prevent the autosave flow from persisting a zero-health death state during scene reload.

### What was implemented
- [x] Connected the player's `died` signal in `game.gd` and added a shared delayed reload path with the same slow-motion feel previously limited to killzones.
- [x] Guarded `_save_player_progress()` so dead-player state is not written into the continue save during the death reload.

### Validation
- [x] Read back the game death-handling changes and checked the signal/reload flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Player Boss Death Animation

### What will be changed
- [x] Play the player's new `die` animation when the final boss is the kill source.
- [x] Keep non-boss deaths on the existing fast restart path.
- [x] Let the shared game restart delay respect the longer boss-death animation timing.

### What was implemented
- [x] Added death-source tracking and boss-kill detection in `player.gd`.
- [x] Locked the player into the `die` animation on final-boss kills and exposed a per-death restart delay to the game flow.
- [x] Added `is_final_boss()` on the boss root so player death handling can identify that source cleanly.

### Validation
- [x] Read back the player/game/boss death-animation changes and checked the source detection and reload timing flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Player Death Hold Timing

### What will be changed
- [x] Let the boss-kill death animation finish fully before restart.
- [x] Hold on the last death frame for a short beat before reloading the level.

### What was implemented
- [x] Added boss-death animation duration and hold timing exports in `player.gd`.
- [x] Updated boss-death processing to stop on the last `die` frame after the animation duration expires.
- [x] Marked the `die` animation as non-looping in `player.tscn` so the death presentation does not restart before the hold period.

### Validation
- [x] Read back the player scene/script timing changes and checked the frame-hold/restart-delay flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Final Boss Construct Defense

### What will be changed
- [x] Add a reusable boss construct system that spawns temporary solid blocks without editing the level TileMap directly.
- [x] Bind `T` to a test staircase pattern that pops up one block at a time in front of the final boss.
- [x] Enforce limited active construct stock, automatic refill on construct expiry, and leave pattern hooks for future boss AI.

### What was implemented
- [x] Added `boss_construct` input in `project.godot` and boss-side debug spawning through `request_construct()` in `final_boss.gd`.
- [x] Created `final_boss_construct.gd/.tscn` and `final_boss_construct_block.gd/.tscn` for timed temporary block patterns with sequential pop-up.
- [x] Added staircase, wall, and rampart pattern definitions so later boss AI can request different constructs while `T` currently spawns the staircase.

### Validation
- [x] Read back the boss construct scripts and checked the spawn-stock-expiry flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Boss Construct Typing Fix

### What will be changed
- [x] Remove strict-typing warnings from the new construct block script so it parses with warnings treated as errors.

### What was implemented
- [x] Replaced generic `min`/`max`/`lerp` calls with typed float variants in `final_boss_construct_block.gd`.

### Validation
- [x] Read back the construct block script and checked the affected typed expressions manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Boss Construct Tuning And Projectile Filtering

### What will be changed
- [x] Make the construct size setting easier to find from the final boss inspector.
- [x] Ensure boss-generated defense blocks still stop player shots without blocking the boss's own fireballs.

### What was implemented
- [x] Grouped the construct exports under a dedicated `Constructs` section in `final_boss.gd`, keeping `construct_block_size` inspector-editable on the boss.
- [x] Tagged construct nodes/blocks with dedicated groups and updated `final_boss_fireball.gd` to ignore those groups while still colliding with other blockers and damage targets.

### Validation
- [x] Read back the boss/fireball/construct scripts and checked the construct filtering flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.

## Current Task: Boss Fireball Construct Blocking Fix

### What will be changed
- [x] Make boss fireballs respect generated constructs as blockers instead of passing through them.
- [x] Prefer the nearest sweep hit so a player standing behind cover is not selected before the cover itself.

### What was implemented
- [x] Removed the boss-construct ignore path from `final_boss_fireball.gd`.
- [x] Changed fireball sweep resolution to choose the closest collider along the projectile motion instead of the first unsorted result returned by physics.

### Validation
- [x] Read back the updated fireball hit-selection logic and checked the blocker-priority flow manually.
- [ ] Run a Godot headless parse/test pass. Blocked here because the Godot executable is not available on PATH in this environment.
