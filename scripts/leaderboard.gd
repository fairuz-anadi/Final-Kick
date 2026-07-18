extends Node
## Autoload ("Leaderboard"). A local, no-frills high-score table — one
## entry per username (highest score kept), capped to the top MAX_ENTRIES,
## persisted to user://leaderboard.cfg. No networking, no real database;
## just a sorted list on disk, same pattern as ScoreManager's best_score.

const SAVE_PATH := "user://leaderboard.cfg"
const MAX_ENTRIES := 5

## Array of {"name": String, "score": int}, sorted highest score first.
var entries: Array[Dictionary] = []

## Name typed into the title screen's prompt before Start — carried across
## the scene change so the ending screen can submit under it automatically.
## Not persisted; empty means the player skipped entering one.
var pending_name: String = ""

func _ready() -> void:
	_load()

## Adds/updates an entry for `username`. If the username already has an
## entry, keeps whichever score is higher (case-insensitive match, so
## "Anadi" and "anadi" are the same player). Returns true if the board
## actually changed — false for an empty name or a score that didn't beat
## that username's existing entry.
func submit_score(username: String, score: int) -> bool:
	var clean_name := username.strip_edges()
	if clean_name.is_empty():
		return false

	var existing := -1
	for i in entries.size():
		if entries[i].name.to_lower() == clean_name.to_lower():
			existing = i
			break

	var changed := false
	if existing == -1:
		entries.append({"name": clean_name, "score": score})
		changed = true
	elif score > int(entries[existing].score):
		entries[existing].score = score
		changed = true

	if changed:
		entries.sort_custom(func(a, b): return a.score > b.score)
		if entries.size() > MAX_ENTRIES:
			entries.resize(MAX_ENTRIES)
			# The cap may have just cut the very entry we appended (full board
			# + a score below everyone on it) — that's a "didn't make it",
			# not a save, and the caller's message must not claim otherwise.
			changed = entries.any(
				func(e): return e.name.to_lower() == clean_name.to_lower())
		if changed:
			_save()
	return changed

## Whether `username` currently holds a spot on the board. Lets callers that
## submit progressively (once per level clear) phrase their status message
## from the board's actual state instead of submit_score's return value —
## which is false for "same score already saved", not just "didn't make it".
func is_on_board(username: String) -> bool:
	var clean_name := username.strip_edges().to_lower()
	return entries.any(func(e): return e.name.to_lower() == clean_name)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("leaderboard", "entries", entries)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var loaded: Array = cfg.get_value("leaderboard", "entries", [])
	entries.assign(loaded)
	# A save from before the cap shrank (it used to be 10) can hold more
	# entries than the board now shows — trim to the current top MAX_ENTRIES.
	entries.sort_custom(func(a, b): return a.score > b.score)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
