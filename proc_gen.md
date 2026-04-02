# Procedural Generation Guide

This document explains the procedural generation system added to this project for a 2D stealth platformer in Godot 4.6.

The system is designed to be:

- Modular
- Deterministic by seed
- Data-driven
- Reusable from gameplay code
- Callable by AI tools and agents
- Beginner-friendly to extend

## 1. High-Level Architecture

The system is split into three clean layers:

1. Tile definitions
2. Generators
3. Renderer

Text diagram:

```text
Gameplay / AI / Tools
        |
        v
  ProcGenService
        |
        +--> ProcGenRequest
        +--> ProcGenChunk
        +--> Agent Overrides
        |
        v
  Generator Layer
  - random
  - rule_based
  - noise
        |
        v
  ProcGenLayout
  - logical grid
  - multiple layers
  - metadata
        |
        +--> ProcGenTileCatalog
        |    logical tile properties
        |
        +--> ProcGenVisualTheme
             visual mapping into TileSet
        |
        v
  ProcGenTileMapRenderer
        |
        v
      TileMap
```

Core scripts:

- `game/scripts/procgen/procgen_service.gd`
- `game/scripts/procgen/procgen_layout.gd`
- `game/scripts/procgen/procgen_request.gd`
- `game/scripts/procgen/procgen_tile_catalog.gd`
- `game/scripts/procgen/procgen_tile_definition.gd`
- `game/scripts/procgen/procgen_visual_theme.gd`
- `game/scripts/procgen/procgen_tile_visual.gd`
- `game/scripts/procgen/procgen_tilemap_renderer.gd`
- `game/scripts/procgen/procgen_random_generator.gd`
- `game/scripts/procgen/procgen_rule_based_generator.gd`
- `game/scripts/procgen/procgen_noise_generator.gd`
- `game/scripts/procgen/procgen_chunk.gd`
- `game/scripts/procgen/procgen_debug_overlay.gd`
- `game/scripts/procgen/procgen_demo.gd`
- `game/scripts/procgen/procgen_defaults.gd`

## 2. Core Concepts

### 2.1 Logical Tiles vs Visual Tiles

The most important design rule is:

- Generation works with logical tile ids
- Rendering works with TileSet coordinates

Example:

- Generator places `floor`
- Renderer maps `floor` to a TileSet source and atlas coordinate

That means you can replace art without rewriting generator logic.

### 2.2 Layout

`ProcGenLayout` is the generated map in memory.

It stores:

- `width`
- `height`
- `layer_names`
- flat cell arrays for each logical layer
- `metadata`

Typical logical layers:

- `ground`
- `stealth`

You can add more later, for example:

- `decoration`
- `hazards`
- `navigation`
- `lighting`

### 2.3 Catalog

`ProcGenTileCatalog` stores tile definitions and their gameplay properties.

Example properties:

- `collision_enabled`
- `friction`
- `visibility`
- `danger`
- `blocks_light`
- `tags`

This is where tile behavior lives.

### 2.4 Visual Theme

`ProcGenVisualTheme` maps a logical tile to a real TileSet entry.

Each visual mapping stores:

- logical layer
- tile id
- TileMap layer index
- TileSet source id
- atlas coordinates
- alternative tile
- selection weight

This is where visuals live.

## 3. Tile Definitions

Example tile definitions are in:

- `game/scripts/procgen/procgen_defaults.gd`

Current default tiles:

- `air`
- `floor`
- `wall`
- `one_way`
- `spike`
- `shadow_zone`
- `light_zone`

Example:

```gdscript
_tile(&"floor", "Floor", true, 1.0, 0.8, 0.0, true, ["ground", "walkable_surface"])
_tile(&"spike", "Spike", true, 0.9, 1.0, 1.0, false, ["hazard"])
_tile(&"shadow_zone", "Shadow Zone", false, 1.0, 0.2, 0.0, false, ["stealth", "cover"])
```

Meaning:

- `floor` is collidable and moderately visible
- `spike` is dangerous
- `shadow_zone` is non-solid and lowers visibility for stealth

## 4. Generators

Three generator types are already implemented.

### 4.1 Random Generator

File:

- `game/scripts/procgen/procgen_random_generator.gd`

Use when:

