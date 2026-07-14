# Final Kick — Asset List (Samprity)

All assets are built from Godot primitives with shared materials — zero external
files, zero import pipeline, zero copyright risk (rulebook-safe). Every
interactive asset keeps the exact collision footprint of Anadi's greybox
stand-ins, so they swap in place without retuning physics.

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

## Integration reference

`scenes/samprity_showcase.tscn` shows every asset wired to Anadi's systems in
one dressed room, including the WorldEnvironment (glow + fog + ACES) that makes
the emissive materials read. Rabib: copy its lighting/environment setup into
the real levels.
