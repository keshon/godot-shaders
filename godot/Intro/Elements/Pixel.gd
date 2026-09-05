@tool
extends Node2D

var size := Vector2.ONE
var color := Color.WHITE


func _draw() -> void:
	draw_rect(Rect2(-size / 2, size), color, true)


func do_scale_down(delay: float) -> void:
	var tween := create_tween()
	(tween.tween_method(_do_scale_down_update, size, Vector2(size.x, 0.0), 0.15)
			.set_ease(Tween.EASE_IN_OUT)
			.set_delay(delay))
	await tween.finished
	queue_free()


func _do_scale_down_update(value: Vector2) -> void:
	size = value
	queue_redraw()