- Prototyping fast maps
- Testing tile rendering
- Creating rough or chaotic layouts

Behavior:

- Builds a base floor
- Places random floating platforms
- Adds some shadow cover
- Places some hazard groups

### 4.2 Rule-Based Generator

File:

- `game/scripts/procgen/procgen_rule_based_generator.gd`

Use when:

- You want more controlled level flow
- You need reachable movement space
- You want better platform readability

Behavior:

- Builds a walkable path across the map
- Limits jump gap and rise changes
- Adds support pillars
- Adds stealth shadow beneath platforms
- Tracks spawn and goal in metadata

Important parameters:

- `floor_thickness`
- `max_gap`
- `max_rise`
- `min_platform`
- `max_platform`
- `shadow_depth`

### 4.3 Noise Generator

File:

- `game/scripts/procgen/procgen_noise_generator.gd`

Use when:

- You want more organic terrain
- You want cave-like or uneven space
- You want broad terrain variation from a seed

Behavior:

- Uses `FastNoiseLite`
- Builds varying floor heights
- Adds stealth layers under ceilings

Important parameters:

- `frequency`
- `floor_base`
- `floor_amplitude`
- `ceiling_base`

## 5. Chunk / Module Composition

File:

- `game/scripts/procgen/procgen_chunk.gd`

Chunks are reusable mini-layouts.

They store:

- id
- width
- height
- rows
- legend
- markers
- tags

Example concept:

- start room
- patrol corridor
- spike lane
- gap section
- stealth alcove

The service can compose chunk sequences:

```gdscript
var chunks := ProcGenDefaults.build_demo_chunks()
var layout := service.compose_chunk_sequence(request, chunks)
```

This is useful for:

- modular authored generation
- hybrid handcrafted + procedural level design
- future AI-generated chunk assembly

## 6. Determinism

Determinism is handled by the request seed.

If these stay the same:

- seed
- generator algorithm
- params
- chunk order
- theme selection logic

Then the generated result stays the same.

This is important for:

- debugging
- replays
- network sync planning
- saving procgen state
- AI experiments

## 7. Main API

The main entry point is:

- `game/scripts/procgen/procgen_service.gd`

Key methods:

- `generate_layout(request: ProcGenRequest) -> ProcGenLayout`
- `generate_layout_from_dict(request_data: Dictionary) -> ProcGenLayout`
- `compose_chunk_sequence(request: ProcGenRequest, chunks: Array[ProcGenChunk]) -> ProcGenLayout`
- `apply_agent_overrides(layout: ProcGenLayout, overrides: Array[Dictionary]) -> void`
- `serialize_layout(layout: ProcGenLayout) -> Dictionary`
- `debug_ascii(layout: ProcGenLayout, layer_name := &"ground") -> String`
- `get_request_schema() -> Dictionary`

This is the API gameplay code and AI tools should call.

## 8. Example: Generate a Level

```gdscript
var catalog := ProcGenDefaults.build_catalog()
var theme := ProcGenDefaults.build_theme()
var service := ProcGenService.new(catalog)

var request := ProcGenRequest.from_dict({
	"seed": 1337,
	"width": 96,
	"height": 32,
	"algorithm": "rule_based",
	"logical_layers": ["ground", "stealth"],
	"params": {
		"floor_thickness": 2,
		"max_gap": 4,
		"max_rise": 3,
		"min_platform": 4,
		"max_platform": 8,
		"shadow_depth": 2
	}
})

var layout := service.generate_layout(request)
ProcGenTileMapRenderer.new().render(layout, catalog, theme, $TileMap, request.seed)
```

## 9. AI / Tool Calling Support

This system was intentionally shaped so external agents can control it.

### 9.1 Dictionary-Based Requests

AI tools do not need to manually construct every GDScript object.

They can send a plain dictionary:

```gdscript
var layout := service.generate_layout_from_dict({
	"seed": 77,
	"width": 64,
	"height": 24,
	"algorithm": "noise",
	"logical_layers": ["ground", "stealth"],
	"params": {
		"frequency": 0.05,
		"floor_base": 13
	}
})
```

### 9.2 Agent Overrides

Agents can make targeted edits after generation:

