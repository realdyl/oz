# Oz Development Folder

This is the development workspace for **Oz: The Road Home**.

## Current Progress: Prototype v0.1 (Feel First)

We are currently implementing the "Feel First" prototype as defined in the [Prototype Plan](https://github.com/realdyl/obsidian-oz/blob/main/08%20Technical/Prototype%20Plan.md).

### Implemented:
- [x] Project structure and `project.godot` configuration.
- [x] Dorothy Controller:
  - WASD Movement & Rotation.
  - **Blink**: Short-distance teleport (Space).
  - **Kick**: Basic attack with collision and knockback (F).
- [x] Third-person Camera Manager.
- [x] Dummy Enemy for combat testing.

## How to Setup the Prototype in Godot 4.x

1. Open the folder in the Godot Engine.
2. **Player Setup**:
   - Create a `CharacterBody3D` scene.
   - Attach `res://actors/dorothy/player_controller.gd`.
   - Add a `Node3D` child named `CameraPivot` (set it slightly above the origin).
   - Add a `CollisionShape3D` (Capsule).
   - Add a `MeshInstance3D` (Capsule) for visibility.
3. **Camera Setup**:
   - Create a `Node3D` in the main scene.
   - Attach `res://systems/camera_manager.gd`.
   - Assign the Player node to the `target` property in the Inspector.
   - Add a `Camera3D` as a child of this node.
4. **Enemy Setup**:
   - Create a `CharacterBody3D` scene.
   - Attach `res://actors/enemies/dummy_enemy.gd`.
   - Add a `CollisionShape3D` and `MeshInstance3D` (Box).
5. **Scene Setup**:
   - Create a `Node3D` main scene.
   - Add a `StaticBody3D` floor (PlaneMesh + CollisionShape3D).
   - Add a `DirectionalLight3D` and `WorldEnvironment`.
   - Instantiate the Player and a few Dummy Enemies.

## Input Map
The following actions are defined in `project.godot`:
- `move_forward` (W)
- `move_backward` (S)
- `move_left` (A)
- `move_right` (D)
- `blink` (Space)
- `kick` (F)
- `summon` (Q)
- `interact` (E)
