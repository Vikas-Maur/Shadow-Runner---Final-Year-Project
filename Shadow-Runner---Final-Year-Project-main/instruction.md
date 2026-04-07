# Shadow Runner Agent Instructions

## Change Workflow

1. Read `plan.md` and latest modified files to understand current context.
2. Inspect working tree changes (`git status`, `git diff`) before editing.
3. Prefer small, focused changes that match the existing structure.
4. Update `plan.md` with:
   - what will be changed,
   - what was implemented,
   - checkbox status (`[x]` when done).
   - any newly added steps/features discovered during the task.
   - if entirely new functionality is added during the task, create a separate section for it so a new agent can recover context quickly.
   - if the work has already been committed, clear `plan.md` first and then rewrite it from the current committed state instead of appending another stale section.
5. Validate changes with quick checks (scene/script wiring, signals, obvious regressions).
6. Share a short summary of what changed and where.
7. **Before any `git add`, `git commit`, or `git push`, ask the user explicitly.**

## Git Rule (Mandatory)

- Never run:
  - `git add`
  - `git commit`
  - `git push`
- Unless the user has clearly approved it in the current request.
- You should suggest at various intervals where a commit could be made.

## Project Patterns To Follow

- Keep gameplay logic in scripts and scene data in `.tscn` files.
- Build reusable systems (health, damage, interaction, UI binding) instead of hardcoding per scene.
- For composite enemies, keep root-level combat methods (`apply_damage()`, `is_dead()`, `take_damage()`) forwarding to the health-bearing child so hit detection can stay generic.
- Keep persistent progression/session state in an autoloaded manager so menu, levels, and one-time tutorial flags share a single source of truth.
- Use stable per-level node keys for persistent world state such as collected items, defeated enemies, and resumed checkpoints.
- Use exported variables for tuning gameplay values in the editor.
- Prefer signals/events for communication between nodes; avoid tight coupling.
- Keep backward compatibility when extending systems (for example wrapper methods like `take_damage()`).
- Isolate UI logic from core gameplay logic.
- Keep persistent screen-space HUD in dedicated `CanvasLayer` scenes or under the main game scene, not embedded inside per-level map scenes.
- Avoid duplicating logic between player and NPC/enemy scripts; share behavior through common patterns/resources.
- Make dangerous world elements data-driven (damage amount, cooldowns, effects).
- Keep names consistent and clear (`max_health`, `current_health`, `is_dead`, etc.).
- After major changes, verify related scenes where the script is used.

## Coding Guidelines

- Keep scripts simple and readable; avoid over-engineering.
- Add comments only where logic is non-obvious.
- Prefer deterministic behavior and guard clauses for invalid states.
- Preserve existing behavior unless the task explicitly changes it.

## Re-inforcement

- If a better pattern/practice/rule is found, you should modify the instructions.md to follow that.

- You must iteratively keep on improving the instruction.md with the time. Don't overdo/underdo it though. Do it when it makes total sense.

- If indefinitive whether to make changes or not, you can ask the user about those changes and take a permission.
