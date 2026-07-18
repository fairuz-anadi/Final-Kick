extends Node
## Autoload ("ScoreManager"). Turns a level's run stats (from HUD.get_stats())
## into a real point score — the result screen's rank/efficiency readout was
## explicitly "not a hidden scoring system," this is the actual one.
##
## Wiring: title_screen resets the run total via reset_run() when a new game
## starts; ResultScreen calls score_level(stats) once per level completion
## and displays the returned level/total split; the ending scene reads
## total_score for the final tally, and calls finish_run() to check/save a
## new best against previous playthroughs (persisted to user://score.cfg).

const BASE_SCORE := 1000
const KICK_PENALTY := 80      ## per kick beyond the first
const REWIND_PENALTY := 50    ## per rewind used
const TIME_PAR := 150.0       ## seconds; finishing under this earns a time bonus
const TIME_BONUS_PER_SECOND := 4
const MAX_TIME_BONUS := 600
const MIN_LEVEL_SCORE := 100  ## completing a level is always worth something

const SAVE_PATH := "user://score.cfg"

var total_score: int = 0
var best_score: int = 0
## What each level has already contributed to total_score (scene path -> pts),
## so re-clearing a level via RETRY replaces its contribution instead of
## stacking it — the run total can't be farmed by replaying an easy room.
var _level_scores: Dictionary = {}

func _ready() -> void:
	_load_best()

## Call when a new game starts (title screen) so scores don't carry over
## from a previous playthrough.
func reset_run() -> void:
	total_score = 0
	_level_scores.clear()

## Call once the run is fully complete (ending scene). Returns true if this
## run's total beat the previous best — saves the new best either way isn't
## needed since a non-beating run leaves the file untouched.
func finish_run() -> bool:
	if total_score <= best_score:
		return false
	best_score = total_score
	_save_best()
	return true

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	cfg.save(SAVE_PATH)

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = cfg.get_value("score", "best", 0)

## Scores one completed level and adds it to the run total (replacing this
## level's previous contribution if it was re-cleared — see _level_scores).
## Returns {"level_score": int, "total_score": int} for display.
func score_level(stats: Dictionary, level_path: String = "") -> Dictionary:
	var kicks: int = stats.get("kicks", 0)
	var rewinds: int = stats.get("rewinds", 0)
	var time: float = stats.get("time", 0.0)

	var kick_penalty := maxi(kicks - 1, 0) * KICK_PENALTY
	var rewind_penalty := rewinds * REWIND_PENALTY
	var time_bonus := clampi(int((TIME_PAR - time) * TIME_BONUS_PER_SECOND), 0, MAX_TIME_BONUS)

	var raw := BASE_SCORE - kick_penalty - rewind_penalty + time_bonus
	var level_score := maxi(raw, MIN_LEVEL_SCORE)
	if level_path != "":
		total_score -= int(_level_scores.get(level_path, 0))
		_level_scores[level_path] = level_score
	total_score += level_score

	return {"level_score": level_score, "total_score": total_score}
