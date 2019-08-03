ngrading
=====

NPad's Color Grading Library

Requires LOVE 11.0 or later to run. [Demo.LOVE](https://cdn.discordapp.com/attachments/330089431379869708/607065237157445658/demo.love)

Color Grading
-----

Color grading is a post-processing effect to improve the appearance of image using precomputed RGB table.
Any effect that doesn't require neighbor pixels such as hue shift, contrast, sepia, etc. can be precomputed using the LUT table.

Two variants of LUT table can be used:

* `neutral-lut16.png` has 16 width pixels per cell and contains 4x4 cells (64x64). Useful for low-end devices where prformance and memory matters.

* `neutral-lut64.png` has 64 width pixels per cell and contains 8x8 cells (512x512). Recommended color table for most devices.

Functions
-----

#### `ColorGrading ngrading.load(string|ImageData image, number pixelsPerCell)`

Create new `ColorGrading` object from specified RGB lookup-table.

Parameters:

* `image` - RGB lookup-table/LUT file.

* `pixelsPerCell` - Width of single cell in pixels.

#### `string ngrading.getShader()`

Get the internal shader string used for the color grading effect. The shader string contains this function

```glsl
vec4 ngrading(Image tex, vec2 textureCoords);
```

which you can concatenate with your custom shader.

> This function is a low-level function. Only use this if you plan on using custom shaders but with color grading!

#### `void ColorGrading:apply()`

Set the shader to color grading shader. Any subsequent drawing will use the color grading shader.
To disable it, call `love.graphics.setShader(othershader)` or `love.graphics.setShader()`.

> This function replaces the current active shader to color grading shader.

#### `void ColorGrading:setupShaderData([Shader shader])`

Prepares the shader to apply color grading data such as LUT.

Parameters:

* `shader` - Shader to prepare the color grading data. Defaults to `love.graphics.getShader()` and error if there are no active shader.

> This function is a low-level function. Only use this if you plan on using custom shaders but with color grading!
