extends Node3D

@onready var _blended_cube: MeshInstance3D = $BlendedCube
@onready var _clipped_cube: MeshInstance3D = $ClippedCube
@onready var _main_cube: MeshInstance3D = $MainCube
@onready var _camera: Camera3D = $Camera3D

@onready var clipped_start_color: Color = _clipped_cube.get_surface_override_material(0).albedo_color
@onready var blended_start_color: Color = _blended_cube.get_surface_override_material(0).albedo_color
@onready var main_start_color: Color = _main_cube.get_surface_override_material(0).albedo_color


func setup() -> void:
	_blended_cube.get_surface_override_material(0).albedo_color = Color.TRANSPARENT
	_clipped_cube.get_surface_override_material(0).albedo_color = Color.TRANSPARENT
	_main_cube.get_surface_override_material(0).albedo_color = Color.TRANSPARENT


func show_clipped_cube() -> void:
	_fade_in(_clipped_cube, clipped_start_color)


func show_blended_cube() -> void:
	_fade_in(_blended_cube, blended_start_color)


func show_main_cube() -> void:
	var material := _main_cube.get_surface_override_material(0)
	await _fade_in(_main_cube, main_start_color).finished
	# Godot 4 replaced the flags_transparent boolean with a transparency mode.
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED


func _fade_in(cube: MeshInstance3D, target: Color) -> Tween:
	var material := cube.get_surface_override_material(0)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", target, 1.0).from(Color.TRANSPARENT)
	return tween
