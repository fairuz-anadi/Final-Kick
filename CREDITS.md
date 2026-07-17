# Final Kick — Credits


## Engine & tools
- Godot Engine 4.7 (MIT license) — https://godotengine.org
- Jolt Physics (via Godot) — MIT license

## Assets
- All 3D models built from Godot primitive meshes by the team (no external assets)
- All materials and shaders written by the team

## Fonts (SIL Open Font License 1.1 — license files in assets/fonts/)
- Orbitron — Matt McInerney (via Google Fonts)
- Rajdhani — Indian Type Foundry (via Google Fonts)

## Audio
- All sound effects (kick thud, gear/grid clink, vial explosion, electric zap,
  UI hover/click/ding/max-power/level-complete, heart loss, factory shutdown,
  machine startup, narrator chime, spark, rewind engage, charge tick) —
  Kenney, **CC0 1.0 Universal** (public domain, no attribution required):
  "Impact Sounds," "Sci-fi Sounds," and "Interface Sounds" packs,
  https://kenney.nl/assets. Files live in `assets/audio/sfx/`; loaded in
  `scripts/placeholder_sfx.gd`. The Worker's voice cue reuses the narrator
  chime pitched down, rather than a separate file.
- The three looping ambient beds (wind, clock, heartbeat) are still
  synthesized procedurally at runtime in the same file — none of Kenney's
  packs had a seamless ambience loop that fit, and a mis-picked loop's audible
  seam was a worse risk than a guaranteed-clean synthesized one. Swap them for
  real loops later by replacing their `_synthesize_*_loop()` call site.
- The layered music (calm piano → ambient pad → full mix, driven by Factory
  Energy) and the quiet ambient factory hum are likewise synthesized
  procedurally in `scripts/audio_director.gd`, for the same reason — both are
  seamless loops/beds rather than one-shot effects.
