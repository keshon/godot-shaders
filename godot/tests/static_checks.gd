# Static checks that need no GPU. Run with:
#
#     godot --headless --path godot --script res://tests/static_checks.gd
#
# Exits non-zero if any check fails, so it can gate a pull request.
#
# These target the way an engine upgrade actually breaks a project: not with
# errors, but by discarding data in silence. A renamed property, a wiped shader
# parameter and an emptied sky material all load without complaint.
extends SceneTree

# Property names that are legitimately absent from ClassDB.
const IGNORED_PROPERTIES := ["script", "__meta__", "editor_description", "libraries"]

# Namespaces a resource fills in at runtime, so ClassDB never lists them:
# shader uniforms, theme overrides, animation tracks and so on.
const DYNAMIC_PREFIXES := [
	"shader_parameter/",
	"theme_override_colors/",
	"theme_override_constants/",
	"theme_override_fonts/",
	"theme_override_font_sizes/",
	"theme_override_icons/",
	"theme_override_styles/",
	"surface_material_override/",
	"blend_shapes/",
	"libraries/",
	"anims/",
	"tracks/",
	"bones/",
	"metadata/",
	"input_",
]

# Nodes that are pointless without a texture, so a null one means it was lost.
const NEEDS_TEXTURE := ["Sprite2D", "Sprite3D"]

var _failures: Array[String] = []
var _warnings: Array[String] = []
var _class_properties := {}
var _skipped_scripted := 0


func _initialize() -> void:
	_cache_class_properties()

	var files := _find_files("res://", [".tscn", ".tres", ".gdshader"])
	print("Scanning %d files\n" % files.size())

	_check_resources_load(files)
	_check_referenced_paths(files)
	_check_property_names(files)
	_check_shader_parameters(files)
	_check_empty_essentials(files)

	print("")
	for warning in _warnings:
		print("  warn  %s" % warning)
	for failure in _failures:
		print("  FAIL  %s" % failure)

	if _failures.is_empty():
		print("\nAll static checks passed (%d warnings)." % _warnings.size())
		quit(0)
	else:
		print("\n%d failures, %d warnings." % [_failures.size(), _warnings.size()])
		quit(1)


# Every scene, resource and shader must load. A null return means the file is
# unparseable or points at something missing.
func _check_resources_load(files: Array) -> void:
	var failed := 0
	for path in files:
		if ResourceLoader.load(path) == null:
			_failures.append("does not load: %s" % path)
			failed += 1
	print("load               %d files, %d failed" % [files.size(), failed])


# Catches references the engine's upgrade tools drop or rewrite incorrectly.
func _check_referenced_paths(files: Array) -> void:
	var missing := 0
	var regex := RegEx.create_from_string('path="(res://[^"]+)"')
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for m in regex.search_all(text):
			var target := m.get_string(1)
			if not ResourceLoader.exists(target) and not FileAccess.file_exists(target):
				_failures.append("%s references missing %s" % [path, target])
				missing += 1
	print("references         %d missing" % missing)


# A property Godot no longer knows is not an error at load time: it is dropped
# in silence and the value it carried is lost. This is how Godot 3 leftovers
# such as `range_height` or `expand` survive an upgrade while doing nothing.
func _check_property_names(files: Array) -> void:
	var unknown := 0
	for path in files:
		if not path.ends_with(".tscn") and not path.ends_with(".tres"):
			continue
		var current_class := ""
		var has_script := false
		var in_multiline := false
		for raw_line in _lines(FileAccess.get_file_as_string(path)):
			var line := raw_line as String
			if in_multiline:
				in_multiline = not line.ends_with('"')
				continue
			if line.begins_with("["):
				current_class = _class_of(line)
				has_script = false
				continue
			var separator := line.find(" = ")
			if current_class.is_empty() or separator == -1:
				continue
			var property := line.substr(0, separator)
			var value := line.substr(separator + 3)
			# Shader code and other long strings span lines; skip their bodies.
			# A lone quote opens such a string, so it must not be mistaken for a
			# complete one just because it also ends with a quote.
			if value.begins_with('"') and (value.length() == 1 or not value.ends_with('"')):
				in_multiline = true
				continue
			if property == "script":
				has_script = true
				continue
			if property in IGNORED_PROPERTIES or property.begins_with("__"):
				continue
			if _is_dynamic(property) or _is_known_property(current_class, property):
				continue
			# Scripts add exported properties ClassDB cannot see. Reporting them
			# would bury the real findings, so they are counted, not listed.
			if has_script:
				_skipped_scripted += 1
			else:
				_failures.append("%s: %s.%s is not a Godot property"
						% [path.replace("res://", ""), current_class, property])
				unknown += 1
	print("properties         %d unknown (%d on scripted nodes, not checked)"
			% [unknown, _skipped_scripted])


