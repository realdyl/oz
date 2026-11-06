# Oz Development Folder

This is the development workspace for **Oz: The Road Home**.

## Current Progress: Prototype v0.3 (Kansas → Munchkinland)

**Main scene:** Kansas farmyard. Completing the storm loads Munchkinland landing.

### Implemented
- [x] **Level 1 Kansas** (`regions/kansas/farmyard.tscn`) — B&W farm, basket, Toto, debris, white-out handoff
- [x] **Level 2 Munchkinland** — Dorothy playable; shoes; Scarecrow Lead after claim
- [x] Arrows primary move; Party Lead on Munchkinland only
- [x] Headless: `smoke_check.gd`, `kansas_sim.gd`, `play_sim.gd` (Munchkinland)

### How to run
1. Open this folder in Godot 4.8+
2. Press **Play** (F5) — starts in Kansas
3. Basket → Toto → survive debris → large hit → Munchkinland

### Headless checks
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/smoke_check.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/kansas_sim.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/play_sim.gd
```

Agent protocol: `obsidian-oz/08 Technical/Agent Token Efficiency.md`  
Kansas design: `obsidian-oz/02 World/Kansas Farmyard Prologue.md`


## Input Map
Defined in `project.godot` (first binding = primary):
- `move_*` — arrows first, WASD second
- `blink` (Space), `kick` (F), `summon` (Q), `interact` (E)
- `switch_next` (Tab), `switch_dorothy` (1), `switch_scarecrow` (2), tin/lion 3–4 reserved

## Design bible
[realdyl/obsidian-oz](https://github.com/realdyl/obsidian-oz) — silver shoes (book canon), candy pastels with rot underneath, grey Kansas house as the last B&W object. Bond: `04 Systems/Party Control and the Bond.md`.
