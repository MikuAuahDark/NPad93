-- NPad's Advanced Frame Limiter
--
-- Copyright (c) 2022 Miku AuahDark
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

local love = require("love")

local nafl = {
	_VERSION = "1.0.1",
	_AUTHOR = "MikuAuahDark",
	_LICENSE = "MIT"
}

local var = {
	value = nil,
	mode = "sleep",
	accumulator = 0,
	time = 0,
	canvas = nil,
	redraw = false,
	queuedValue = nil,
	queuedMode = "sleep",
	displayRateDelay = 4,
	refreshRate = 0,
	monkeypatch = true,
	loveRun = love.run,
	loveErrhand = love.errorhandler or love.errhand
}

local loveGetCanvas = love.graphics.getCanvas
local loveSetCanvas = love.graphics.setCanvas
local loveReset = love.graphics.reset

---@param value? integer
---@param mode? '"sleep"' | '"lockstep"' | '"vblank"'
local function setLimit(value, mode)
	-- vblank 1 is no-op
	if mode == "vblank" and value == 1 then
		value, mode = nil, nil
	end

	var.queuedValue = value
	var.queuedMode = mode
end

local function needBackbuffer()
	return var.mode == "vblank" or var.mode == "lockstep"
end

local function applyMonkeypatch()
	love.graphics.reset = nafl.reset
	love.graphics.getCanvas = nafl.getCanvas
	love.graphics.setCanvas = nafl.setCanvas
end

local function revertMonkeypatch()
	love.graphics.reset = loveReset
	love.graphics.getCanvas = loveGetCanvas
	love.graphics.setCanvas = loveSetCanvas
end

local function initSleep()
	var.frameTime = 1 / var.value
	var.time = love.timer.getTime()
end

local function initLockstep()
	var.frameTime = 1 / var.value
	var.accumulator = 0
	var.firstTime = true
	var.runDraw = false
	var.forceDraw = false
	nafl.resize()

	if var.monkeypatch then
		applyMonkeypatch()
	end
end

local function initVblank()
	nafl.resize()

	if var.monkeypatch then
		applyMonkeypatch()
	end
end

---@param dt number
local function updateSleep(dt)
	var.time = love.timer.getTime()
	return true, dt
end

---@param dt number
local function updateLockstep(dt)
	var.runDraw = false

	-- Always draw the 1st frame regardless
	if var.firstTime then
		var.firstTime = false
		var.runDraw = true
		return true, dt
	end

	-- Prevent spiral of death by not lockstepping
	-- if dt is larger than the intended frame time
	if dt > var.frameTime then
		var.runDraw = true
		return true, dt
	end

	-- If force draw is issued, allow update and empty
	-- out the accumulator.
	if var.forceDraw then
		dt = dt + var.accumulator
		var.accumulator = 0
		return true, dt
	end

	var.accumulator = var.accumulator + dt
	if var.accumulator >= var.frameTime then
		var.accumulator = var.accumulator - var.frameTime
		var.runDraw = true
		return true, var.frameTime
	end

	return false, dt
end

local function drawSleep()
	return true
end

local function drawLockstep()
	love.graphics.push("all")

	if var.runDraw or var.forceDraw then
		love.graphics.setCanvas(var.canvas)
		love.graphics.clear(love.graphics.getBackgroundColor())
		var.forceDraw = false
		return true
	end

	return false
end

local function drawVblank()
	love.graphics.push("all")
	love.graphics.setCanvas(var.canvas)
	love.graphics.clear(love.graphics.getBackgroundColor())
	return true
end

local function postDrawSleep()
	love.graphics.flushBatch()
end

local function postDrawLockstep()
	love.graphics.pop()
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(var.canvas)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

local function decideSleep()
	local t = love.timer.getTime() - var.time
	local sleepFor = math.max(var.frameTime - t - 0.0005, 0)

	if sleepFor > 0 then
		love.timer.sleep(sleepFor)
	end
end

local function decideLockstep()
end

local function decideVblank()
	for i = 1, var.value - 1 do
		if love.graphics.isActive() then
			love.graphics.clear()
			love.graphics.setBlendMode("alpha", "premultiplied")
			love.graphics.draw(var.canvas)
			love.graphics.setBlendMode("alpha", "alphamultiply")
			love.graphics.present()
		end
	end
end

local initMode = {
	["sleep"] = initSleep,
	["lockstep"] = initLockstep,
	["vblank"] = initVblank,
}

