extends Node2D

const Y_OFFSET = 27

@export var Vertex: PackedScene
@export var theme: Theme
@export var v_code: PackedScene

var data := [
	"-1   1   1",
	" 1   1  -1",
	" 1   1   1",
	"-1   1  -1",
	"-1  -1   1",
	" 1  -1  -1",
	" 1  -1   1",
	"-1  -1  -1",
	" 1   1   1",
	"-1   1  -1",
	" 1   1  -1",
	"-1   1   1",
	" 1  -1   1",
	"-1  -1  -1",
	" 1  -1  -1",
	"-1  -1   1",
	" 1   1   1",
	"-1  -1   1",
	"-1   1   1",
	" 1  -1   1",
	" 1   1  -1",
	"-1  -1  -1",
	"-1   1  -1",
	" 1  -1  -1"
]

var labels := []
var vertices := []
var vertex_start_positions := []
var vertex_end_positions := []
var culled_indices := []
var indices := []


func setup(cube: MeshInstance3D, camera: Camera3D) -> void:
	var x := 50.0
	var y := 60.0

	_extract_end_positions(cube, camera)

	for label_text in data:
		var vertex := Vertex.instantiate()
		add_child(vertex)

		vertex.position = Vector2(x, y)
		vertices.append(vertex)
		vertex_start_positions.append(vertex.position)

		var label := Label.new()
		label.text = label_text
		add_child(label)
		label.position = Vector2(x + 30, y - 18)
		label.theme = theme
		label.modulate = Color.WHITE
		labels.append(label)

		y += Y_OFFSET


func animate() -> void:
	await animate_vertices()
	remove_labels()


func remove_labels() -> void:
	var tween := create_tween().set_parallel(true)
	for l in labels:
		tween.tween_property(l, "modulate", Color.TRANSPARENT, 1.0).from(Color.WHITE)
	await tween.finished
	for l in labels:
		l.queue_free()


func animate_vertices() -> void:
	var anim_time := 0.5
	for i in range(0, indices.size(), 3):
		var tween := create_tween().set_parallel(true)
		# Godot 4's Array.slice() end is exclusive; Godot 3's was inclusive, so
		# this still covers the three indices of one triangle.
		for indice in indices.slice(i, i + 3):
			(tween.tween_property(
					vertices[indice],
					"position",
					vertex_end_positions[indice],
					anim_time)
					.set_trans(Tween.TRANS_SINE)
					.set_ease(Tween.EASE_IN_OUT))
		await tween.finished
		await get_tree().create_timer(anim_time).timeout
		if i == 6:
			anim_time = 0.3
		if i == 21:
			anim_time = 0.15


func do_cull() -> void:
	var tween := create_tween().set_parallel(true)
	for indice in culled_indices:
		tween.tween_property(vertices[indice], "modulate", Color.RED, 1.0).from(Color.WHITE)
		(tween.tween_property(vertices[indice], "modulate", Color.TRANSPARENT, 1.0)
				.from(Color.RED)
				.set_delay(1.0))
	await tween.finished


func _extract_end_positions(mesh_instance: MeshInstance3D, camera: Camera3D) -> void:
	var mesh := mesh_instance.mesh

	var pixel_data: Array = mesh.surface_get_arrays(0)
	var mesh_vertices: Array = pixel_data[ArrayMesh.ARRAY_VERTEX]
	var normals: Array = pixel_data[ArrayMesh.ARRAY_NORMAL]
	var _indices: Array = pixel_data[ArrayMesh.ARRAY_INDEX]
	indices = _indices
	var camera_normal := -camera.global_transform.basis.z
	vertex_end_positions.resize(mesh_vertices.size())

	var xform := mesh_instance.global_transform

	for indice in _indices:
		var v: Vector3 = mesh_vertices[indice]

		var vertex: Vector3 = xform * (v)
		var normal: Vector3 = xform.basis * (normals[indice])

		if normal.dot(camera_normal) > 0:
			culled_indices.append(indice)

		var end_point := camera.unproject_position(vertex)  # / 0.078

		vertex_end_positions[indice] = end_point
