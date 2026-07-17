extends Node
## Autoload ("Difficulty"). Global difficulty selection, picked on the title
## screen before Start (see title_screen.gd/.tscn). Two knobs scale with it:
## LifeManager reads drain_per_loss(), ball.gd reads rewind_frames() in its
## _ready(). Persists for the whole run (title screen -> ending), since it's
## an autoload rather than scene-local state.

enum Level { EASY, MEDIUM, HARD }

var current: Level = Level.MEDIUM

## Factory Energy lost per ball loss (out of 100). Easy forgives mistakes
## with a smaller penalty; Hard punishes them harder. Medium matches the
## game's original fixed value.
const DRAIN_PER_LOSS := {
	Level.EASY: 12.0,
	Level.MEDIUM: 20.0,
	Level.HARD: 30.0,
}

## Rewind history length in physics frames (60fps). Easy gives a longer undo
## window; Hard shortens it. Medium matches the game's original ~10s default.
const REWIND_FRAMES := {
	Level.EASY: 900,   # ~15s
	Level.MEDIUM: 600, # ~10s
	Level.HARD: 300,   # ~5s
}

func drain_per_loss() -> float:
	return DRAIN_PER_LOSS[current]

func rewind_frames() -> int:
	return REWIND_FRAMES[current]
