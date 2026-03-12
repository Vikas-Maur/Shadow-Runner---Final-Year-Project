## Current Task

- [x] Extend the Ollama integration so gameplay systems can request compact structured JSON, not only streamed dialogue text.
- [x] Replace the final boss hardcoded combat decision loop with an Ollama-driven controller for movement, facing, jump, stomp, fire, and construct generation.
- [x] Expose combat snapshot data for the model, including player state, boss state, recent attacks, cooldowns, and construct capacity.
- [x] Keep local game logic limited to validating and executing abilities chosen by the model instead of choosing tactics itself.

## Implemented

- Added `send_structured_message()` to `game/scripts/ollama_api.gd` with per-request state, JSON extraction, timeout handling, and shared chat transport.
- Added console logging for the Ollama message trail so outgoing system/user prompts and incoming assistant replies are printed once per request, with streamed responses appearing live as they arrive.
- Reworked `game/scripts/final_boss.gd` into an LLM intent executor:
  - sends fast structured boss-fight snapshots to Ollama,
  - applies model-selected movement/facing horizons,
  - executes model-selected jump, stomp, fire, and construct actions after local legality checks,
  - tracks recent player hits, last boss action results, cooldowns, and construct budgets,
  - now forces player-facing combat posture, coerces passive model outputs into active pressure, applies an emergency fallback combat decision when the model is unavailable, invalid, or too slow, maintains a preferred minimum standoff distance from the knight, stays inside exported horizontal play bounds, and limits fireball volume per interval so construct usage becomes necessary.
- Added player combat snapshot helpers in `game/scripts/player.gd` so the boss model can see the player's latest attack pattern and current combat state.

## Validation

- [x] Reviewed the changed scripts for obvious GDScript issues after refactoring.
- [ ] Run Godot parser / headless validation once a local Godot executable is available in PATH or the workspace.

## Notes

- No commit actions were taken.
- The workspace does not currently expose a `godot` or `godot4` executable, so automated script parsing could not be run from the terminal.