local updateMode = {
	["sleep"] = updateSleep,
	["lockstep"] = updateLockstep,
	["vblank"] = updateSleep,
}

local drawMode = {
	["sleep"] = drawSleep,
	["lockstep"] = drawLockstep,
	["vblank"] = drawVblank,
}

local postDrawMode = {
	["sleep"] = postDrawSleep,
	["lockstep"] = postDrawLockstep,
	["vblank"] = postDrawLockstep
}

local decideMode = {
	["sleep"] = decideSleep,
	["lockstep"] = decideLockstep,
	["vblank"] = decideVblank
}

local function shouldPerform()
	return var.value and (var.refreshRate == 0 or var.refreshRate > var.value)
end

--====================================--
--===== Public API Listing Below =====--
--====================================--

---Get screen refresh rate. Equivalent to `select(3, love.window.getMode()).refreshrate`
---@return integer
function nafl.getRefreshRate()
	return select(3, love.window.getMode()).refreshrate
end

---Activate FPS limiter.
---
---There are 3 `mode`s that user can choose from, with the expected `value` parameter:
---* `"sleep"` - Sleeps the CPU until it reaches the desired FPS. `value` is the target FPS.
---  **Caveat**: Target FPS may not be 100% guaranteed.
---* `"lockstep"` - Run the game in lock-step fashion. `love.update` will see at least `1/value`
---  seconds but _can be higher_. `value` is the target FPS. **Caveat**: `love.timer.getFPS()`
---  reading will be inaccurate.
---* `"vblank"` - Wait for specified amount of vblank (which is `1/screen refresh rate` seconds).
---  `value` is number of vblank to wait (so value of `2` will wait for `2/screen refresh rate`
---  seconds). **Caveat**: Does not limit FPS fully when vsync is (forcefully) turned off.
---
---Calling this function without any parameter turns off the FPS limiter.
---@param mode? '"sleep"' | '"lockstep"' | '"vblank"'
---@param value? integer
function nafl.limit(mode, value)
	if mode and value then
		assert(mode == "sleep" or mode == "lockstep" or mode == "vblank", "invalid mode")
		setLimit(value, mode)
	else
		setLimit()
	end
end

---Return the internal backbuffer Canvas used on lockstep or vblank mode.
---@return love.Canvas?
function nafl.getBackbufferCanvas()
	return var.canvas
end

---This function must be called when the window is resized. The default `nafl.run`
---calls this, but if you're using your own `love.run`, make sure to call this.
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
function nafl.resize()
	if needBackbuffer() then
		var.canvas = love.graphics.newCanvas()

		if var.mode == "lockstep" then
			var.forceDraw = true
		end
	end
end

---Start NAFL routines on this frame.
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
function nafl.start()
	local changed = var.value ~= var.queuedValue or var.mode ~= var.queuedMode
	var.value = var.queuedValue
	var.mode = var.queuedMode

	if changed then
		revertMonkeypatch()
	end

	if var.value then
		if changed then
			initMode[var.mode]()
		end
	end

	var.displayRateDelay = var.displayRateDelay + 1
	if var.displayRateDelay >= 5 then
		var.displayRateDelay = 0
		var.refreshRate = nafl.getRefreshRate()
	end
end

---Update NAFL routines and determine if update logic should be called on
---this frame. `dt` must be value of `love.timer.step()`, without modifications!
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
---@param dt number `love.timer.step()`
---@return boolean call call update routine?
---@return number dt actual `dt` that should be passed to `love.update`
function nafl.update(dt)
	if shouldPerform() then
		return updateMode[var.mode](dt)
	end

	return true, dt
end

---Determine if render logic should be called on this frame.
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
---@return boolean @call draw routine?
function nafl.draw()
	if shouldPerform() then
		return drawMode[var.mode]()
	end

	return true
end

---Post-`love.update` function that must be called. Call this just before
---`love.graphics.present`.
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
function nafl.postDraw()
	if shouldPerform() then
		return postDrawMode[var.mode]()
	end
end

---Final function that must be called just before the game loop code finishes.
---
---**NOTE**: This is for advanced users. See implementation of `nafl.run`
---in nafl.lua for more information about this function!
function nafl.decide()
	if shouldPerform() then
		decideMode[var.mode]()
	end
end

