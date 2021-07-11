NPad Libraries
=====

Various NPad Lua libraries for LOVE can be found here. Most libs are single files unless noted.

Check each file/folder for license terms.

ts-declarations
-----

This is not a library, but it's TypeScript definitions meant to be used with [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua).

Each file correspond to each module, unless noted. Note that some module may not have TypeScript definitions, yet.

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

![Example](https://cdn.discordapp.com/attachments/495385205520072704/854188364429262848/unknown.png)

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

	love.graphics.setColor(0.3, 0.3, 0.3)
	love.graphics.rectangle("fill", rect1:get())
	love.graphics.rectangle("fill", rect2:get())
	love.graphics.rectangle("fill", rect3:get())
	love.graphics.rectangle("fill", rect4:get())

	local font = love.graphics.getFont()
	love.graphics.setColor(1, 1, 1)
	drawRectCenter("Rectangle 1", rect1, font)
	drawRectCenter("Rectangle 2", rect2, font)
	drawRectCenter("Rectangle 3", rect3, font)
	drawRectCenter("Rectangle 4", rect4, font)
end

function love.resize()
	NLay.update(love.window.getSafeArea())
end
```

Features not implemented yet:

* [Aspect ratio size 0 constraint](https://developer.android.com/training/constraint-layout#ratio)

* [Bidirectional constraint chain](https://developer.android.com/training/constraint-layout#constrain-chain)

Documentation can be found at https://github.com/MikuAuahDark/NPad93/blob/master/doc/NLay.md
