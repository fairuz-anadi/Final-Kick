# Final Kick — Asset List

All 3D models and materials are built from Godot primitives by the team — zero
external files, zero import pipeline for visuals. Every interactive asset keeps
the exact collision footprint of the original greybox stand-ins, so they swap
in place without retuning physics. Sound effects are the one external asset
category in the project — see **Sound effects** below for the license.

## Materials (`assets/materials/`)

| Material | Used for | Room language |
|---|---|---|
| `brass.tres` | gears, seesaw plank | mechanical — warm brass |
| `rust_metal.tres` | dominoes, crates, cork | mechanical — rust |
| `dark_metal.tres` | hubs, panels, pipes, trim | neutral factory steel |
| `concrete.tres` | floors, walls | neutral factory shell |
| `green_glass.tres` | vial glass | chemical — sickly green |
| `green_liquid.tres` | vial contents (emissive) | chemical |
| `wire_glow.tres` | wire strips, domino stripe, ball strap | electrical — cyan glow |
| `amber_lamp.tres` | panel indicator lamps | electrical |
| `ball_device.tres` | the kick ball | player — pale + cyan rim |
| `ghost_material.tres` | ball during rewind scrub | rewind state |

## Interactive assets (`assets/models/`)

| Scene | Script attached | Notes |
|---|---|---|
| `gear.tscn` | `gear.gd` | 8-tooth brass gear, same 0.6 collision radius as greybox; set `connected_gears` per level |
| `vial.tscn` | `vial.gd` | glass + emissive liquid; same 0.3×0.5×0.3 collision box |
| `wire_panel.tscn` | `grid_node.gd` | panel mesh is the first child so the surge flash targets it; set `connected_nodes` |
| `domino.tscn` | — (pure physics) | rest height y=0.55 on flat ground |
| `crate.tscn` | — (pure physics) | rest height y=0.3 |
| `seesaw_lever.tscn` | — (pure physics) | plank on fixed cylinder, no joints |

## Environment (`assets/models/`)

| Scene | Notes |
|---|---|
| `factory_wall.tscn` | 6×3 m section, scale/rotate around perimeter |
| `pipe.tscn` | lies along X, scale root X for length |

## VFX (`assets/shaders/`, `assets/models/`)

| File | What it is |
|---|---|
| `kick_trail.tscn` | glow trail particles — drop as child of the Ball |
| `ghost.gdshader` | fresnel hologram look for the rewind ghost |
| `rewind_overlay.gdshader` | full-screen desaturate/scanline/vignette while scrubbing |

## UI (`scenes/ui/`, `scripts/ui/`)

- `hud.tscn` — charge meter, timeline scrub bar, rewind overlay + ghost swap, control hints. Set `ball_path` on the instance.
- `win_screen.tscn` — connect `WinConditionDetector.level_complete` → `show_win()`; waits for the spectacle cam before appearing.
- `title_screen.tscn` — game entry (set as main scene). Space starts.
- `ending.tscn` — final story beat + credits.

## Sound effects (`assets/audio/sfx/`)

| File | Used for | Source |
|---|---|---|
| `kick_thud.ogg` | ball kick | Kenney "Impact Sounds" |
| `gear_clink.ogg` | gear/grid trigger | Kenney "Impact Sounds" |
| `vial_explosion.ogg` | vial explosion | Kenney "Sci-fi Sounds" |
| `grid_zap.ogg` | grid/wire surge | Kenney "Sci-fi Sounds" |
| `ui_hover.ogg` / `ui_click.ogg` | button hover/press | Kenney "Interface Sounds" |
| `target_ding.ogg` | target-activated notification | Kenney "Interface Sounds" |
| `max_power.ogg` | max-power kick callout | Kenney "Interface Sounds" |
| `level_complete_motor.mp3` | level-complete motor spin-up | team recording (replaced Kenney chime; old `level_complete.ogg` unused) |
| `heart_loss.ogg` | life lost | Kenney "Interface Sounds" |
| `shutdown.ogg` | factory shutdown | Kenney "Sci-fi Sounds" |
| `narrator_blip.ogg` | narrator line cue (also the Worker's voice, pitched down) | Kenney "Interface Sounds" |
| `spark.ogg` | ambient/activation spark | Kenney "Interface Sounds" |
| `rewind.ogg` | rewind engage | Kenney "Interface Sounds" |
| `charge_tick.ogg` | charge-stage tick (pitch varies per stage) | Kenney "Interface Sounds" |

License: **CC0 1.0 Universal** (public domain, no attribution required) —
https://kenney.nl/assets, license copy in `assets/audio/sfx/KENNEY_LICENSE.txt`.
Loaded via `scripts/placeholder_sfx.gd`. The three looping ambient beds (wind,
clock, heartbeat) plus the ambient factory hum and layered music stay
synthesized procedurally — all seamless loops/beds, not one-shot effects, and
Kenney's packs didn't have a loop-safe real substitute for the first three.

## Integration reference

`scenes/tech_demo_showcase.tscn` shows every asset wired to the game's systems
in one dressed room, including the WorldEnvironment (glow + fog + ACES) that
makes the emissive materials read. Copy its lighting/environment setup into
the real levels.
