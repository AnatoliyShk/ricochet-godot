# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Ricochet** is a 2D top-down shooter built with Godot 4.5 (Forward Plus renderer). The player shoots projectiles that ricochet off walls to defeat enemies.

## Development Commands

This is a Godot 4.5 project. Open `project.godot` in the Godot editor to run, edit scenes, or export. There is no CLI build system — all running and testing happens through the Godot editor or exported binary.

- **Run game**: Open in Godot editor → F5 (run project) or F6 (run current scene)
- **Main scene**: `room.tscn`

## Architecture

### Scene & Script Pairing
Each gameplay element is a `.tscn` scene with a paired `.gd` script. The root scene `room.tscn` composes everything.

### Projectile System (`projectile.gd`, `projectile.tscn`)
The core mechanic. Projectiles use **raycast-based movement** (not RigidBody2D physics) for deterministic reflection:
- Each frame, a raycast checks ahead along the velocity vector
- On wall hit, velocity is reflected using the surface normal
- Up to 3 ricochets; bullet turns green after first bounce
- Shooter exclusion: bullet ignores collision with player until it travels 50px
- Bullets only damage enemies if they have ricocheted at least once

### Collision Groups
Group membership drives all cross-object communication:
- `"player"` — the player node
- `"enemies"` — enemy nodes
- `"walls"` — wall segments (StaticBody2D nodes that bullets reflect off)
- `"hud"` — HUD CanvasLayer (receives `update_health` calls)
- `"damage_effect"` — damage vignette layer (receives `trigger` calls)

### Health & Damage Flow
1. Projectile detects enemy via `area_entered` → calls `take_damage(amount, direction)`
2. Enemy/player flashes, applies knockback, decrements HP
3. Player death → `get_tree().reload_current_scene()`
4. HUD updates via `get_tree().get_nodes_in_group("hud")[0].update_health(hp, max_hp)`

### Visual Layers (CanvasLayer z-order)
- Layer -1: Black background
- Layer 2: HUD (`UILayer` with `hud.gd`)
- Layer 9: Bloom post-process shader
- Layer 10: CRT scanlines + vignette shader; also displays player HP via shader uniform
- Layer 11: Damage effect (red vignette on hit, `damage_effect.gd` + `damage_effect.gdshader`)

### Wall Types
- `wall_segment.gd` — static wall; shakes on bullet impact
- `rotating_wall.gd` — toggles 90° between horizontal/vertical on bullet impact; both extend StaticBody2D and belong to `"walls"` group

### Camera (`camera_2d.gd`)
Smooth follow with mouse look-ahead (up to 150px offset toward cursor). Attached as a child of the player node.

### Laser Sight (`ricochet_laser_sight.gd`)
Right-click shows a trajectory preview of up to 3 ricochets. Uses the same raycast reflection math as `projectile.gd` to predict the path, then draws animated flowing arrows along it.

### HUD (`hud.gd`)
Entirely procedural — no `.tscn` file. Creates health bar, progress bar, and HP label via code using `StyleBoxFlat`. Pulses orange/red when HP ≤ 1.

### Input Map
Defined in `project.godot`:
- `move_left/right/up/down` → WASD
- `shoot` → Left mouse button
- Right mouse button (hardcoded in laser sight) → trajectory preview
- F11 (hardcoded in player) → toggle fullscreen
