extends CanvasLayer
## Result screen (Samprity). Connect WinConditionDetector.level_complete →
## show_result(). Waits out the spectacle cam, then fades/scales in with the
## run's real stats (from the HUD) and an S/A/B/C rank.

@export var hud_path: NodePath
@export var spectacle_delay: float = 4.6
@export var next_scene: String = "res://scenes/ui/ending.tscn"

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
	get_tree().change_scene_to_file(next_scene)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
