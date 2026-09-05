# Renders every demo and checks it actually draws something. Run with:
#
#     godot --path godot --rendering-driver opengl3 --script res://tests/render_checks.gd
#     godot --path godot --script res://tests/render_checks.gd -- --calibrate
#
# Needs a real rendering driver: --headless uses a dummy renderer that draws
# nothing, so these checks would pass on a completely broken project.
#
# ADDING A DEMO
# Drop a .tscn in Demos/ and it is picked up automatically - the same rule the
# demo browser uses. Nothing here holds a list. If a demo needs different
# limits, add a section to tests/demos.cfg instead of editing this file.
#
# WHY GOLDENS ARE CALIBRATED
# Animated demos are not reproducible frame to frame: shader TIME keeps running,
# and --fixed-fps does not pin it. Measured run-to-run difference on an
# unchanged build ranges from 0.000 (MatCap, static) to 0.155 (Water2D). A
# single global tolerance therefore either misses real regressions or fails
# constantly, so each demo carries its own measured noise floor.
#
# Run with --calibrate to measure it: every demo is rendered twice and the
# difference is written to tests/demos.cfg. Demos noisier than NOISE_CEILING are
# marked golden=false, because no threshold can separate signal from churn for
# them.
extends SceneTree

const DEMOS_DIR := "res://Demos"
const GOLDEN_DIR := "res://tests/golden"
const CONFIG_PATH := "res://tests/demos.cfg"
const OUTPUT_DIR := "user://render_checks"

# Demos are authored for this resolution; rendering smaller crops them.
const RESOLUTION := Vector2i(1920, 1080)
const WARMUP_FRAMES := 200
# Comparison size: coarse enough to shrug off driver differences, fine enough
# that a missing sky or an untextured object still moves the number.
const SAMPLE := Vector2i(160, 90)

# Defaults, overridable per demo in demos.cfg.
const DEFAULT_FLAT_THRESHOLD := 0.02
const DEFAULT_GOLDEN_TOLERANCE := 0.06
# Above this measured noise, a demo cannot be compared to a golden at all.
const NOISE_CEILING := 0.03
# How much of the noise floor to allow before calling a difference real.
const NOISE_SAFETY := 3.0

var _config := ConfigFile.new()
var _failures: Array[String] = []
var _checked := 0
var _calibrating := false


func _initialize() -> void:
	_calibrating = "--calibrate" in OS.get_cmdline_user_args()
	DisplayServer.window_set_size(RESOLUTION)
	root.size = RESOLUTION
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_config.load(CONFIG_PATH)

	var scenes := _demo_scenes()
	print("%s %d demos at %dx%d\n"
			% ["Calibrating" if _calibrating else "Rendering", scenes.size(),
			RESOLUTION.x, RESOLUTION.y])

	for path in scenes:
		if _calibrating:
			await _calibrate_demo(path)
		else:
			await _check_demo(path)

	if _calibrating:
		_config.save(CONFIG_PATH)
		print("\nWrote %s. Review it, then capture goldens." % CONFIG_PATH)
		quit(0)
		return

	for failure in _failures:
		print("  FAIL  %s" % failure)
	if _failures.is_empty():
		print("\nAll %d demos rendered (screenshots in %s)." % [_checked, OUTPUT_DIR])
		quit(0)
	else:
		print("\n%d of %d demos failed." % [_failures.size(), _checked])
		quit(1)


func _check_demo(path: String) -> void:
	var name := path.get_file().get_basename()
	if _config.get_value(name, "skip", false):
		print("  skip  %s" % name)
		return
	var image := await _render(path)
	if image == null:
		_failures.append("%s does not load" % name)
		return
	_checked += 1
	image.save_png(OUTPUT_DIR.path_join(name + ".png"))
	var sample := _downsample(image)

	var flat_limit: float = _config.get_value(name, "flat_threshold", DEFAULT_FLAT_THRESHOLD)
	var deviation := _luminance_deviation(sample)
	if deviation < flat_limit:
		_failures.append("%s renders a flat image (deviation %.4f < %.4f)"
				% [name, deviation, flat_limit])
		return

	var golden_path := GOLDEN_DIR.path_join(name + ".png")
	if not FileAccess.file_exists(golden_path):
		print("  ok    %-32s dev %.3f  (no golden)" % [name, deviation])
		return
	if not _config.get_value(name, "golden", true):
		print("  ok    %-32s dev %.3f  (golden disabled: too noisy)" % [name, deviation])
		return

	var golden := Image.new()
	if golden.load(golden_path) != OK:
		_failures.append("%s: golden image will not load" % name)
		return
	var tolerance: float = _config.get_value(name, "golden_tolerance", DEFAULT_GOLDEN_TOLERANCE)
	var difference := _mean_difference(sample, _downsample(golden))
	if difference > tolerance:
		_failures.append("%s differs from its golden by %.4f (limit %.4f)"
				% [name, difference, tolerance])
	else:
		print("  ok    %-32s dev %.3f  diff %.3f" % [name, deviation, difference])


# Render twice and record how much a demo differs from itself. That noise floor
# is what makes a golden comparison meaningful rather than a coin toss.
func _calibrate_demo(path: String) -> void:
	var name := path.get_file().get_basename()
	var first := await _render(path)
	var second := await _render(path)
	if first == null or second == null:
		print("  --    %-32s does not load" % name)
		return
	var noise := _mean_difference(_downsample(first), _downsample(second))
	var goldenable := noise <= NOISE_CEILING
	_config.set_value(name, "golden", goldenable)
	_config.set_value(name, "noise", snappedf(noise, 0.0001))
	if goldenable:
		var tolerance := maxf(DEFAULT_GOLDEN_TOLERANCE, noise * NOISE_SAFETY)
		_config.set_value(name, "golden_tolerance", snappedf(tolerance, 0.001))
	print("  %-32s noise %.4f  %s"
			% [name, noise, "goldenable" if goldenable else "ANIMATED - golden disabled"])


func _render(path: String) -> Image:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	root.add_child(instance)
	for i in WARMUP_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	instance.free()
	await process_frame
	return image


func _downsample(image: Image) -> Image:
	var copy := image.duplicate() as Image
	copy.resize(SAMPLE.x, SAMPLE.y, Image.INTERPOLATE_BILINEAR)
	return copy


func _luminance_deviation(image: Image) -> float:
	var values := PackedFloat32Array()
	var total := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var luminance := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			values.append(luminance)
			total += luminance
	var mean := total / values.size()
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	return sqrt(variance / values.size())


func _mean_difference(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
	return total / float(a.get_width() * a.get_height())


# Top level of Demos/ only, matching what the demo browser lists.
func _demo_scenes() -> Array:
	var scenes := []
	var dir := DirAccess.open(DEMOS_DIR)
	if dir == null:
		return scenes
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			scenes.append(DEMOS_DIR.path_join(file))
	scenes.sort()
	return scenes
