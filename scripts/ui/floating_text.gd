extends Label
## One-shot floating feedback text: rises, scales up slightly,
## fades, frees itself after ~1 second. Spawn via HUD.notify(). The spawner
## sets `position` to the anchor point; this script re-centers on it.

func setup(message: String, color: Color) -> void:
	text = message
	modulate = color

func _ready() -> void:
	# Wait one frame so the label has its final size, then center on the
	# anchor point and put the pivot in the middle so scaling grows outward.
	await get_tree().process_frame
	position.x -= size.x / 2.0
	pivot_offset = size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 64.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 1.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.55)
	tween.chain().tween_callback(queue_free)
