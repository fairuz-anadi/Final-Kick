extends Node
class_name WinConditionDetector
## Tracks a list of objects that must each reach their own "activated" state
## (a Vial exploding, a Gear finishing its spin-up, a GridNode's first surge,
## etc.) and fires `level_complete` once every one of them has.
##
## Deliberately generic: any node with an `activated` signal can be listed in
## `required_objects`, regardless of type — this script never checks what
## kind of object it's tracking, only that the signal exists and fires.

signal level_complete

# CROSS-TEAM ADDITION (UI): additive only — reports "n of m targets done"
# whenever a tracked object activates, so the HUD can show live progress.
signal progress_changed(done: int, total: int)

@export var required_objects: Array[NodePath] = []
@export var debug_print_on_complete: bool = true

var _activated: Array[bool] = []
var _targets: Array[Node] = []
var _completed: bool = false

func _ready() -> void:
	_activated.resize(required_objects.size())
	_activated.fill(false)
	_targets.resize(required_objects.size())

	for i in required_objects.size():
		var target: Node = get_node_or_null(required_objects[i])
		_targets[i] = target
		if target == null:
			push_warning("WinConditionDetector: required object at index %d not found (%s)" % [i, required_objects[i]])
			continue
		if not target.has_signal("activated"):
			push_warning("WinConditionDetector: '%s' has no 'activated' signal" % target.name)
			continue
		target.connect("activated", _on_required_object_activated.bind(i))

	# A blackout in progress must not race a still-spinning gear into a win —
	# once the shutdown fade starts, this level can no longer complete.
	LifeManager.factory_shutdown.connect(func() -> void: _completed = true)

	# Deferred so a HUD connecting to progress_changed in its own _ready still
	# receives the initial 0-of-N state regardless of scene-tree order.
	_emit_progress.call_deferred()

func _on_required_object_activated(index: int) -> void:
	if _completed or _activated[index]:
		return
	_activated[index] = true
	# Factory-revival flourish (light bloom, spark burst, startup rumble,
	# energy bump) — the "machines coming back to life" feedback loop.
	if _targets[index] is Node3D:
		FactoryManager.on_machine_activated(_targets[index])
	_emit_progress()
	if not _activated.has(false):
		_completed = true
		if debug_print_on_complete:
			print("WinConditionDetector: level complete — all %d required objects activated" % _activated.size())
		PlaceholderSFX.play_level_complete()
		level_complete.emit()

func _emit_progress() -> void:
	progress_changed.emit(_activated.count(true), _activated.size())
