# Oz — Prototype

Godot 4 prototype for **Oz: The Road Home**.

## Status

**v0.4.1 — playtest polish** (follow Lead · placements · signs · doors · stepped fields · Kansas shadows)

| Level | Scene | Role |
| --- | --- | --- |
| **1 · Kansas** | `regions/kansas/farmyard.tscn` | B&W prologue: basket → Toto → shutter → cellar → storm (**main scene**) |
| **2 · Munchkinland** | `regions/munchkinland/landing_square.tscn` | Color landing + party + combat lessons |

Open the `oz/` folder in Godot 4.8+ and press **Play**.

## Level 1 — Kansas

1. Find the **basket** — glowing post + compass (E)  
2. Find **Toto** — he joins the basket  
3. **Latch the farmhouse shutter** (E)  
4. **Check the cellar** (E) — Aunt Em call-out; storm starts either way  
5. **Dodge debris** (cannot fail the story)  
6. **Large debris** → white-out → Munchkinland  

Landmarks: barn, fence ring, clothesline, windmill.

| Input | Action |
| --- | --- |
| **Arrow keys** | Move (WASD secondary) |
| Mouse (auto-capture) | Look **360°** yaw |
| **Hold RMB + WASD** | Orbit camera (yaw/pitch) |
| **Z / C** | Orbit left / right |
| Click / Esc | Re-capture / release look |
| **E** | Interact (basket / Toto / shutter / cellar) |
| **F9** | Skip straight to Munchkinland (playtest) |
| **F8** | Skip to storm phase (playtest) |

No blink, kick, or Shoes in Kansas.

## Level 2 — Munchkinland (after transition)

| Input | Action |
| --- | --- |
| Arrows / WASD | Move |
| Mouse / RMB+WASD / Z·C | Look / orbit 360° |
| Space | Blink (Dorothy only) |
| **F** | **Kit verb** (see table) — always shows VFX label |
| E | Shoes · free / calm / oil · **enter/exit cottages** |
| **Tab** | Cycle Lead among unlocked friends — **whole party follows the Lead** |
| **1 · 2 · 3 · 4** | Dorothy · Scarecrow · Tin Man · Lion |

### Kit verbs (must Lead that character)

| Lead | F | What you should see |
| --- | --- | --- |
| Dorothy | **KICK** | Silver arc + “KICK” + hitstop on connect |
| Scarecrow | **CAW** | Yellow ring + crow sparks + enemies confuse (“?”) |
| Lion | **ROAR** | Orange expanding rings + enemies flee (“!”) |
| Tin Man | **AXE** | Steel slash + “AXE” + armor **SHATTER** on armored foes |

### Act spine (longer than unlock-only)

1. Claim **Silver Shoes**  
2. Clear **landing swarm** (kick lesson)  
3. Free **Scarecrow** (east path, glowing **SCARECROW** post) → **crow field** (CAW lesson)  
4. Calm **Lion** (follow orange **LION** posts north past the gate)  
5. Oil **Tin Man** (west **block terrace** — step up the ramps)  
6. Chop **Living Tree** gate (axe armor-break)  
7. Defeat **Marshal** rogue on the south road  
8. Open road / full party Tab cycle  

Wayfinding posts + billboard signs (no backwards DEBTS). Grass tufts; stepped terraces with collision (no walk-through hills). Cottages: **E** enter/exit. Rogue Munchkins are candy **puppets with limbs**, not snowmen.

If Tab does nothing useful, the HUD prompt says why. Shoes stay on Dorothy; Lead is agency only.

## GUI

Functional paper HUD only. Full GUI polish is **deferred** until this two-level spine is stable enough to replicate into later regions.

## Setup

See [README_DEV.md](./README_DEV.md). Design: [obsidian-oz](https://github.com/realdyl/obsidian-oz) · *Kansas Farmyard Prologue*.
