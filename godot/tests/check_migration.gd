# Reports property VALUES an engine upgrade dropped. Run with:
#
#     godot --headless --path godot --script res://tests/check_migration.gd
#     godot --headless --path godot --script res://tests/check_migration.gd -- --reference <rev>
#
# Needs `git` on PATH. Prints a report and always exits 0: this is a tool for an
# upgrade, not a gate. The permanent gates are in static_checks.gd.
#
# WHEN TO RUN IT
# After converting the project to a new Godot version, with the reference set to
# the last commit before the conversion. Godot's converter renames what it knows
# about and silently discards the rest, and the discarded values are invisible
# afterwards: nothing errors, the scene just behaves differently.
#
# This is how the Godot 3 to 4 port's damage was found - 273 dropped values
# across 114 blocks, including every shader parameter and every sky material.
#
# WHAT IT CANNOT SEE
# A value that stayed valid but changed meaning. Godot 3's background_mode 4 was
# CANVAS and is KEEP in Godot 4; the number survived, so nothing here flags it.
# Enum-valued properties still need reading by a person.
extends SceneTree

const DEFAULT_REFERENCE := "0eef82d^"

# Godot 3 class -> Godot 4 class.
const CLASS_RENAMES := {
	"Spatial": "Node3D", "SpatialMaterial": "StandardMaterial3D", "Sprite": "Sprite2D",
	"MeshInstance": "MeshInstance3D", "Camera": "Camera3D", "Particles": "GPUParticles3D",
	"Particles2D": "GPUParticles2D", "ParticlesMaterial": "ParticleProcessMaterial",
	"Light2D": "PointLight2D", "OmniLight": "OmniLight3D", "SpotLight": "SpotLight3D",
	"DirectionalLight": "DirectionalLight3D", "Position2D": "Marker2D",
	"Position3D": "Marker3D", "Viewport": "SubViewport", "Area": "Area3D",
	"ViewportContainer": "SubViewportContainer", "KinematicBody": "CharacterBody3D",
	"KinematicBody2D": "CharacterBody2D", "RigidBody": "RigidBody3D",
	"StaticBody": "StaticBody3D", "CollisionShape": "CollisionShape3D",
	"BoxShape": "BoxShape3D", "SphereShape": "SphereShape3D", "CubeMesh": "BoxMesh",
	"NoiseTexture": "NoiseTexture2D", "GradientTexture": "GradientTexture1D",
	"OpenSimplexNoise": "FastNoiseLite", "ProceduralSky": "Sky", "World": "World3D",
	"MultiMeshInstance": "MultiMeshInstance3D", "Skeleton": "Skeleton3D",
}

# Godot 3 property -> Godot 4 property, applied to the reference side.
const PROPERTY_RENAMES := {
	"translation": "position", "range_height": "height", "expand": "expand_mode",
	"align": "horizontal_alignment", "pressed": "button_pressed", "current": "enabled",
	"scroll_horizontal_enabled": "horizontal_scroll_mode", "msaa": "msaa_3d",
	"playback_process_mode": "callback_mode_process", "own_world": "own_world_3d",
	"world": "world_3d", "shadow_atlas_size": "positional_shadow_atlas_size",
	"extents": "size", "octaves": "fractal_octaves", "persistence": "fractal_gain",
	"lacunarity": "fractal_lacunarity", "period": "frequency",
	"as_normalmap": "as_normal_map", "flag_align_y": "particle_flag_align_y",
	"flag_disable_z": "particle_flag_disable_z", "emission_energy": "emission_energy_multiplier",
	"background_sky": "sky", "ss_reflections_enabled": "ssr_enabled",
	"ss_reflections_max_steps": "ssr_max_steps", "rect_min_size": "custom_minimum_size",
	"bbcode_text": "text", "percent_visible": "visible_ratio", "pause_mode": "process_mode",
	"hint_tooltip": "tooltip_text", "min_value": "_limits", "max_value": "_limits",
}
const PREFIX_RENAMES := [
	["shader_param/", "shader_parameter/"],
	["material/", "surface_material_override/"],
	["custom_fonts/", "theme_override_fonts/"],
	["custom_colors/", "theme_override_colors/"],
	["custom_styles/", "theme_override_styles/"],
	["custom_constants/", "theme_override_constants/"],
]
# Godot 3 stored one value plus a randomness factor; Godot 4 stores min/max.
const RANDOM_PAIRS := ["initial_velocity", "angular_velocity", "orbit_velocity",
		"linear_accel", "radial_accel", "tangential_accel", "damping", "angle", "scale"]
# Control margins became container-managed layout, which is a real conversion,
# not a loss. Reporting them buries everything else.
const IGNORED := ["margin_left", "margin_top", "margin_right", "margin_bottom",
		"anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "resource_name",
		"__meta__", "editor_description", "script"]

var _reference := DEFAULT_REFERENCE
var _repository := ""
var _class_properties := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--reference")
	if index != -1 and index + 1 < args.size():
		_reference = args[index + 1]
	_repository = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	_cache_class_properties()

	if _git(["rev-parse", _reference]).is_empty():
		print("Cannot resolve reference '%s' in %s" % [_reference, _repository])
		quit(0)
		return
	print("Comparing against %s\n" % _reference)

	var findings := 0
	var blocks := 0
	for path in _find_files("res://"):
		var relative := (path as String).replace("res://", "")
		var old_text := _git(["show", "%s:godot/%s" % [_reference, relative]])
		if old_text.is_empty():
			continue
		var report := _compare(old_text, FileAccess.get_file_as_string(path))
		if report.is_empty():
			continue
		print("%s" % relative)
		for line in report:
			print("    %s" % line)
			findings += 1
		blocks += report.size()
	print("\n%d dropped values across %d blocks." % [findings, blocks])
	print("Values that stayed valid but changed meaning are NOT listed; read enum")
	print("properties such as background_mode by hand.")
	quit(0)


