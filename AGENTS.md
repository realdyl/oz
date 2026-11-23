# Oz: The Road Home — Godot Game Repository (`realdyl/oz`)

## Purpose
Playable Godot 4.8+ prototype and production codebase for **Oz: The Road Home**.
Design bible and living roadmap live in the companion vault: `../obsidian-oz/` (`realdyl/obsidian-oz`).

## Local Contracts
- **Separate Git Repository:** `oz/` is its own git repo (`realdyl/oz`, branch `main`). Never commit vault notes here, and never commit Godot code into `obsidian-oz/`.
- **Auto-Git Policy (Mandatory):** Follow `../obsidian-oz/08 Technical/Auto Git Policy.md`:
  1. Update `../obsidian-oz/09 Production/Prototype Progress Log.md` and relevant roadmap checkboxes as work lands.
  2. Verify all headless checks pass before committing (`smoke_check.gd`, `kansas_sim.gd`, `play_sim.gd`, `act34_sim.gd`).
  3. Stage only intentional files (never `.godot/`, `.DS_Store`, or secrets).
  4. Commit with a concise conventional message (`Ship …`, `Upgrade …`, `Fix …`) and push `main` to `origin` in **both** `oz` and `obsidian-oz` after every landed, verified pass.
- **Keep Existing Contracts Stable:**
  - `PlayHUD` (`res://ui/play_hud.tscn` + `play_hud.gd`): keep `CanvasLayer` root named `PlayHUD`, group `"hud"`, direct child `Fade` (`ColorRect`), hidden `ThreatCompass` (`Label`), and methods `set_objective`, `set_prompt`, `set_kansas_mode`, `set_party_roster`.
  - Keep `DialogueUI`, `LevelTransition`, `Party`, `Whimsy`, and `CombatFx` public APIs backward-compatible.
- **Anti-Minecraft Visual Standard:** All new 3D props, characters, buildings, and foliage should use layered silhouettes, stylized PBR roughness/metallic response, and `res://systems/world_kit.gd` helpers—never bare unshaded `BoxMesh` slabs or uncapped horizon `Label3D` clutter.

## Verification Commands
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/smoke_check.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/kansas_sim.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/play_sim.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/act34_sim.gd
```
