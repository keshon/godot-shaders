# Godot Shaders

> A fork of [gdquest-demos/godot-shaders](https://github.com/gdquest-demos/godot-shaders),
> maintained by **Señor Mega** and **Claude**, who knows nothing about Godot.

Upstream stalled part-way through its Godot 3 to 4 port and the demos stopped
working. This fork finishes it. All 39 demos and the intro presentation run.

The original project README is kept verbatim as
[README.LEGACY.md](README.LEGACY.md), including its links to GDQuest's courses
and channels.

## Requirements

Godot **4.4 or newer**. Imported mesh node names follow the 4.4 importer, which
writes `Cube_001` where earlier versions wrote `Cube001`. Developed against
4.7.1.

## Running the demos

Open the `godot/` directory as a project. The main scene,
`Main/DemoSelector.tscn`, is a browser that lists every demo and loads it in
place.

Each demo is also a standalone scene under `Demos/`, so any one of them can be
opened and run directly. Shaders live in `Shaders/`; a few demos keep their
shader next to the scene that uses it. `Intro/ShaderPipelineIntro.tscn` is a
separate presentation about the shader pipeline.

Checks that the demos still load and draw live in
[`godot/tests/`](godot/tests/README.md).

## The shaders

### 3D shaders

| | Demo | What it shows |
| --- | --- | --- |
| <img src="img/demos/CrystalsDemo.png" width="220"> | **Crystals**<br>`CrystalsDemo.tscn` | A SpatialMaterial converted to a shader, adding a TIME-based pulse to its emission and fresnel. |
| <img src="img/demos/Dissolve3DDemo.png" width="220"> | **3D dissolve**<br>`Dissolve3DDemo.tscn` | A noise mask dissolves a 3D object by reducing the mesh's alpha channel according to the shape of the noise texture. |
| <img src="img/demos/Flag3DDemo.png" width="220"> | **Waving flag**<br>`Flag3DDemo.tscn` | The shader samples and scrolls OpenSimplexNoise to displace the mesh's vertices, giving the impression of a flag blowing in the wind. |
| <img src="img/demos/ForceFieldDemo.png" width="220"> | **Force field**<br>`ForceFieldDemo.tscn` | A fresnel effect forms the smooth glow, and the depth buffer finds where the field intersects existing world geometry. |
| <img src="img/demos/ImpossibleCubeDemo.png" width="220"> | **Impossible cube (stencil mask)**<br>`ImpossibleCubeDemo.tscn` | A viewport simulates stencil tests, making objects disappear depending on which colour faces the camera in the stencil view. The stencil supports up to 7 colours of masks. |
| <img src="img/demos/InteractiveSnowDemo.png" width="220"> | **Interactive snow**<br>`InteractiveSnowDemo.tscn` | A trail is painted into a secondary viewport. A shader reads it to decide where to displace the snow and blend it into the dirt underneath. |
| <img src="img/demos/MatCapDemo.png" width="220"> | **MatCap**<br>`MatCapDemo.tscn` | This shader applies a material capture texture. It maps a sphere texture using the model's normals instead of UVs. So any normals that point to the right sample from the texture's right. |
| <img src="img/demos/Outline3DDemo.png" width="220"> | **3D outline**<br>`Outline3DDemo.tscn` | Outlines 3D objects with precise control. The meshes are drawn a second time, larger, with inverted culling so the copy sits behind the object. Two methods are shown; each has different limitations. |
| <img src="img/demos/ParticleBridgeDemo.png" width="220"> | **Particle bridge**<br>`ParticleBridgeDemo.tscn` | Particles can be shaders too! This demo shows how to communicate between a particle and material shader for complex effects with many moving parts. |
| <img src="img/demos/PixelPerfectOutline3DDemo.png" width="220"> | **Pixel-perfect 3D outline**<br>`PixelPerfectOutline3DDemo.tscn` | Drawing the outline in clip space instead of vertex space keeps it a constant width regardless of distance from the camera or object scale. Suited to user interfaces, object highlights and technical drawings. |
| <img src="img/demos/Shockwave3DDemo.png" width="220"> | **3D shockwave**<br>`Shockwave3DDemo.tscn` | This shader uses vertex manipulation to propagate a spherical shockwave through the geometry. |
| <img src="img/demos/SphereMaskDemo.png" width="220"> | **Spherical mask**<br>`SphereMaskDemo.tscn` | A sphere-shaped mask is applied to the bridge to make it disappear when too far from the lantern. |
| <img src="img/demos/StylizedFireDemo.png" width="220"> | **Stylized fire**<br>`StylizedFireDemo.tscn` | A particle system with custom world coordinates and noise-based alpha erosion. |
| <img src="img/demos/StylizedLiquidDemo.png" width="220"> | **Stylized bottled liquid**<br>`StylizedLiquidDemo.tscn` | A custom wobble shader, with a script that tells the liquid shader when movement happens. The liquid mesh's origin should sit roughly at its centre. |
| <img src="img/demos/StylizedWaterfallDemo.png" width="220"> | **Stylized waterfall**<br>`StylizedWaterfallDemo.tscn` | Flowing water built without flowmaps, using UVs and vertex colours authored in Blender. |
| <img src="img/demos/TextureMixDemo.png" width="220"> | **Texture mixing methods**<br>`TextureMixDemo.tscn` | This shader mixes albedo and normal map textures based on different parameters. Such as vertex color, ambient occlusion, and world space normal. |
| <img src="img/demos/UnlitDirectionalTint.png" width="220"> | **Unlit directional tint**<br>`UnlitDirectionalTint.tscn` | An unlit shader that tints the model depending on the world normal. The unlit tint shader is on the left, and the regular shader with albedo on the right. |
| <img src="img/demos/Water3DDemo.png" width="220"> | **3D water**<br>`Water3DDemo.tscn` | The water shader uses the depth and color buffer to cause a stylized refraction effect. The shader highlights intersections with foam using the depth buffer. |
| <img src="img/demos/WindGrassDemo.png" width="220"> | **Wind grass**<br>`WindGrassDemo.tscn` | A wind shader that uses a MultiMesh to create blades of grass and a noise texture for the wind. This shader also supports one character interacting with the grass. |
| <img src="img/demos/WindTreesDemo.png" width="220"> | **Wind trees**<br>`WindTreesDemo.tscn` | This shader uses vertex displacement driven by noise and masked with vertex colors to create realistic foliage reacting to wind. |
| <img src="img/demos/XRay3DDemo.png" width="220"> | **3D x-ray**<br>`XRay3DDemo.tscn` | This shader generates a black and white mask that determines where color information from the XRay view should override color information from the Main view. The XRay view is a glowing fresnel effect. |

### 2D shaders

| | Demo | What it shows |
| --- | --- | --- |
| <img src="img/demos/BlurGlowDemo.png" width="220"> | **2D glow from a blur pass**<br>`BlurGlowDemo.tscn` | The shader takes a sprite and blurs it in two passes. It uses this blurred texture as a mask that feeds into the MainView's shader. The MainView applies a glow around the character. |
| <img src="img/demos/Clouds2DDemo.png" width="220"> | **2D clouds**<br>`Clouds2DDemo.tscn` | Use noise and texture scrolling to add shadows cast by overhead clouds to your world. |
| <img src="img/demos/Dissolve2DDemo.png" width="220"> | **2D dissolve**<br>`Dissolve2DDemo.tscn` | A noise mask dissolves the sprite and generates a second mask that fills the emission points array of a CPUParticles2D. The dissolve mask is scaled down in ScaledView, then its pixels are read in GDScript to build the particle mask. |
| <img src="img/demos/NoiseDemo.png" width="220"> | **Noise types**<br>`NoiseDemo.tscn` | Several common types of random noise, selecting the proper noise to shape your shaders is a key step in creating appealing effects. |
| <img src="img/demos/Outline2DDemo.png" width="220"> | **2D outline**<br>`Outline2DDemo.tscn` | Shaders are excellent for the not-so-easy task of outlining 2D sprites - outlining only outside the pixels, inside, or both. |
| <img src="img/demos/PaletteSwap2DDemo.png" width="220"> | **2D palette swap**<br>`PaletteSwap2DDemo.tscn` | The sprite is made grayscale, and the shade of gray selects a colour from a palette. Multiple palettes are supported, selected with a `palette_index` parameter. |
| <img src="img/demos/PreBakedGlowDemo.png" width="220"> | **Baked-in-texture glow**<br>`PreBakedGlowDemo.tscn` | A shader on a premade sprite creates a glow. The sprite's texture needs glow baked in for the shader to manipulate its alpha and colour intensity. |
| <img src="img/demos/Reflection2DDemo.png" width="220"> | **2D reflection (Sprite2D)**<br>`Reflection2DDemo.tscn` | A vertical mirror shader fades a reflection of the screen texture into a background colour. A gradient texture controls how quickly the reflection disappears. |
| <img src="img/demos/Reflection2DTextureRectDemo.png" width="220"> | **2D reflection (TextureRect)**<br>`Reflection2DTextureRectDemo.tscn` | This shader achieves the same results as the Reflection2DDemo but uses a TextureRect instead of a sprite. |
| <img src="img/demos/Water2DDemo.png" width="220"> | **Top-down 2D water**<br>`Water2DDemo.tscn` | The top-down 2D water shader. The diffuse color texture has no light information. The shader calculates the shadows, and you can use the modulate property to tint it. |
| <img src="img/demos/WaterSidescroll2DDemo.png" width="220"> | **Side-scrolling 2D water**<br>`WaterSidescroll2DDemo.tscn` | This side-scrolling water shader builds on the Reflection2DDemo. There is a hidden, simplified Water2DSideSimple node to help you understand the basics. |
| <img src="img/demos/XRay2DDemo.png" width="220"> | **2D x-ray**<br>`XRay2DDemo.tscn` | This shader uses a black and white mask to determine where color information from the XRay view should override color information from the Main view. |

### Screen and viewport effects

| | Demo | What it shows |
| --- | --- | --- |
| <img src="img/demos/BlurViewportContainersDemo.png" width="220"> | **Motion blur with SubViewportContainers**<br>`BlurViewportContainersDemo.tscn` | Uses ViewportContainers to compose a scene that uses Gaussian blur as motion blur. The ship is in a separate viewport, so it's not affected by the motion blur. |
| <img src="img/demos/BlurViewportTexturesDemo.png" width="220"> | **Motion blur with TextureRects**<br>`BlurViewportTexturesDemo.tscn` | Uses TextureRects to compose a scene that uses Gaussian blur as motion blur. It's an alternative setup to produce a result like BlurViewportContainers. |
| <img src="img/demos/EnvironmentGlowDemo.png" width="220"> | **Glow from a WorldEnvironment**<br>`EnvironmentGlowDemo.tscn` | Glow on 2D objects from a built-in WorldEnvironment node, without writing a shader for it. |
| <img src="img/demos/InvertedColorsDemo.png" width="220"> | **Inverted colours**<br>`InvertedColorsDemo.tscn` | This shader takes the colors output by the demo viewport and inverts them - white is black, blue isn't blue, not red is red, etc. |
| <img src="img/demos/PointilismDemo.png" width="220"> | **Pointilism**<br>`PointilismDemo.tscn` | You can achieve a pointillism or dithering effect by turning the color from your viewport into grayscale and using the step function. |
| <img src="img/demos/ShockwaveDemo.png" width="220"> | **Screen distortion (2D shockwave)**<br>`ShockwaveDemo.tscn` | This shader generates a torus-shaped black and white mask, the data of which is used to distort the UVs of the demo viewports to make a shockwave distortion effect. |
## Contributing

Found a bug, or want to add a shader?
[Open an issue](https://github.com/keshon/godot-shaders/issues/new).

Run [the checks](godot/tests/README.md) before opening a pull request. A new
demo dropped into `Demos/` is picked up by them automatically.

Code follows GDQuest's [GDScript style
guide](https://www.gdquest.com/docs/guidelines/best-practices/godot-gdscript/),
which the existing sources were written against.

## Credits

The shaders and demos are the work of [GDQuest](https://www.gdquest.com/) and
its contributors, made for the Godot Shader Secrets course. This fork only
ports them.

Stylized fire adapted from a Unity tutorial by
[@minionsart](https://twitter.com/minionsart/).

Licensed under the terms in [LICENSE](LICENSE).
