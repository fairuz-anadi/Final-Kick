extends Node
class_name SyncGateLock
## Level 9 (Echo Kick). Opens only if two separate GridNodes both surge
## within `sync_window` seconds of each other — built so a live kick and a
## previously recorded Echo ghost's kick have to land at (almost) the same
## instant, not just both happen at some point during the run.

signal activated

@export var node_a: NodePath
@export var node_b: NodePath
@export var sync_window: float = 0.5
@export var lamp_a_path: NodePath  # optional: visual feedback, lit once node_a's side has fired
@export var lamp_b_path: NodePath

var _last_a: float = -INF
var _last_b: float = -INF
var _opened: bool = false

func _ready() -> void:
	var a := get_node_or_null(node_a)
	var b := get_node_or_null(node_b)
	if a and a.has_signal("surged"):
		a.surged.connect(_on_a)
	if b and b.has_signal("surged"):
		b.surged.connect(_on_b)

func _on_a(_source) -> void:
	_last_a = _now()
	_light(lamp_a_path)
	_check()

func _on_b(_source) -> void:
	_last_b = _now()
	_light(lamp_b_path)
	_check()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _light(lamp_path: NodePath) -> void:
	var lamp := get_node_or_null(lamp_path)
	if lamp is Light3D:
		lamp.light_energy = 2.0

func _check() -> void:
	if _opened:
		return
	if absf(_last_a - _last_b) <= sync_window:
		_opened = true
		activated.emit()
