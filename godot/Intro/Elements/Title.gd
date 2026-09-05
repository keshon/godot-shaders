extends Label


func change_title(title: String) -> void:
	# Godot 4 tweens run their steps in sequence, so the fade out, the text swap
	# and the fade in can be one tween instead of two plus a wait.
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.15).from(Color.WHITE)
	tween.tween_callback(func() -> void: text = title)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	await tween.finished
