extends CanvasLayer
## Autoload ("SettingsPanel"). Volume control — the one real usability gap
## left after the Music/SFX bus split: there was no way for a player to turn
## anything down. Reusable overlay like InstructionsPanel, opened from both
## the title screen and the pause menu. Persists to user://settings.cfg so
## the choice survives between sessions.

const SAVE_PATH := "user://settings.cfg"

@onready var _panel: Control = %Panel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SFXSlider

func _ready() -> void:
	_panel.visible = false
	_load_settings()

func open() -> void:
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false

func _on_music_slider_changed(value: float) -> void:
	_set_bus_volume("Music", value)
	_save_settings()

func _on_sfx_slider_changed(value: float) -> void:
	_set_bus_volume("SFX", value)
	_save_settings()

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.0001)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", _music_slider.value)
	cfg.set_value("audio", "sfx", _sfx_slider.value)
	cfg.save(SAVE_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_music_slider.value = cfg.get_value("audio", "music", 1.0)
	_sfx_slider.value = cfg.get_value("audio", "sfx", 1.0)
	_set_bus_volume("Music", _music_slider.value)
	_set_bus_volume("SFX", _sfx_slider.value)
