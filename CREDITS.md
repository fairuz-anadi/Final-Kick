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
- Current SFX (kick thud, gear/grid clink, vial explosion, electric zap) are
  **placeholders** — synthesized procedurally at runtime in
  `scripts/placeholder_sfx.gd`, not recorded or sourced from anywhere, so no
  license entry is needed for them.
- Replace each with real recorded/sourced SFX when ready (swap the
  `PlaceholderSFX.play_*()` call at each trigger site), and add the source +
  license here once you do — the submission form requires a complete credits list.
