# Player Controls

## Current Movement

- Move left: `A` or Left Arrow
- Move right: `D` or Right Arrow
- Jump: `Space`
- Interact: `I`
- Dash: `Left Shift` or `K`
- Sword attack: `J`
- Shoot: `L`

## Current Attacks

### Air Stomp

- Input: while in the air, press `S` or Down Arrow.
- Effect: the knight commits to a fast downward strike.
- Result on enemy contact: if the stomp lands from above, the enemy takes stomp damage and the knight bounces back upward.
- Result on bad timing: if the knight falls into an enemy without a valid stomp, the enemy still hurts the player.

### Sword Slash

- Input: press `J`.
- Effect: the knight performs a short front-facing sword swing.
- Hit rules: each swing can damage a target once.
- Best use: sword is the reliable close-range attack for side approaches and grounded combat.

### Knight Shot

- Input: press `L`.
- Effect: the knight fires a fast horizontal shot in the facing direction.
- Hit rules: each shot travels straight, damages the first target it reaches, and disappears on hit or on wall contact.
- Best use: shooting is for safe mid-range pressure before closing in with the sword or committing to a stomp.

## Shooting Ground Rules

- The knight only shoots forward in the current facing direction. There is no up/down aiming.
- Shooting has a short cooldown, so it is a pacing tool, not a rapid-fire stream.
- Shooting is blocked while dashing, during a sword swing, and during an active stomp dive so attack states stay readable.
- Shots are single-hit projectiles: one enemy, one hit, then the projectile is spent.
- Projectile damage uses the same typed-damage system as the other attacks, so enemies can tune projectile resistance separately in `game/scripts/npc.gd`.

## Movement Feel Upgrades

### Coyote Time

- You still get a small jump window after stepping off a ledge.
- This makes platforming more forgiving and removes missed jumps caused by single-frame timing.

### Jump Buffer

- If jump is pressed just before landing, the jump is stored briefly and triggers on landing.
- This makes chained jumps more reliable.

### Short Hop

- Tapping jump gives a shorter jump.
- Holding jump gives full height.

### Dash

- Input: `Left Shift` or `K`
- Effect: a quick horizontal burst in the current facing direction.
- Use it to cross gaps, recover spacing, or avoid hazards.

## Tuning Notes

- Dash, stomp, and jump feel values are exported in `game/scripts/player.gd`, so they can be adjusted from the editor later without changing the code.
- The sword uses `game/assets/sprites/sword.png` as a separate sprite so it can be iterated independently from the knight sheet.
- Sword damage, shooting values, stomp timing, and movement feel values are all exported in `game/scripts/player.gd`.
