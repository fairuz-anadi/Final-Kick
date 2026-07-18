extends CanvasLayer
## Result screen. Connect WinConditionDetector.level_complete →
## show_result(). Waits out the spectacle cam, then fades/scales in with the
## run's real stats (from the HUD) and a playful earned title — no letter
## grades, no efficiency math: every clear gets crowned with something fun.

@export var hud_path: NodePath
@export var spectacle_delay: float = 4.6
@export var ending_scene: String = "res://scenes/ui/ending.tscn"

## Single source of truth for level sequencing. NEXT LEVEL looks up the
## scene that's currently running in this list and advances by one — add
## new levels here and every result screen picks it up automatically,
## instead of having to set a "next scene" override on every level.
const LEVEL_ORDER: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	"res://scenes/levels/level_4.tscn",
	"res://scenes/levels/level_5.tscn",
	"res://scenes/levels/level_6.tscn",
	"res://scenes/levels/level_7.tscn",
	"res://scenes/levels/level_8.tscn",
	"res://scenes/levels/level_9.tscn",
	"res://scenes/levels/level_10.tscn",
]

@onready var _panel: Control = %Panel
@onready var _stats_label: Label = %Stats
@onready var _rank_label: Label = %Rank
@onready var _score_label: Label = %ScoreLabel
@onready var _flawless_badge: Label = %FlawlessBadge

func _ready() -> void:
	_panel.visible = false

func show_result() -> void:
	await get_tree().create_timer(spectacle_delay).timeout

	var stats := {"time": 0.0, "kicks": 0, "rewinds": 0, "targets_done": 0, "targets_total": 0, "best_chain": 0}
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("get_stats"):
		stats = hud.get_stats()

	_stats_label.text = "TIME   %02d:%02d\nMACHINES   %d / %d\nKICKS   %d" % [
		int(stats["time"]) / 60, int(stats["time"]) % 60,
		stats["targets_done"], stats["targets_total"],
		stats["kicks"],
	]
	_rank_label.text = _earned_title(stats)
	_flawless_badge.visible = stats["rewinds"] == 0

	var score := ScoreManager.score_level(stats)
	_score_label.text = "SCORE  +%d   ·   TOTAL  %d" % [score["level_score"], score["total_score"]]

	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The title slams in a beat after the panel, oversized then elastic-settling.
	_rank_label.pivot_offset = _rank_label.size / 2.0
	_rank_label.scale = Vector2(2.2, 2.2)
	_rank_label.modulate.a = 0.0
	var title_tween := create_tween()
	title_tween.tween_interval(0.35)
	title_tween.tween_property(_rank_label, "modulate:a", 1.0, 0.12)
	title_tween.parallel().tween_property(_rank_label, "scale", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Every run earns a crown — the checks run best-first, so the most
## impressive thing the player did is the thing that gets named.
func _earned_title(stats: Dictionary) -> String:
	var kicks: int = stats["kicks"]
	var rewinds: int = stats["rewinds"]
	var best_chain: int = stats.get("best_chain", 0)
	var total: int = stats["targets_total"]
	if kicks <= 1 and total > 1:
		return "ONE-KICK WONDER"
	if best_chain >= 5 or (total > 0 and best_chain >= total and best_chain >= 3):
		return "FULL MELTDOWN"
	if best_chain == 4:
		return "CHAIN REACTOR"
	if best_chain == 3:
		return "TRIPLE THREAT"
	if best_chain == 2:
		return "DOUBLE TROUBLE"
	if rewinds >= 4:
		return "TIME BENDER"
	if stats["time"] <= 30.0:
		return "SPEED DEMON"
	return "FACTORY HERO"

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_next_pressed() -> void:
	LevelFlow.go_to_level(_next_scene())

## The level after whichever one is currently running, or the ending scene
## if the current scene isn't in LEVEL_ORDER (shouldn't happen) or is the
## last entry in it (the real "you beat the game" case).
func _next_scene() -> String:
	var current_path := get_tree().current_scene.scene_file_path
	var index := LEVEL_ORDER.find(current_path)
	if index == -1 or index + 1 >= LEVEL_ORDER.size():
		return ending_scene
	return LEVEL_ORDER[index + 1]

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
