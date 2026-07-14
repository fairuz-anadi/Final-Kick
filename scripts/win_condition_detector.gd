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

@export var required_objects: Array[NodePath] = []
@export var debug_print_on_complete: bool = true

var _activated: Array[bool] = []
var _completed: bool = false

func _ready() -> void:
	_activated.resize(required_objects.size())
	_activated.fill(false)

	for i in required_objects.size():
		var target: Node = get_node_or_null(required_objects[i])
		if target == null:
			push_warning("WinConditionDetector: required object at index %d not found (%s)" % [i, required_objects[i]])
			continue
		if not target.has_signal("activated"):
			push_warning("WinConditionDetector: '%s' has no 'activated' signal" % target.name)
			continue
		target.connect("activated", _on_required_object_activated.bind(i))

func _on_required_object_activated(index: int) -> void:
	if _completed or _activated[index]:
		return
	_activated[index] = true
	if not _activated.has(false):
		_completed = true
		if debug_print_on_complete:
			print("WinConditionDetector: level complete — all %d required objects activated" % _activated.size())
		level_complete.emit()
