# Godot Shaders — maintained fork

> A fork of [gdquest-demos/godot-shaders](https://github.com/gdquest-demos/godot-shaders),
> maintained by **Señor Mega** and **Claude**, who knows nothing about Godot.

**Status:** runs on **Godot 4.7**. All 39 demos load and render.

Upstream stopped part-way through its Godot 3 → 4 port, and the demos have not
worked since. This fork finishes the port.

Most of the damage was never visible as an error. The conversion made the
structural changes correctly and then discarded data in silence: every
`shader_param` in the project, 44 sprite textures, every bezier animation key,
and the contents of every sky material. Nothing logs a warning when a shader
runs on default values or a sky renders as Godot's built-in grey — it simply
looks wrong, and only if you know what it used to look like.

Restored values were recovered from the last pre-port revision rather than
invented, so the demos match their original design instead of a plausible guess.

## Running the tests

Both scripts exit non-zero on failure and need nothing beyond Godot:

```bash
# static checks: no GPU required
godot --headless --path godot --script res://tests/static_checks.gd

# render checks: needs a real driver, --headless draws nothing
godot --path godot --rendering-driver opengl3 --script res://tests/render_checks.gd
```

`static_checks.gd` verifies that every scene, resource and shader loads, that
every referenced path exists, and that **every property name is one Godot still
knows**. That last check is what catches an engine upgrade: a renamed property
does not error, it is dropped silently and the feature it controlled stops
working.

`render_checks.gd` renders every demo and fails if the frame is flat — a black
or blank screen — or if it drifts from an approved golden image.

Both run in CI on every pull request. See [`godot/tests/`](godot/tests/README.md)
for details and for how to add golden images.

## How this fork is maintained

The port was done with AI assistance (Claude Code). The first attempt passed
"39 demos render, zero errors" while every 3D demo was quietly drawing the wrong
sky — which is exactly why the checks above exist and why golden images only
count once a human has looked at them.

Treat the tests as the guard rail, not as proof. They catch regressions against
a reference; they cannot tell you a shader still teaches what it is meant to
teach.

---

*Everything below is the original GDQuest README.*

# Godot Shaders

![project banner](./img/banner-shader-secrets.png)

Godot Shaders is a repository of Free shaders, part of which we made for our course [Godot Shader Secrets](https://gdquest.mavenseed.com/courses/godot-shader-secrets).

➡ Follow us on [Twitter](https://twitter.com/NathanGDQuest) and [YouTube](https://www.youtube.com/c/gdquest/) for free game creation tutorials, tips, and news! Get one of our [Godot game creation courses](https://gdquest.mavenseed.com/) to support our work on Free Software.

![2D dissolve shader, showing a character burning](./img/robi-in-flames.png)

## The shaders

Here's a list of available shaders and demos.

### 3D Shaders

![Stylized fire shader](img/stylized-fire.png)

- 3D dissolve
- 3D outline
- 3D shockwave
- 3D stylized fire
- Advanced toon shader
- Force field
- Stencil mask (impossible cube)
- Stylized fire
- Stylized bottled liquid
- Interactive snow
- Unlit directional tint
- Texture mixing methods
- Stylized waterfall shader
- Spherical mask shader
- Particle bridge: process to canvas_item/spatial communication

### 2D Shaders

![2D water shader with light support](./img/water2d.png)

- 2D baked-in-texture glow control
- 2D clouds: noise-based cloud shadows cast over the game world
- 2D dissolve
- 2D glow
- 2D outline
- 2D palette swap
- 2D reflection
- 2D water for side-scrolling games
- 2D water in top-down view
- 2D x-ray (masking)

### Screen shaders

- Gaussian blur
- Inverted colors
- Pointilism
- Screen distortion (2D shockwave)

## How to use

You can find the shaders in the `Shaders/` directory. Most shaders come with a demo scene. All demos are in the `Demos/` directory.

The `Intro/` directory contains an intro animation to the shader pipeline, that we use in our shader course.

## Contributing

Contributors are welcome!

If you encounter a bug, please [open an issue](https://github.com/GDQuest/godot-game-harvester/issues/new).

If you want to contribute to the project, for instance by fixing a bug or adding a feature, check out our:

1. [Contributor guidelines](https://www.gdquest.com/docs/guidelines/contributing-to/gdquest-projects/).
1. [GDScript style guide](https://www.gdquest.com/docs/guidelines/best-practices/godot-gdscript/)

## Credits

Stylized fire adapted from a Unity tutorial by [@minionsart](https://twitter.com/minionsart/).
