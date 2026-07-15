extends CanvasLayer
## Result screen. Connect WinConditionDetector.level_complete →
## show_result(). Waits out the spectacle cam, then fades/scales in with the
## run's real stats (from the HUD) and an S/A/B/C rank.

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
]

@onready var _panel: Control = %Panel
@onready var _stats_label: Label = %Stats
@onready var _rank_label: Label = %Rank

func _ready() -> void:
	_panel.visible = false

func show_result() -> void:
	await get_tree().create_timer(spectacle_delay).timeout

	var stats := {"time": 0.0, "kicks": 0, "rewinds": 0, "targets_done": 0, "targets_total": 0}
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("get_stats"):
		stats = hud.get_stats()

	_stats_label.text = "TIME   %02d:%02d\nTARGETS   %d / %d\nKICKS USED   %d\nREWINDS USED   %d\nEFFICIENCY   %d%%" % [
		int(stats["time"]) / 60, int(stats["time"]) % 60,
		stats["targets_done"], stats["targets_total"],
		stats["kicks"], stats["rewinds"],
		_efficiency(stats),
	]
	_rank_label.text = _rank(stats)

	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Derived from real inputs only: every kick past the first and every rewind
# costs efficiency. Not a hidden scoring system — just a readout of the run.
func _efficiency(stats: Dictionary) -> int:
	var kicks: int = stats["kicks"]
	var rewinds: int = stats["rewinds"]
	return clampi(100 - maxi(kicks - 1, 0) * 15 - rewinds * 10, 10, 100)

## Fewest kicks and rewinds = the plan's stated goal, so that's the rank.
func _rank(stats: Dictionary) -> String:
	var kicks: int = stats["kicks"]
	var rewinds: int = stats["rewinds"]
	if kicks <= 1 and rewinds == 0:
		return "S"
	if kicks <= 2 and rewinds <= 1:
		return "A"
	if kicks <= 4 and rewinds <= 3:
		return "B"
	return "C"

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