```gdscript
"agent_overrides": [
	{"layer": "ground", "x": 10, "y": 18, "tile_id": "spike"},
	{"layer": "stealth", "x": 14, "y": 17, "tile_id": "shadow_zone"}
]
```

This is useful for:

- inserting special hazards
- placing stealth pockets
- enforcing mission-specific changes
- hybrid human + AI generation

### 9.3 Schema Export

`get_request_schema()` provides a machine-friendly request description for tool integrations.

## 10. TileMap Rendering

The TileMap renderer is in:

- `game/scripts/procgen/procgen_tilemap_renderer.gd`

It:

- clears used TileMap layers
- walks the logical layout
- resolves the logical tile id from the catalog
- looks up the visual mapping in the theme
- calls `TileMap.set_cell()`

Important point:

- The layout stores logical tile indexes
- The renderer converts those to visuals through the catalog and theme

## 11. How To Integrate Tiles Properly

This is the most important setup step.

### 11.1 Current Project Situation

Your existing level scenes such as:

- `game/scenes/levels/level_1_map.tscn`
- `game/scenes/levels/level_2_map.tscn`
- `game/scenes/levels/level_3_map.tscn`

embed a large TileSet directly in the scene.

That works for hand-authored levels, but for procedural generation the better setup is:

1. Move the reusable TileSet into a standalone `.tres`
2. Assign that TileSet to the TileMap used by procgen scenes
3. Map logical tile ids to the real TileSet atlas coords in `ProcGenVisualTheme`

### 11.2 Recommended Tile Integration Workflow

#### Step 1: Create a shared TileSet resource

In the Godot editor:

1. Open one of the current map scenes
2. Select the TileMap
3. Save its TileSet as a standalone resource such as:
   - `game/assets/tilesets/world_tileset.tres`
4. Reuse that TileSet in any procedural level scene

This gives you one source of truth for tiles.

#### Step 2: Decide which atlas cells correspond to gameplay tiles

Pick atlas cells for:

- floor
- wall
- one-way platform
- spike
- shadow overlay
- light overlay

Record:

- `source_id`
- `atlas_coords`
- `alternative_tile`

If you use one atlas source, `source_id` is often `0`.

#### Step 3: Update the visual theme

Edit:

- `game/scripts/procgen/procgen_defaults.gd`

Replace placeholder mappings:

```gdscript
_visual(&"ground", &"floor", 0, 0, Vector2i(0, 0))
_visual(&"ground", &"wall", 0, 0, Vector2i(2, 0))
_visual(&"ground", &"spike", 0, 0, Vector2i(4, 0))
_visual(&"stealth", &"shadow_zone", 1, 0, Vector2i(5, 0))
```

with the real atlas coordinates from your TileSet.

### 11.3 Recommended TileMap Layer Setup

Use at least two TileMap layers:

- Layer `0`: solid world tiles like floor/wall/platform/spike
- Layer `1`: stealth visuals like shadow and light zones

This matches the default procgen theme.

If you want more visual richness later:

- Layer `2`: detail decals
- Layer `3`: foreground cover

### 11.4 Collision Best Practice

There are two reasonable strategies.

#### Option A: Collision comes from TileSet tiles

Use when:

- each visual tile already has correct collision
- floor/wall/spike art directly match gameplay tiles

Pros:

- simple
- good for beginner use

Cons:

- logic and visuals are a bit more tightly coupled

#### Option B: Separate logic TileMap and art TileMap

Use when:

- you want maximum flexibility
- art may change often
- different skins should reuse the same layout logic

Recommended structure:

- `LogicTileMap`
  - hidden or debug-only
  - collision-enabled tiles
- `VisualTileMap`
  - visible art only

Then render the same layout through different themes.

For long-term scalability, this is the better architecture.

### 11.5 Changing Art Without Changing Generation

If you want to swap a tileset:

1. Keep the same logical tile ids
2. Create a new `ProcGenVisualTheme`
3. Change only the mapping from tile id to TileSet cell

Do not edit the generators unless gameplay rules actually changed.

## 12. Integrating Into This Project

### 12.1 Quick Demo Path

Attach:

- `game/scripts/procgen/procgen_demo.gd`

to a test scene with:

- a `TileMap`
- optionally a `ProcGenDebugOverlay`

On `_ready()`, it:

- builds the default catalog
- builds the default theme
- generates a level
- renders it to the TileMap

### 12.2 Recommended Real Integration Path

Your current runtime level loading is in:

- `game/scripts/game.gd`
- `game/scripts/level_manager.gd`

Recommended next integration:

1. Create a new procedural level scene, for example:
   - `game/scenes/levels/proc_level.tscn`
2. Add:
   - `TileMap`
   - `Marker2D` for spawn
   - optional debug overlay
3. Attach a new level script that:
   - creates a `ProcGenService`
   - generates a layout from a seed
   - renders to TileMap
   - reads `layout.metadata["spawn"]`
   - positions the player spawn marker
4. Add that level scene into `LevelManager.LEVELS`

This lets procgen levels participate in the same loading flow as hand-authored ones.

### 12.3 Suggested Procedural Level Script

```gdscript
extends GameLevel

@export var tile_map: TileMap
@export var seed: int = 1337

func _ready() -> void:
	var catalog := ProcGenDefaults.build_catalog()
	var theme := ProcGenDefaults.build_theme()
	var service := ProcGenService.new(catalog)

	var request := ProcGenRequest.from_dict({
		"seed": seed,
		"width": 96,
		"height": 32,
		"algorithm": "rule_based",
		"logical_layers": ["ground", "stealth"]
	})

	var layout := service.generate_layout(request)
	ProcGenTileMapRenderer.new().render(layout, catalog, theme, tile_map, seed)

	var spawn := layout.metadata.get("spawn", Vector2i(2, 2))
	var spawn_node := $PlayerSpawn
	spawn_node.position = Vector2(spawn.x * 16, spawn.y * 16)
```

Adjust tile size if your TileMap uses something other than `16x16`.

## 13. Performance Notes

The current implementation is already reasonable for large tilemaps because:

- layout data is stored in flat arrays
- generation works on integers, not scene instances
- rendering writes cells directly
- chunk composition stamps arrays instead of instantiating many nodes

For larger maps later, consider:

- generating only visible chunks
- splitting world generation by room/region
- caching serialized layouts by seed
- using batched scene placement for props/enemies after tile generation

## 14. Debugging

### 14.1 ASCII Debug Output

Use:

```gdscript
print(service.debug_ascii(layout, &"ground"))
```

This is useful for:

- checking connectivity
- debugging AI requests
- testing seeds quickly

### 14.2 Debug Overlay

File:

- `game/scripts/procgen/procgen_debug_overlay.gd`

It draws overlays for:

- collision
- danger
- low visibility

Use this when validating stealth gameplay and hazard placement.

## 15. Extending the System

Easy next extensions:

- add enemy spawn markers to metadata
- add patrol path generation
- add room graph generation
- add collectible placement pass
- add stealth score / visibility heatmap
- add level validation pass
- add biome-specific visual themes
- add mission templates for AI agents

Good pattern to follow:

1. Generator creates structure
2. Validation pass fixes or rejects invalid results
3. Decoration pass adds flavor
4. Spawn pass adds enemies/items
5. Renderer applies visuals

## 16. Beginner Rules Of Thumb

If you are extending this system, keep these rules:

- Add new gameplay behavior in tile definitions
- Add new visual look in the visual theme
- Add new generation logic in a generator
- Keep generators free of TileSet-specific atlas coords
- Pass everything important through `ProcGenRequest`
- Keep seeds stable during debugging

## 17. Recommended Next Steps

Best next steps for this project:

1. Extract the current embedded TileSet into a shared `.tres`
2. Create a `proc_level.tscn` test scene
3. Point `ProcGenDefaults.build_theme()` at real atlas coords
4. Add player spawn and goal placement from layout metadata
5. Add a post-pass for coins, enemies, and stealth patrol routes
6. Add a validation pass that ensures start-to-goal reachability

## 18. Summary

This procgen system gives you:

- modular tile logic
- separate visual mapping
- deterministic level generation
- rule-based and noise-based options
- reusable chunks/modules
- AI/tool-friendly control surface
- a clean path to integrate with your existing Godot project

Most important integration rule:

- Treat logical tiles and visual tiles as separate systems

That single choice will keep the project scalable as your stealth mechanics, art style, and AI tooling grow.
