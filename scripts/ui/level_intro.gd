extends Control
## Shown between levels (see level_flow.gd) — a short story/description beat
## for the room the player's about to enter. Continues on a button press or
## the kick key, matching the title screen's "Space also starts" pattern.

const LEVEL_INFO := {
	"res://scenes/levels/level_2.tscn": {
		"eyebrow": "ENTERING — ROOM 02",
		"title": "SPARK THE LINE",
		"description": "Gears alone won't cut it here — you'll need the spark to jump before the chain runs cold.",
	},
	"res://scenes/levels/level_3.tscn": {
		"eyebrow": "ENTERING — ROOM 03",
		"title": "FULL CIRCUIT",
		"description": "Every system in this room is holding its breath. One wrong angle and it all stays dead.",
	},
	"res://scenes/levels/level_4.tscn": {
		"eyebrow": "ENTERING — FINAL ROOM",
		"title": "THE FINAL KICK",
		"description": "This is the last one. Whatever's waited at the center of this factory has been quiet for years — not for much longer.",
	},
	"res://scenes/levels/level_5.tscn": {
		"eyebrow": "ENTERING — ROOM 05",
		"title": "THE GAP",
		"description": "The line breaks here — half the machinery is stranded on the far side. A normal kick won't reach it. Charge past full and hold.",
	},
	"res://scenes/levels/level_6.tscn": {
		"eyebrow": "ENTERING — ROOM 06",
		"title": "OVERCHARGE",
		"description": "A gate seals the only way through, opening for a breath at a time. Charging past full buys range — but the longer you hold, the less you can trust your aim.",
	},
	"res://scenes/levels/level_7.tscn": {
		"eyebrow": "ENTERING — ROOM 07",
		"title": "THE LONG CHAIN",
		"description": "The longest hallway in the building, lined end to end with machinery. Nothing new to learn here — just a long way to fall if you miss one near the end.",
	},
	"res://scenes/levels/level_8.tscn": {
		"eyebrow": "ENTERING — ROOM 08",
		"title": "LEAKING VIALS",
		"description": "The chemical tanks here don't wait for anyone. Leave one too long and it goes off on its own terms — and it won't count for anything when it does.",
	},
	"res://scenes/levels/level_9.tscn": {
		"eyebrow": "ENTERING — ROOM 09",
		"title": "ECHO KICK",
		"description": "This gate only answers to two hits landing as one. Record a run, then live one alongside it — press E to bank the echo, then kick for real.",
	},
	"res://scenes/levels/level_10.tscn": {
		"eyebrow": "ENTERING — THE LAST ROOM",
		"title": "EVERYTHING, ONCE MORE",
		"description": "Gears, vials, wires, the gap, the gate — all of it, one last time, all in the same breath. This is the room the whole factory was leading to.",
	},
}

@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _prompt: Label = %Prompt

func _ready() -> void:
	var info: Dictionary = LEVEL_INFO.get(LevelFlow.next_level_path, {})
	_eyebrow.text = info.get("eyebrow", "ENTERING")
	_title.text = info.get("title", "NEXT ROOM")
	_description.text = info.get("description", "")

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _process(_delta: float) -> void:
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.003)
	_prompt.modulate.a = pulse

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("kick"):
		_continue()

func _on_continue_pressed() -> void:
	_continue()

func _continue() -> void:
	SceneTransition.go(LevelFlow.next_level_path)
