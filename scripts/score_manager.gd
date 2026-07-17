extends Node
## Autoload ("ScoreManager"). Turns a level's run stats (from HUD.get_stats())
## into a real point score — the result screen's rank/efficiency readout was
## explicitly "not a hidden scoring system," this is the actual one.
##
## Wiring: title_screen resets the run total via reset_run() when a new game
## starts; ResultScreen calls score_level(stats) once per level completion
## and displays the returned level/total split; the ending scene reads
## total_score for the final tally.

const BASE_SCORE := 1000
const KICK_PENALTY := 80      ## per kick beyond the first
const REWIND_PENALTY := 50    ## per rewind used
const TIME_PAR := 150.0       ## seconds; finishing under this earns a time bonus
const TIME_BONUS_PER_SECOND := 4
const MAX_TIME_BONUS := 600
const MIN_LEVEL_SCORE := 100  ## completing a level is always worth something

var total_score: int = 0

## Call when a new game starts (title screen) so scores don't carry over
## from a previous playthrough.
func reset_run() -> void:
	total_score = 0

## Scores one completed level and adds it to the run total. Returns
## {"level_score": int, "total_score": int} for display.
func score_level(stats: Dictionary) -> Dictionary:
	var kicks: int = stats.get("kicks", 0)
	var rewinds: int = stats.get("rewinds", 0)
	var time: float = stats.get("time", 0.0)

	var kick_penalty := maxi(kicks - 1, 0) * KICK_PENALTY
	var rewind_penalty := rewinds * REWIND_PENALTY
	var time_bonus := clampi(int((TIME_PAR - time) * TIME_BONUS_PER_SECOND), 0, MAX_TIME_BONUS)

	var raw := BASE_SCORE - kick_penalty - rewind_penalty + time_bonus
	var level_score := maxi(raw, MIN_LEVEL_SCORE)
	total_score += level_score

	return {"level_score": level_score, "total_score": total_score}
