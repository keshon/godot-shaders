# Tests

No dependencies beyond Godot itself, plus `git` for the migration tool. Every
script exits non-zero on failure.

```bash
tests/run_tests.sh                    # what CI runs
tests/run_tests.sh --render           # also render every demo
GODOT=/path/to/godot tests/run_tests.sh
```

Or directly:

```bash
godot --headless --path godot --script res://tests/static_checks.gd
godot --path godot --rendering-driver opengl3 --script res://tests/render_checks.gd
godot --headless --path godot --script res://tests/check_migration.gd
```

## Adding a demo

Drop a `.tscn` into `Demos/` and it is covered. Nothing holds a list: the static
checks walk `res://`, and the render checks scan the top level of `Demos/`, the
same rule the demo browser uses. If a demo needs different limits, add a section
to `demos.cfg` rather than editing a script.

## `static_checks.gd` — the backbone

Runs anywhere, deterministic, no GPU.

| Check | Catches |
| --- | --- |
| every `.tscn` / `.tres` / `.gdshader` loads | unparseable files, broken references |
| every `res://` path resolves | files moved without updating references |
| every property name exists in `ClassDB` | **properties an upgrade silently dropped** |
| every `ShaderMaterial` sets some uniform | **wiped materials** |
| no `Sky` without a material, no `Sprite2D` without a texture | **emptied resources** |

The last three are the ones that matter, because none of what they catch is an
error at load time. A renamed property is discarded in silence. A shader whose
parameters were wiped still runs, on defaults. An empty sky renders Godot's own
gradient. The project looked healthy in all three states.

Two details keep this honest rather than noisy:

- Only properties with `PROPERTY_USAGE_STORAGE` count. `ClassDB` also returns
  group headers, and they collide with real names — `ParticleProcessMaterial`
  has a `scale` *group* but stores `scale_min` / `scale_max`. Without the filter
  the check passes on values that are being discarded.
- Scene files are CRLF on Windows. Splitting on a bare newline leaves a carriage
  return that makes every quoted value look like an unterminated multi-line
  string, silently skipping the rest of the block. That bug hid 77 real findings
  until it was fixed; see `_lines()`.

## `render_checks.gd`

Renders every demo at 1920×1080 — the resolution they are authored for, smaller
crops rather than scales — and checks the frame is not a flat colour. That
catches black screens and demos whose geometry or materials failed to load.

It will also compare against a golden image if one exists in `golden/`.

### On goldens, and why they are not a gate

Golden images are standard practice elsewhere (Playwright, Percy, Paparazzi,
Chromium's and Skia's test suites) and they are also the flakiest category of
test most teams own. Here the numbers are measured, not assumed:

- 35 of 39 demos are reproducible run to run (noise ≤ 0.03, many exactly 0.000).
- 4 are not: Water2D 0.155, InteractiveSnow 0.059, WindTrees 0.055,
  WindGrass 0.035.

Those four contain no particles and no randomness. They are continuously
animating shaders, and shader `TIME` advances with wall-clock time, so a capture
after a fixed number of frames lands on a different moment each run. `--fixed-fps`
does not pin it. Nothing is missing from the demos; sampling a moving image is
simply not reproducible.

So the tolerance is not papering over a fixable defect, and it is not applied
globally either. `--calibrate` renders every demo twice, records its own noise in
`demos.cfg`, and marks anything above the ceiling `golden=false`:

```bash
godot --path godot --script res://tests/render_checks.gd -- --calibrate
```

Goldens do not run in CI. Software rendering does not produce the same pixels as
a GPU, so goldens captured on a workstation would fail for reasons unrelated to
the change under test. Treat them as a local tool, and note their value is lower
now than it looks: the regression they were meant to catch — the emptied sky —
is caught deterministically by `static_checks.gd`.

### Capturing goldens

Run the render checks, **look at every screenshot in `user://render_checks/`**,
then copy the correct ones into `golden/`. A golden nobody has inspected is
worse than none: it locks in whatever was broken and reports green forever.

That is not hypothetical. This project was once declared working on "39 demos
render, zero errors" while every 3D demo drew Godot's default grey sky.

## `check_migration.gd` — for engine upgrades

Compares every block against a reference revision and reports values the
converter dropped. Needs `git`. Prints a report and always exits 0: it is a tool
for an upgrade, not a gate.

```bash
godot --headless --path godot --script res://tests/check_migration.gd -- --reference <rev>
```

This is what found the Godot 3 → 4 damage: 273 dropped values across 114 blocks,
including every shader parameter and every sky material. Run it after converting
the project to a new Godot version, with the reference set to the commit before
the conversion.

It cannot see a value that stayed valid but changed meaning. Godot 3's
`background_mode` 4 was `CANVAS` and is `KEEP` in Godot 4 — the number survived,
so nothing flags it. Enum properties still need reading by a person.

## What none of this checks

These detect regressions against a reference. They cannot tell you a shader
demonstrates the technique it is meant to teach, or that the result looks right.
That still needs someone who knows what the demo is for.
