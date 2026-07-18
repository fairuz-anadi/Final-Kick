extends CanvasLayer
## Autoload ("DifficultyPanel"). Difficulty picker as its own page — same
## reusable-overlay pattern as InstructionsPanel/SettingsPanel, opened from
## the title screen's DIFFICULTY button. Selection persists to
## user://difficulty.cfg and the three buttons sync to Difficulty.current
## every time the page opens, so re-opening always shows what's active.

const SAVE_PATH := "user://difficulty.cfg"

@onready var _panel: Control = %Panel
@onready var _easy_button: Button = %EasyButton
@onready var _medium_button: Button = %MediumButton
@onready var _hard_button: Button = %HardButton

func _ready() -> void:
	_panel.visible = false
	_load_saved()

func open() -> void:
	_sync_buttons()
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false

func _sync_buttons() -> void:
	_easy_button.button_pressed = Difficulty.current == Difficulty.Level.EASY
	_medium_button.button_pressed = Difficulty.current == Difficulty.Level.MEDIUM
	_hard_button.button_pressed = Difficulty.current == Difficulty.Level.HARD

func _on_easy_toggled(pressed: bool) -> void:
	if pressed:
		_set_difficulty(Difficulty.Level.EASY)

func _on_medium_toggled(pressed: bool) -> void:
	if pressed:
		_set_difficulty(Difficulty.Level.MEDIUM)

func _on_hard_toggled(pressed: bool) -> void:
	if pressed:
		_set_difficulty(Difficulty.Level.HARD)

func _set_difficulty(level: Difficulty.Level) -> void:
	Difficulty.current = level
	var cfg := ConfigFile.new()
	cfg.set_value("difficulty", "level", level)
	cfg.save(SAVE_PATH)

func _load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	Difficulty.current = cfg.get_value("difficulty", "level", Difficulty.Level.MEDIUM)