func _compare(old_text: String, new_text: String) -> Array:
	var old_blocks := _parse(old_text)
	var new_blocks := _parse(new_text)
	var by_key := {}
	for block in new_blocks:
		by_key[block.key] = block

	var report := []
	for block in old_blocks:
		var target = null
		for key in _key_variants(block.key):
			if by_key.has(key):
				target = by_key[key]
				break
		if target == null:
			continue  # block absent entirely: re-authored or removed on purpose
		var missing := []
		for property in block.properties:
			if property in IGNORED or property.ends_with("_random"):
				continue
			var renamed := _rename(property)
			if renamed in RANDOM_PAIRS:
				renamed += "_max"
			if target.properties.has(renamed) or target.properties.has(property):
				continue
			# Only report if Godot still stores it; otherwise it was removed,
			# which is expected rather than a loss.
			if _stores(target.cls, renamed) == 1:
				missing.append(renamed)
		if not missing.is_empty():
			report.append("%s %s: %s" % [block.kind, block.key, ", ".join(missing)])
	return report


func _parse(text: String) -> Array:
	var blocks := []
	var current = null
	var in_multiline := false
	for raw in _lines(text):
		var line := raw as String
		if in_multiline:
			in_multiline = not line.ends_with('"')
			continue
		if line.begins_with("["):
			current = _block_header(line)
			if current != null:
				blocks.append(current)
			continue
		var separator := line.find(" = ")
		if current == null or separator == -1:
			continue
		var value := line.substr(separator + 3)
		# A lone quote opens a multi-line string; it must not be mistaken for a
		# complete one just because it also ends with a quote.
		if value.begins_with('"') and (value.length() == 1 or not value.ends_with('"')):
			in_multiline = true
			continue
		current.properties[line.substr(0, separator)] = value
	return blocks


func _block_header(line: String):
	var kind := ""
	if line.begins_with("[node"):
		kind = "node"
	elif line.begins_with("[sub_resource"):
		kind = "sub_resource"
	elif line.begins_with("[resource]"):
		return {"kind": "resource", "key": "resource", "cls": "", "properties": {}}
	else:
		return null
	var cls := _attribute(line, "type")
	cls = CLASS_RENAMES.get(cls, cls)
	var key := ""
	if kind == "node":
		key = _attribute(line, "parent") + "/" + _attribute(line, "name")
	else:
		key = _attribute(line, "id")
	return {"kind": kind, "key": key, "cls": cls, "properties": {}}


func _attribute(line: String, name: String) -> String:
	var marker := name + '="'
	var start := line.find(marker)
	if start == -1:
		# sub_resource ids were unquoted in Godot 3: id=12
		marker = name + "="
		start = line.find(marker)
		if start == -1:
			return ""
		start += marker.length()
		var stop := start
		while stop < line.length() and line[stop] != "]" and line[stop] != " ":
			stop += 1
		return line.substr(start, stop - start)
	start += marker.length()
	return line.substr(start, line.find('"', start) - start)


# Node paths the port renamed: Viewport became SubViewport, and Godot 4.4's
# importer writes Cube_001 where earlier versions wrote Cube001.
func _key_variants(key: String) -> Array:
	var variants := [key]
	var swapped := key.replace("/Viewport/", "/SubViewport/")
	if swapped.ends_with("/Viewport"):
		swapped = swapped.substr(0, swapped.length() - 9) + "/SubViewport"
	if swapped != key:
		variants.append(swapped)
	for variant in variants.duplicate():
		var regex := RegEx.create_from_string("([A-Za-z_])(\\d{3})$")
		var suffixed := regex.sub(variant, "$1_$2")
		if suffixed != variant:
			variants.append(suffixed)
	return variants


func _rename(property: String) -> String:
	for pair in PREFIX_RENAMES:
		if property.begins_with(pair[0]):
			return pair[1] + property.substr(pair[0].length())
	return PROPERTY_RENAMES.get(property, property)


# 1 = Godot stores it, 0 = it does not, -1 = class unknown so cannot judge.
func _stores(cls: String, property: String) -> int:
	if cls.is_empty() or not _class_properties.has(cls):
		return -1
	var known: Dictionary = _class_properties[cls]
	if known.has(property):
		return 1
	var slash := property.find("/")
	if slash != -1:
		var prefix := property.substr(0, slash + 1)
		for name in known:
			if (name as String).begins_with(prefix):
				return 1
	return 0


func _cache_class_properties() -> void:
	for cls in ClassDB.get_class_list():
		var names := {}
		for property in ClassDB.class_get_property_list(cls, false):
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				names[property.name] = true
		_class_properties[cls] = names


func _git(arguments: Array) -> String:
	var output := []
	var command := ["-C", _repository]
	command.append_array(arguments)
	if OS.execute("git", command, output, true) != 0:
		return ""
	return "\n".join(output)


func _find_files(path: String) -> Array:
	var found := []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".tscn") or file.ends_with(".tres"):
			found.append(path.path_join(file))
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		found.append_array(_find_files(path.path_join(sub)))
	return found

# Scene files are checked out with CRLF on Windows. Splitting on a bare newline
# leaves a trailing carriage return, which makes every quoted value look like an
# unterminated multi-line string and silently swallows the lines after it.
func _lines(text: String) -> PackedStringArray:
	return text.replace("\r\n", "\n").split("\n")
