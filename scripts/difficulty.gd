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

## Fallback kick limit (Hard baseline) for any scene not in LEVEL_KICK_BASE
## below — e.g. a test/menu scene with a Ball but no real level layout.
const DEFAULT_KICK_BASE := 7

## Per-level Hard-difficulty kick base, sized to each room's objective count
## and mechanics (more targets, longer corridors, or extra hazards like
## Level 7's long chain or Level 10's finale all get more room). This is the
## tight, no-slack number — Medium and Easy scale it up via
## KICK_LIMIT_MULTIPLIER for a more forgiving margin.
const LEVEL_KICK_BASE := {
	"res://scenes/levels/level_1.tscn": 6,   # 1 target, straight lane
	"res://scenes/levels/level_2.tscn": 7,   # 2 targets, simple chain
	"res://scenes/levels/level_3.tscn": 8,   # 3 targets, angled bank shot
	"res://scenes/levels/level_4.tscn": 12,  # 5 targets across two chambers
	"res://scenes/levels/level_5.tscn": 10,  # 4 targets, pit split + burst-only far side
	"res://scenes/levels/level_6.tscn": 9,   # 3 targets, timed gate + overcharge
	"res://scenes/levels/level_7.tscn": 16,  # 8 targets down a 64m corridor
	"res://scenes/levels/level_8.tscn": 10,  # 4 targets, vials decay under time pressure
	"res://scenes/levels/level_9.tscn": 10,  # 3 targets, twin corridors both need clearing
	"res://scenes/levels/level_10.tscn": 16, # 6 targets, finale combines prior hazards
}

## Hard keeps LEVEL_KICK_BASE as-is (1.0x); Medium gives noticeably more
## room, and Easy more still, so the base table only has to be tuned once.
const KICK_LIMIT_MULTIPLIER := {
	Level.EASY: 2.0,
	Level.MEDIUM: 1.4,
	Level.HARD: 1.0,
}

## Factory Energy lost per kick beyond the level's limit (out of 100) —
## smaller than a ball loss, but it stacks the same way and can still
## trigger the critical warning or a full blackout.
const KICK_OVERAGE_DRAIN := {
	Level.EASY: 5.0,
	Level.MEDIUM: 8.0,
	Level.HARD: 12.0,
}

func drain_per_loss() -> float:
	return DRAIN_PER_LOSS[current]

func rewind_frames() -> int:
	return REWIND_FRAMES[current]

## `scene_path` should be the current scene's scene_file_path (ball.gd passes
## get_tree().current_scene.scene_file_path); unrecognized/empty paths fall
## back to DEFAULT_KICK_BASE so non-level test scenes still work.
func kicks_per_level(scene_path: String = "") -> int:
	var base: int = LEVEL_KICK_BASE.get(scene_path, DEFAULT_KICK_BASE)
	return maxi(1, roundi(base * KICK_LIMIT_MULTIPLIER[current]))

func kick_overage_drain() -> float:
	return KICK_OVERAGE_DRAIN[current]
