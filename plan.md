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