---This is the default NAFL-integrated game loop, based on `love.run`.
---
---**NOTE**: This is for advanced users. Please see
---[`love.run` Wiki page](https://love2d.org/wiki/love.run) for more
---information about LOVE game loop!
---
---If you're writing your own game loop, take a note where to place the NAFL-specific
---functions. Otherwise you may get errors.
---@return function
function nafl.run()
	---@diagnostic disable-next-line: undefined-field
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		nafl.start() -- NAFL: Put this before processing events.

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					---@diagnostic disable-next-line: undefined-field
					if not love.quit or not love.quit() then
						return a or 0
					end
				-- NAFL: Handle resize event!
				elseif name == "resize" then
					nafl.resize()
				end

				---@diagnostic disable-next-line: undefined-field
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		local update update, dt = nafl.update(love.timer.step())
		-- NAFL: Only run `love.update` if `update` is `true`.

		-- Call update and draw
		---@diagnostic disable-next-line: undefined-field
		if update and love.update then love.update(dt) end

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if nafl.draw() then -- NAFL: `nafl.draw` returns boolean whetever to call `love.draw` or not.
				---@diagnostic disable-next-line: undefined-field
				if love.draw then love.draw() end
			end

			nafl.postDraw() -- NAFL: Call this just before `love.graphics.present` is called.
			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
		nafl.decide() -- NAFL: Call this at the end of game loop.
	end
end

function nafl.errorHandler(msg)
	if nafl.getBackbufferCanvas() and love.graphics.isActive() then
		loveSetCanvas()
	end
	revertMonkeypatch()

	return var.loveErrhand(msg)
end

---Equivalent to `love.graphics.getCanvas` but returns the default canvas when needed.
function nafl.getCanvas()
	local c = loveGetCanvas()

	if shouldPerform() and needBackbuffer() and (not c) then
		c = var.canvas
	end

	return c
end

---Equivalent to `love.graphics.setCanvas` but sets the default canvas when needed.
function nafl.setCanvas(c)
	if shouldPerform() and needBackbuffer() and c == nil then
		c = var.canvas
	end

	return loveSetCanvas(c)
end

---Equivalent to `love.graphics.reset` but sets the default canvas when needed.
function nafl.reset()
	loveReset()

	if shouldPerform() and needBackbuffer() then
		loveSetCanvas(var.canvas)
	end
end

---Do not monkeypatch `love.graphics.getCanvas`, `love.graphics.setCanvas`,
---and `love.graphics.reset` when using "**lockstep**" or "**vblank**" limiter
---mode.
---
---If you don't monkeypatch those LOVE functions, then you must replace all
---calls to:
---* `love.graphics.getCanvas` to `nafl.getCanvas`
---* `love.graphics.setCanvas` to `nafl.setCanvas`
---* `love.graphics.reset` to `nafl.reset`
---
---**CAUTION**: This is one-time function. Once disabled, it can't be enabled
---again. This function should be called at your main.lua, before `love.load`
---is called, otherwise the behavior of this function is undefined.
function nafl.disableMonkeypatch()
	var.monkeypatch = false
end

---Do not replace `love.run` with NAFL-written `nafl.run`. Useful if
---you already written your own `love.run` before loading this library.
---
---**CAUTION**: This is one-time function. Once disabled, it can't be enabled
---again. This function should be called at your main.lua, before `love.load`
---is called, otherwise the behavior of this function is undefined.
---
---**NOTE**: Please read `nafl.lua` if you implemented your own `love.run`
---and want to integrate this library into your game loop!
function nafl.disableNAFLRun()
	love.run = var.loveRun
end

---Do not replace `love.errorhandler` with NAFL-written `nafl.errorHandler`.
---Maybe useful if you have written your own `love.errorhandler`, but NAFL
---error handler only unsets canvas then calls the original LOVE error handler
---(or the one you wrote if overridden before loading this library)
---
---**CAUTION**: This is one-time function. Once disabled, it can't be enabled
---again. This function should be called at your main.lua, before `love.load`
---is called, otherwise the behavior of this function is undefined.
---
---**NOTE**: Please read `nafl.lua` if you implemented your own `love.run`
---and want to integrate this library into your game error handler!
function nafl.disableErrorHandler()
	love.errorhandler = var.loveErrhand
end

love.run = nafl.run
love.errorhandler = nafl.errorHandler

return nafl

--[[
Changelog:
vM.m.p: YYYY-MM-DD

v1.0.1: 2022-09-13
> Override love.errorhandler to unset Canvas and revert monkeypatch.

v1.0.0: 2022-09-09
> Initial release.
]]
