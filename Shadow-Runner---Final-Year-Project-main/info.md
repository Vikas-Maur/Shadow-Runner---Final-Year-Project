# Shadow Runner Visual Snapshot

## Characters
- **Player:** A small armored knight (`knight.png`), 32x32-frame pixel animation set (idle, run, jump). Readable silhouette with helmet plume and clean side-view motion.
- **NPC (current in-game):** `Elder Bran` uses `MiniOldMan.png` with a gentle 4-frame idle/walk loop; scaled up in scene, giving a classic retro-villager look.
- **Enemy:** Green slime (`slime_green.png`) with squashy 24x24-style frames and simple patrol behavior. A purple slime variant (`slime_purple.png`) is also present in assets.

## Sprite/Asset Style
- **Core style:** 2D pixel art with crisp nearest-neighbor rendering (no texture filtering, no mipmaps).
- **Palette feel:** Warm earthy browns/oranges for terrain, accented by bright collectible/UI colors.
- **Props/collectibles:** Animated gold coin strip, portal sheet with strong glow colors, fruits/items/object tiles for pickups and decor.
- **Character packs present:** Multiple mini human variants (noble, villager, worker, queen/princess, old man/woman), even if not all are instantiated in the main scene.

## Map Composition
- **Main map scene:** Single large `TileMap` with at least two named layers (`Background`, `Mid`) plus placed scene instances (coins, moving platforms, killzone).
- **Tilesets mixed into map:** `world_tileset`, `A4`, school/interior sets, seasonal midgrounds, dungeon/background strips, and object sheets.
- **Gameplay layout feel:** Side-scrolling platformer lane with jumps, hazards, coin lines, and light tutorial text prompts.

## Look and Feel Summary
- Retro arcade platformer vibe: readable, compact sprites, bright pickups, and chunky tile geometry.
- Visual mood blends **cozy/fantasy** (knight + villagers + slimes) with **adventure-school/dungeon tile variety** from the broader tileset library.
- Overall aesthetic is playful, approachable, and intentionally low-res.
