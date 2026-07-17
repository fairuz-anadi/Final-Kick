extends Label
## One-shot floating feedback text: pops in, rises, fades, frees itself.
## Spawn via HUD.notify(). The spawner sets `position` to the anchor point;
## this script re-centers on it. Bigger font sizes (chain callouts, FINAL
## KICK) get a harder elastic pop so the important moments hit harder.

var _big := false

func setup(message: String, color: Color, font_size: int = 24) -> void:
	text = message
	modulate = color
	add_theme_font_size_override("font_size", font_size)
	_big = font_size >= 30

func _ready() -> void:
	# Wait one frame so the label has its final size, then center on the
	# anchor point and put the pivot in the middle so scaling grows outward.
	await get_tree().process_frame
	position.x -= size.x / 2.0
	pivot_offset = size / 2.0
	if _big:
		# Elastic slam-in from oversized, then rise and fade — arcade juice.
		scale = Vector2(1.9, 1.9)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "position:y", position.y - 72.0, 1.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.8)
		tween.chain().tween_callback(queue_free)
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 64.0, 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.18, 1.18), 1.0)
		tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.55)
		tween.chain().tween_callback(queue_free)
