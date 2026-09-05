extends Node2D

# Emitted once the cull animation has finished, so the parent can wait for a
# batch of drawers without owning their tweens.
signal culled

var vertex_positions := []

var length := 0.0
var color_mod := 1.0
var culled_color: Color
var cull: bool
var will_cull: bool


func setup(_vertex_positions: Array, _will_cull: bool) -> void:
	vertex_positions = _vertex_positions
	will_cull = _will_cull


func do_draw(anim_time: float) -> void:
	var tween := create_tween()
	tween.tween_method(_do_draw_update, 0.0, 1.0, anim_time).set_delay(anim_time)
	await tween.finished


func do_cull() -> void:
	cull = true
	# Sequential by default in Godot 4: the colour shift runs, then the fade.
	var tween := create_tween()
	tween.tween_method(_do_cull_color_update, Color.SKY_BLUE, Color.RED, 1.0)
	tween.tween_method(_do_cull_update, 1.0, 0.0, 1.0)
	await tween.finished
	culled.emit()


func _do_draw_update(value: float) -> void:
	length = value
	queue_redraw()


func _do_cull_color_update(value: Color) -> void:
	culled_color = value
	queue_redraw()


func _do_cull_update(value: float) -> void:
	color_mod = value
	queue_redraw()


func _draw() -> void:
	var v1: Vector2 = vertex_positions[0]
	var v2: Vector2 = vertex_positions[1]
	var v3: Vector2 = vertex_positions[2]

	var color_mod_actual := 1.0
	var color := Color.SKY_BLUE

	if cull and will_cull:
		color = culled_color
		color_mod_actual = color_mod

	color *= color_mod_actual

	var lerped_v1_to_v2 = (v1).lerp(v2, length)
	var lerped_v2_to_v3 = (v2).lerp(v3, length)
	var lerped_v3_to_v1 = (v3).lerp(v1, length)

	draw_line(v1, lerped_v1_to_v2, color, 1.25)
	draw_line(v2, lerped_v2_to_v3, color, 1.25)
	draw_line(v3, lerped_v3_to_v1, color, 1.25)

	if length != 0 and length < 1.0:
		draw_circle(lerped_v1_to_v2, 5, color * 1.2)
		draw_circle(lerped_v2_to_v3, 5, color * 1.2)
		draw_circle(lerped_v3_to_v1, 5, color * 1.2)
