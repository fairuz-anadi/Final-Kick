# Final Kick — jam submission fields

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
- **Hold R + Left/Right arrows** — scrub backward/forward through the last ~10 seconds (Easy/Hard widen or narrow this window — see Difficulty below)
- **P** — pause
- Goal: wake every gear, wire node, and vial in the room to complete it

**Factory Energy, not lives.** There are no hearts. Losing the ball (falling
out of bounds or touching a hazard) drains Factory Energy — the same meter
you're filling by waking machines — and respawns the ball with progress
intact. Before any machine in the room is awake, a lost ball costs nothing;
once you've made real progress, draining the meter to zero triggers a full
"Power Lost" blackout and restarts the level.

**Final Kick burst.** Available every level, once per level. Hold well past
full charge and keep holding — a supercharged kick arms itself, strong
enough to clear a gap a normal kick can't reach. Firing it spends it for
that level; losing the ball doesn't — it carries over until you actually use it.

**Overcharge.** Repeatable on every kick, in every room, including after a
level's Final Kick has been spent: hold past full charge for extra range and
power, at the cost of a wobblier aim. Trades precision for reach, every time.

**Leaking Vials** *(Level 8)*. These destabilize on real elapsed time — even
while rewinding — and detonate on their own if left too long. A self-triggered
vial does **not** count toward clearing the room, so stalling isn't free.

**Echo Kick** *(Level 9)*. Press **E** to bank the ball's current run as a
replaying "echo" ghost, then reset and take a second, live attempt — the room
only clears if both the echo and the live kick land their hits within a
fraction of a second of each other.

**The story.** A fully illustrated, six-shot opening cinematic (skippable via
a single dedicated SKIP button — no key/click shortcuts, so it can't be cut
short by accident) frames the run: an old worker kept a dead factory company
for decades; a kid finds his workshop and his final invention — a device
that kicks — and picks up where he left off. During gameplay, a narrator
comments through the run, and the same global "Factory Energy" meter that
tracks your run also visibly and audibly brings each room back to life as
its objectives are cleared — lighting, ambient dressing, and the music layer
all respond to it.

**Difficulty.** Chosen on the title screen before Start (Easy/Medium/Hard).
It scales two things: how much Factory Energy a lost ball costs (12/20/30
out of 100), and the rewind window's length (~15s/~10s/~5s).

**Leaderboard.** A local top-10 high-score table, entered by name on the
title screen and saved on-device — no account or networking involved.

## Team
- Anadi — systems & physics (kick, rewind, gear/vial/grid triggers, win condition, camera)
- Rabib — levels & sound
- Samprity — art, UI, shaders

## Links
- Repository: https://github.com/fairuz-anadi/Final-Kick
- Submitting Web-only, by design — see the Windows note above
- Video: pending Day 8 shoot

## Credits
See `CREDITS.md` at the project root (kept current alongside the art/UI work).
