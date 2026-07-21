# FINAL KICK

> Kick. Rewind. Kick harder — until the dead factory breathes.

A 3D physics-puzzle game built in **Godot 4.7**. You're the last hope of a
factory that forgot how to move: one busted kicking device, ten dead rooms,
and a rewind button. Line up a kick, watch the chain ripple through gears,
wires and vials — and if it dies halfway, scrub time backward and try a
better angle.

## ▶ Play it now

**No install needed — play in your browser:**

### 🎮 [finalkick.vercel.app](https://finalkick.vercel.app)

Works in any modern desktop browser (Chrome, Firefox, Edge). Keyboard +
mouse required — not a mobile game.

## Requirements

**To play (browser):**
- A desktop browser with WebGL2/WASM support (Chrome, Firefox, or Edge recommended)
- Keyboard and mouse

**To run or edit from source:**
1. Install [Godot Engine 4.7 (stable)](https://godotengine.org/download)
2. Clone this repository:
   ```
   git clone https://github.com/fairuz-anadi/Final-Kick.git
   ```
3. Open Godot → **Import** → select the repo's `project.godot`
4. Press **F5** to run

**To export the web build yourself:**
- Install the 4.7 export templates (Editor → Manage Export Templates)
- Project → Export → **Web** preset → export to `web-export/index.html`

## How to play

**Goal:** wake every machine in the room — gears, wire panels, vials — to
complete it. Ten rooms total; each one adds a new twist.

| Input | Action |
|---|---|
| **Mouse** | Aim |
| **Hold Space** | Charge the kick (longer hold = harder kick) |
| **Release Space** | Kick |
| **Hold R + Left/Right** | Scrub backward/forward through time |
| **Right-drag mouse** | Orbit the camera around the room |
| **Scroll wheel** | Zoom toward the cursor |
| **1 / 2 / 3 / 4 / 5** | Snap camera: Front / Back / Left / Right / Top |
| **HOME** | Reset the camera shot |
| **P** | Pause |

**Worth knowing:**
- **No lives — Factory Energy.** Losing the ball drains the same meter you
  fill by waking machines. Drain it to zero after making real progress and
  the room blacks out and restarts.
- **Overcharge:** hold past full charge for extra power at the cost of a
  wobblier aim. Repeatable on any kick.
- **Final Kick burst:** hold *well* past full — once per room — for a huge
  burst that clears gaps nothing else can.
- **Kick limit.** Each room has a kick budget, sized to how many targets
  and how hard that room is (bigger on later, longer rooms). It's not a
  hard cutoff — every kick past the limit still fires, but drains Factory
  Energy instead of being free.
- **Difficulty** (Easy/Medium/Hard, on the title screen) scales the rewind
  window (~15s/~10s/~5s), how much a lost ball costs, and each room's kick
  limit (Hard is tightest; Medium and Easy give noticeably more room).
- **Leaderboard:** local top-5 by name (entered at the title screen). Every
  level clear counts toward the board — not just full runs.
- The ball earns a new look every room, from stock chrome to a white-hot
  finale form. Purely cosmetic.

## Features

- **Quantum Rewind** — an undo you can *scrub*, not just press
- **Chain reactions** — gears spin machinery, vials widen the blast, wire grids surge power along the chain
- **Leaking Vials** — some chemicals detonate on their own schedule, and a self-triggered blast doesn't count
- **Twin Circuits** — a forked room with a long drop in the middle; both sides need a perfect line
- **Factory Energy** — each room visibly and audibly wakes up as you clear it
- **Kick budget** — a per-room, difficulty-scaled kick limit; running dry doesn't lock you out, it just starts costing Factory Energy
- **A real ending** — a celebration screen, a narrated closing story, and an auto-opening results dashboard
- **Spectacle Cam** — the camera goes cinematic when the chain completes
- **Fully illustrated opening cinematic** with a skippable six-shot story

## Deployment (CI/CD)

Every push to `master` automatically exports the web build and deploys it to
[finalkick.vercel.app](https://finalkick.vercel.app) via GitHub Actions —
see [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml).

Manual deploy (from a machine with the Vercel CLI logged in):

```
godot --headless --export-release "Web" web-export/index.html
cd web-export
vercel deploy --prod --yes
```

## Team

- **Anadi** — systems & physics (kick, rewind, triggers, win conditions, camera)
- **Rabib** — level design & sound
- **Samprity** — art, UI & shaders

## Credits

Third-party assets and licenses are listed in [CREDITS.md](CREDITS.md).