# A ShaderMaterial whose shader declares uniforms but which sets none of them is
# the signature of a wiped material: the shader still runs, on default values,
# and nothing is logged. Before these were restored, 86 materials looked like
# this. Materials that set some uniforms and leave others at their declared
# defaults are normal and not reported.
func _check_shader_parameters(files: Array) -> void:
	var checked := 0
	var wiped := 0
	for path in files:
		var resource := ResourceLoader.load(path)
		if resource == null:
			continue
		for material in _collect_materials(resource):
			if material.shader == null:
				_warnings.append("%s: ShaderMaterial has no shader assigned"
						% path.replace("res://", ""))
				continue
			var uniforms: Array = material.shader.get_shader_uniform_list()
			if uniforms.is_empty():
				continue
			checked += 1
			var unset := 0
			for uniform in uniforms:
				if material.get_shader_parameter(uniform.name) == null:
					unset += 1
			if unset == uniforms.size():
				_failures.append("%s: material sets none of the %d uniforms in %s"
						% [path.replace("res://", ""), uniforms.size(),
						material.shader.resource_path.get_file()])
				wiped += 1
	print("shader parameters  %d materials, %d with nothing set" % [checked, wiped])


# Resources that exist but whose essential field is empty. An upgrade that drops
# data leaves exactly this shape behind, and none of it raises an error: an
# empty Sky renders Godot's default gradient, a Sprite2D with no texture draws
# nothing at all.
func _check_empty_essentials(files: Array) -> void:
	var empty := 0
	for path in files:
		var resource := ResourceLoader.load(path)
		if resource == null:
			continue
		for sky in _collect_of_type(resource, "Sky"):
			if sky.sky_material == null:
				_failures.append("%s: Sky has no sky_material" % path.replace("res://", ""))
				empty += 1
		if not (resource is PackedScene):
			continue
		var state := (resource as PackedScene).get_state()
		for i in state.get_node_count():
			if not (state.get_node_type(i) in NEEDS_TEXTURE):
				continue
			var texture = _node_property(state, i, "texture")
			if texture == null:
				_failures.append("%s: %s (%s) has no texture"
						% [path.replace("res://", ""), state.get_node_name(i),
						state.get_node_type(i)])
				empty += 1
	print("empty essentials   %d found" % empty)


func _node_property(state: SceneState, node: int, name: String) -> Variant:
	for j in state.get_node_property_count(node):
		if state.get_node_property_name(node, j) == name:
			return state.get_node_property_value(node, j)
	return null


func _collect_materials(resource: Resource) -> Array:
	var found := []
	for value in _all_values(resource):
		if value is ShaderMaterial:
			found.append(value)
	return found


func _collect_of_type(resource: Resource, cls: String) -> Array:
	var found := []
	for value in _all_values(resource):
		if is_instance_valid(value) and (value as Object).get_class() == cls:
			found.append(value)
	return found


# Every resource reachable from a file: the resource itself, anything it
# references, and every property stored on a packed scene's nodes.
func _all_values(resource: Resource) -> Array:
	var values := [resource]
	if resource is PackedScene:
		var state := (resource as PackedScene).get_state()
		for i in state.get_node_count():
			for j in state.get_node_property_count(i):
				values.append(state.get_node_property_value(i, j))
	else:
		for property in resource.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				values.append(resource.get(property.name))
	for value in values.duplicate():
		if value is Environment:
			values.append((value as Environment).sky)
		elif value is Material and value.next_pass != null:
			values.append(value.next_pass)
	# The same resource is reachable by more than one route, so report it once.
	var seen := {}
	var unique := []
	for value in values:
		if not (value is Object) or not is_instance_valid(value):
			continue
		var id := (value as Object).get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		unique.append(value)
	return unique


func _is_dynamic(property: String) -> bool:
	for prefix in DYNAMIC_PREFIXES:
		if property.begins_with(prefix):
			return true
	# Theme resources store entries as <Type>/<kind>/<name>.
	return property.count("/") >= 2


func _is_known_property(cls: String, property: String) -> bool:
	if not _class_properties.has(cls):
		return true  # instanced scene or custom class: cannot judge
	var known: Dictionary = _class_properties[cls]
	if known.has(property):
		return true
	# Indexed properties such as surface_material_override/0 are not listed
	# literally, so accept anything sharing a known prefix.
	var slash := property.find("/")
	if slash != -1:
		var prefix := property.substr(0, slash + 1)
		for name in known:
			if (name as String).begins_with(prefix):
				return true
	return false


# Only properties Godot serialises. Group and category headers share names with
# real properties (ParticleProcessMaterial has a "scale" group but stores
# scale_min/scale_max), so filtering on usage is what makes this check honest.
func _cache_class_properties() -> void:
	for cls in ClassDB.get_class_list():
		var names := {}
		for property in ClassDB.class_get_property_list(cls, false):
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				names[property.name] = true
		_class_properties[cls] = names


func _class_of(header: String) -> String:
	if not (header.begins_with("[node") or header.begins_with("[sub_resource")):
		return ""
	var marker := 'type="'
	var start := header.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	return header.substr(start, header.find('"', start) - start)


func _find_files(path: String, extensions: Array) -> Array:
	var found := []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	for file in dir.get_files():
		for extension in extensions:
			if file.ends_with(extension):
				found.append(path.path_join(file))
				break
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		found.append_array(_find_files(path.path_join(sub), extensions))
	return found

# Scene files are checked out with CRLF on Windows. Splitting on a bare newline
# leaves a trailing carriage return, which makes every quoted value look like an
# unterminated multi-line string and silently swallows the lines after it.
func _lines(text: String) -> PackedStringArray:
	return text.replace("\r\n", "\n").split("\n")
