# Final Kick — Credits

## Team
- **Anadi** — systems & physics (kick, rewind, triggers, win detection, spectacle cam)
- **Rabib** — level design, SFX, balancing
- **Samprity** — 3D assets, materials, UI, shaders, itch.io page

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
- Sound effects (kick thud, gear/grid clink, vial explosion, electric zap, UI
  hover/click/ding/max-power/level-complete) — Kenney, **CC0 1.0 Universal**
  (public domain, no attribution required): "Impact Sounds," "Sci-fi Sounds,"
  and "Interface Sounds" packs, https://kenney.nl/assets. Files live in
  `assets/audio/sfx/`; loaded in `scripts/placeholder_sfx.gd`.
- The rest of the roster (heart loss, factory shutdown, machine startup,
  narrator chime, sparks, rewind engage, charge ticks, the Worker's voice cue,
  plus the wind/clock/heartbeat ambient loops) are still **placeholders** —
  synthesized procedurally at runtime in the same file, not recorded or
  sourced from anywhere, so no license entry is needed for them yet. Replace
  each with real recorded/sourced SFX when ready (swap the
  `PlaceholderSFX.play_*()` call at each trigger site) and add the source +
  license here once you do — the submission form requires a complete credits list.
- The layered music (calm piano → ambient pad → full mix, driven by Factory
  Energy) and the quiet ambient factory hum are likewise synthesized
  procedurally in `scripts/audio_director.gd` — both are seamless loops/beds
  rather than one-shot effects, so synthesizing them permanently is a
  reasonable choice rather than an unfinished task; swap the
  `_synthesize_*_loop()` streams for real tracks if the team wants to later.
