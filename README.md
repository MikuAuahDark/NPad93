NPad Libraries
=====

Various NPad Lua libraries for LOVE can be found here. Most libs are single files unless noted.

Check each file/folder for license terms.

declarations
-----

This is not a library, but it's type definitions.

* Files ending with `.ts` is meant to be used with [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua).
* Files ending with `.tl` is meant to be used with [Teal](https://github.com/teal-language/tl/blob/master/docs/declaration_files.md).

Each file correspond to each module, unless noted. Note that some module may not have type definitions, yet.

NVec
-----

**N**Pad **Vec**tor library, LuaJIT FFI-accelerated [hump.vector](https://github.com/vrld/hump/blob/master/vector.lua)-compatible
vector library. Meant as drop-in replacement of hump.vector. Originally written for my game for optimization
purpose, but I think it's better if I make this as standalone and let everyone use it.

For documentation, check out hump.vector documentation: https://hump.readthedocs.io/en/latest/vector.html

NGrading
-----

**N**Pad Color **Grading**, provides easy color grading for your post-processing needs.

For documentation, check out the `ngrading` folder.

NWFC
-----

**N**Pad [**W**ave **F**unction **C**ollapse](https://github.com/mxgmn/WaveFunctionCollapse), WFC implemented in Lua and tries to
be 1:1 mapping between the original WFC.

NFML
-----

**N**Pad **F**FI/Fast/Fine **M**ath **L**ibrary, meant as alternative to CPML. **Work in progress!**

Functions mostly follows [GLSL function names](http://www.shaderific.com/glsl-functions).

NLog
-----

**N**Pad **Log**ging library.

* Uses ANSI color codes on Linux, macOS, and Windows 10 1607

* Uses Windows console API on Windows 10 prior 1607

* Uses [Android native logging](https://developer.android.com/ndk/reference/group/logging) functions

This library missed iOS implementation and may not run with it.

The log level are divided by 4: `info`, `warn`, `error`, and `debug`. NLog exports `nlog.info`, `nlog.warn`, ... and so on.
Furthermore, there's also functions with `f` suffix (`nlog.infof`) which accepts formatted string same as `string.format`.

There's `nlog.getLevel` to retrieve the current logging level:

* 0 = don't print anything

* 1 = print errors (`nlog.error`/`nlog.errorf`)

* 2 = print warnings (`nlog.warn`/`nlog.warnf`)

* 3 = print information (`nlog.info`/`nlog.infof`)

* 4 = print debug information (`nlog.debug`/`nlog.debugf`)

Ensure to modify the `ENVIRONMENT_VARIABLE` variable prior using the library. It's `NLOG_LOGLEVEL` environment variable by default.

NLay
-----

**N**Pad **Lay**outing Library

NLay (pronounced "Enlay") is layouting library inspired by the flexibility of Android's [ConstraintLayout](https://developer.android.com/training/constraint-layout).
This layouting library attempts to implement subset of the ConstraintLayout layouting functionality.

NLay is **NOT** full UI library. It merely function as helper on element placement on the screen. However you are 100% allowed to use NLay for your full featured UI library!

Example:

![Example](https://github.com/user-attachments/assets/6501ce22-5749-43de-8441-bee089414237)

Code to reproduce rectangle placement above are as follows

```lua
local NLay = require("nlay")
local love = require("love")

local function drawRectCenter(text, rect, font)
	local w = font:getWidth(text)
	local h = font:getHeight()
	local root = NLay

	local x, y = NLay.inside(rect):constraint(rect, rect, rect, rect):size(w, h):get()
	love.graphics.print(text, font, x, y)
end

function love.load()
	NLay.update(love.window.getSafeArea())
end

function love.draw()
	local root = NLay
	local insideRoot = NLay.inside(root, 10)

	local rect1 = insideRoot:constraint(root, root)
		:size(100, 100)
	local rect2 = insideRoot:constraint(root, rect1, nil, root)
		:size(0, 100)
		:margin({nil, 10})
	local rect3 = insideRoot:constraint(rect2, rect2, nil, rect2)
		:size(150, 100)
		:margin({10})
	local rect4 = insideRoot:constraint(rect3, rect3)
		:into(false, true)
		:size(75, 100)
		:margin({10})
	local rect5 = insideRoot:constraint(nil, NLay.line(insideRoot, "horizontal", "percent", 0.25), NLay.line(insideRoot, "vertical", "percent", -0.2))
		:size(96, 96)
	local rect6 = insideRoot:constraint(rect2, rect2, rect5, rect4)
		:size(0, 0)
		:into(false, true, false, false)
		:margin({10, 0, 10, 10})
		:ratio(9/16)

	love.graphics.setColor(0.3, 0.3, 0.3)
	love.graphics.rectangle("fill", rect1:get())
	love.graphics.rectangle("fill", rect2:get())
	love.graphics.rectangle("fill", rect3:get())
	love.graphics.rectangle("fill", rect4:get())
	love.graphics.rectangle("fill", rect5:get())
	love.graphics.rectangle("fill", rect6:get())

	local font = love.graphics.getFont()
	love.graphics.setColor(1, 1, 1)
	drawRectCenter("Rectangle 1", rect1, font)
	drawRectCenter("Rectangle 2", rect2, font)
	drawRectCenter("Rectangle 3", rect3, font)
	drawRectCenter("Rectangle 4", rect4, font)
	drawRectCenter("Rectangle 5", rect5, font)
	drawRectCenter("Rectangle 6", rect6, font)
end

function love.resize()
	NLay.update(love.window.getSafeArea())
end

```

Features not implemented yet:

* [Bidirectional constraint chain](https://developer.android.com/training/constraint-layout#constrain-chain)

Documentation can be found at https://github.com/MikuAuahDark/NPad93/blob/master/doc/NLay.md

NAMI
-----

**N**Pad **A**udio **M**etadata **I**nspector

A file-based audio metadata reader for your custom user tracks needs. **Work-in-progress!**

NAFL
-----

**N**Pad **A**dvanced **F**rame **L**imiter

A frame limiter with 3 possible modes that can be switched at runtime.

Full markdown documentation will be written soon. Currently all public functions are annotated.

NTT
-----
**N**Pad **T**ween **T**imer

flux-compatible tween implementation with additional enhancements and restrictions:

* Tweening same variable on same object is forbidden.
* `:after()` tween no longer started if the parent is stopped. https://github.com/rxi/flux/issues/12
* Fully annotated using [sumneko's Lua annotation syntax](https://github.com/sumneko/lua-language-server/wiki/Annotations).

For documentation and usage, please see flux repository: https://github.com/rxi/flux

If you want to replace existing flux library, either rename `ntt.lua` to `flux.lua` or replace all `require`s from `flux` to `ntt`.

NAniTe
-----
**N**Pad **Ani**mation **T**imelin**e**

Timeline-based animation system with support of forward and backward update.

[Demo LOVE Project v1.0.0](https://MikuAuahDark.github.io/nanite-demo.love).
Control are as follows:
* `space` - Pause/resume the animation
* `enter` - Toggle between forward or backward update
* `left` and `right` arrow button - Move the animation backward and forward 5ms (/tick with key repeat).
* `shift` - Increase the behavior above 3x faster (so 15ms)

Documentation can be found at https://github.com/MikuAuahDark/NPad93/blob/master/doc/NAniTe.md

shlex
-----
Simple lexical analysis, translated directly from Python's shlex.

From Python documentation: The shlex class makes it easy to write lexical analyzers for simple syntaxes resembling that of the Unix shell. This will often be useful for writing minilanguages, (for example, in run control files for Python applications) or for parsing quoted strings.

Note: This library is untested with Python's test vectors. Use at your own discretion.

vires
-----

Virtual resolution system with safe area support.

Best used with NLay.

Manami
-----
A library to display text as one character at a time.
Similar to [reflowprint](https://github.com/josefnpat/reflowprint) but supports UTF-8, colored text, and justify alignment.

https://user-images.githubusercontent.com/7500438/210179454-50695a5f-e720-48d9-bd41-a7b34e1638cb.mp4

Example
```lua
local manami = require("manami")
local textToWrite = {
	{1, 0, 0}, "This text is written ",
	{1, 1, 0}, "to demonstrate the ",
	{0, 1, 0}, "functionality of 愛海 (Manami), ",
	{0, 1, 1}, "an improved reflowprint ",
	{0, 0, 1}, "with UTF-8 and multicolor ",
	{1, 1, 1}, "support along with justify alignment.",
}
local reflow = manami(textToWrite, width, targetAlignment)
```

The `manami` function signature is as follows:

```lua
manami manami(string|table text, limit, align, font, separator, lengthCalc): manami
```

Where:
* `text` - String or colored text according to [LOVE colored text format](https://love2d.org/wiki/love.graphics.print#Function_3).
* `limit` - Wrap the line after this many horizontal pixels.
* `align` - [Text alignment](https://love2d.org/wiki/AlignMode). Default is `"left"`.
* `font` - Font to use. Default is return value of `love.graphics.getFont()` when this function is called.
* `separator` - How to separate the text out. If this is string, then it's treated as delimiter. If this is function, then it returns how many character to consume. Default is function that always return 1 (consume one character at a time).
* `lengthCalc` - How to calculate the duration of each character before showing the next one. By default this is a function that returns the amount of character passed.
* Returns new `manami` object.

The function signature of `separator` (if function is passed) is as follows:
```lua
number separator(string s)
```
Where:
* `s` - Unconsumed text.
* Returns `number` of how many (UTF-8) character(s) (**not bytes**) to consume from `s`.

The function signature of `lengthCalc` is as follows:
```lua
number lengthCalc(string s)
```
Where:
* `s` - The chopped text based on return value of `separator` function.
* Returns `number` of the text duration in _time units_.

The definition of _time units_ is up to user. If user assume it's in seconds, then with default `separator` and `lengthCalc`, the character will be displayed one-by-one every second.

A demo `main.lua` can be found here: https://gist.github.com/MikuAuahDark/95c5b626b9607da80d9372d906c3d7b6#file-main-lua (don't use the outdated `manami.lua` there).

NPNN
-----
**NP**ad **N**eural **N**etwork

A simple neural network implementation. It has implenentation of Linear/Dense/FC layer and LSTM layer.

Normally you pass the weights exported from PyTorch to the layers.

```py
import json
import torch

# Say you have PyTorch model in "model" variable
model: torch.nn.Module

class EncodeTensor(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, torch.Tensor):
            return obj.tolist()
        return json.JSONEncoder.default(self, obj)

with open("modeldata.json", "w", encoding="UTF-8") as f:
    json.dump(model.state_dict(), f, cls=EncodeTensor, ensure_ascii=False)
```

Then you load `modeldata.json` using your favorite JSON decoder and pass the weights and the biases to the NN functions.

N9P
-----
**N**Pad93's **9**-**P**atch.

Yet another [9-patch](https://developer.android.com/studio/write/draw9patch) library for LÖVE.

Compared to different implementation, it has an API on constructing your own slices and your own texture or let the
library do everything for you using `.9.png` image.

Simple construction example:

```lua
-- Automatic mode. image.9.png must follow Android 9-patch drawable spec.
local n9p = require("n9p")
local stretchableImage = n9p.loadFromImage("image.9.png")

-- stretchableImage is now usable
```

Advanced construction example:

```lua
-- Manual mode. Specify the stretchable regions yourself.
local n9p = require("n9p")
local existingImage = love.graphics.newImage("image_32x32.png")
local stretchableImage = n9p.newBuilder()
	:addHorizontalSlice(8, 24)
	:addVerticalSlice(8, 24)
	:setHorizontalPadding(4, 28)
	:setVerticalPadding(4, 28)
	:build(existingImage:getDimensions())
stretchableImage:setTexture(existingImage)

-- stretchableImage is now usable
```

Drawing example:

```lua
local stretchableImage = ... -- (see above)
local rootWindowGetter = {get = love.window.getSafeArea} -- fulfils get(self) = x,y,w,h

function love.draw()
	-- Method 1 of drawing: specifying position directly
	local w, h = love.graphics.getDimensions()
	stretchableImage:draw(0, 0, w, h)

	-- Method 2 of drawing: specifying constraint object
	stretchableImage:drawConstraint(rootWindowGetter)
end
```

No separate mrkdown documentation for now, but the public APIs are fully documented.
