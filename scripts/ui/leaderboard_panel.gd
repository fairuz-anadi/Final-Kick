extends CanvasLayer
## Autoload ("LeaderboardPanel"). Read-only ranked view of Leaderboard's
## saved entries — opened from the title screen's main menu. Rows are built
## fresh each time the panel opens since the list changes between runs.

@onready var _panel: Control = %Panel
@onready var _list: VBoxContainer = %EntriesList

func _ready() -> void:
	_panel.visible = false

func open() -> void:
	_refresh()
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	if Leaderboard.entries.is_empty():
		var empty := Label.new()
		empty.text = "NO SCORES YET — BE THE FIRST"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
		_list.add_child(empty)
		return

	for i in Leaderboard.entries.size():
		var entry: Dictionary = Leaderboard.entries[i]
		_list.add_child(_build_row(i + 1, str(entry.name), int(entry.score)))

func _build_row(rank: int, player_name: String, score: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var rank_label := Label.new()
	rank_label.text = "%d." % rank
	rank_label.custom_minimum_size = Vector2(32, 0)
	rank_label.add_theme_color_override("font_color", Color(0.95, 0.42, 0.88, 1))
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.918, 0.918, 0.918, 1))
	row.add_child(name_label)

	var score_label := Label.new()
	score_label.text = str(score)
	score_label.add_theme_color_override("font_color", Color(1, 0.714, 0.153, 1))
	row.add_child(score_label)

	return row
