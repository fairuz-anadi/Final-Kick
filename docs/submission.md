# Final Kick — jam submission fields (Anadi)

Paste-ready answers for the IUT ICT Fest gamejam submission form. This is the
literal form-field content required by the rulebook checklist (engine,
install steps, how to play, links) — for the itch.io *store page* copy
(tagline, description, screenshots), see `docs/itchio_page.md` instead.

## Engine
Godot Engine 4.7 (stable)

## Install steps

**Web (recommended — no install)**
1. Open the game's itch.io page in a modern desktop browser (Chrome, Firefox,
   or Edge — Safari's WebGL2/WASM support has been inconsistent for Godot
   Web exports, so it isn't the primary target).
2. Click the embedded player. No download, no plugin, no account.

Verified: the exported build (`web-export/`) was served from a local static
file server and every asset (`index.html`, `index.js`, `index.wasm`,
`index.pck`) returned `200 OK` with correct MIME types, including
`application/wasm` on the `.wasm` file — a common misconfiguration that
silently breaks WASM instantiation on some hosts. That confirms the build
*serves* correctly as a zero-install static site. **Still needed before
submission:** an actual in-browser playthrough of the uploaded itch.io
build, since serving correctly isn't the same as confirming it runs —
someone needs to click through the itch.io page itself once it's live.

**Windows**
Not built — a deliberate scope call, not an unfinished task. The rulebook
requires "Windows and/or Web," and the zero-install checklist item is
already satisfied by the Web build alone. Producing a Windows build would
need a ~1.3GB one-time export-template download with no compliance benefit,
so it's being skipped. If the team wants a Windows build anyway later purely
as a nice-to-have, the steps would just be "download the .zip, extract, run
FinalKick.exe — no installer."

## How to play
- **Mouse** — aim
- **Hold Space** — charge the kick (power bar fills; the longer you hold, the harder the eventual kick)
- **Release Space** — kick
- **Hold R + Left/Right arrows** — scrub backward/forward through the last ~10 seconds to review what happened
- Goal: chain the kick through every gear, wire node, and vial in the room to complete it

## Team
- Anadi — systems & physics (kick, rewind, gear/vial/grid triggers, win condition, camera)
- Rabib — levels & sound
- Samprity — art, UI, shaders

## Links
- Repository: https://github.com/fairuz-anadi/Final-Kick
- Submitting Web-only, by design — see the Windows note above
- Video: pending Day 8 shoot

## Credits
See `CREDITS.md` at the project root (Samprity is keeping this current).
