-- NAniTe, NPad Animation Timeline
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

---@class nanite
local nanite = {
	_VERSION = "1.0.0",
	_AUTHOR = "Miku AuahDark",
	_LICENSE = "MIT"
}
---@private
nanite.__index = nanite

---@param x number
local function linear(x)
	return x
end

---@param a number
---@param b number
local function minmax(a, b)
	if a > b then
		return b, a
	else
		return a, b
	end
end

-- `loadstring` is not available in script environment, upvalue it out.
local loadstring = loadstring

---@alias nanite.Easing fun(x:number):number
---@alias nanite.UpdateHook fun(userdata:any,dt:number)

---@class nanite.Timeline
---@field public id string? Timeline identifier to be referenced in other timeline (optional). Alphanumeric only (+ underscore) where first character must be a letter.
---@field public start number|string When to start this timeline. Can be number or string defines on how to calculate the value.
---@field public stop number|string When to stop this timeline. Can be number or string defines on how to calculate the value. Mutually exclusive with `duration`.
---@field public duration number|string How long is this tween. Can be number or string defines on how to calculate the value. Mutually exclusive with `stop`.
---@field public easing nanite.Easing? What easing function to use (optional)? The easing function domain and codomain must be [0, 1] over real numbers.
---@field public variables table<string,number>|table<nanite.Easing,table<string,number>> Variables to interpolate, additionally with custom easing function to use as table key.
---@field public updateHook nanite.UpdateHook[] List of functions that must be called when interpolated values are updated.
---@field public userdata any? Additional userdata to associate within update hook

---Internal use class
---@class nanite.SimplifiedTimeline
---@field package id string?
---@field package start number|string
---@field package stop number|string
---@field package duration number|string
---@field package updateHook nanite.UpdateHook[]
---@field package userdata any?
---@field package resolved boolean
---@field package parent nanite
---@field package variableList {name:string,easing:nanite.Easing,start:number,finish:number}[]
---@field package inArea boolean

---@param source table
---@param timelines nanite.Timeline[]?
function nanite:new(source, timelines)
	---@private
	---@type nanite.SimplifiedTimeline[]
	self.timeline = {}
	---@type table<string,nanite.SimplifiedTimeline>
	---@private
	self.timelineLookup = {}
	---@private
	self.duration = 0
	---@private
	self.time = 0
	---@private
	self.globalEnvironment = nil
	---@private
	self.variableInCheck = nil
	---@private
	self.source = source

	for _, v in ipairs(timelines or {}) do
		self:_add(v, false)
	end

	self:_resolveTime()
end

---@param timeline nanite.Timeline
function nanite:add(timeline)
	return self:_add(timeline, true)
end

---Update animation timeline. Both positive and negative `dt` is supported.
---@param dt number
function nanite:update(dt)
	local oldTime = self.time
	---@private
	self.time = math.min(math.max(self.time + dt, 0), self.duration)

	for _, v in ipairs(self.timeline) do
		local update = true

		if v.inArea then
			if self.time >= (v.start + v.duration) then
				v.inArea = false
			elseif self.time < v.start then
				v.inArea = false
			end
		elseif self.time >= v.start and self.time < (v.start + v.duration) then
			v.inArea = true
		else
			local start, stop = minmax(oldTime, self.time)
			-- Handle case where dt is larger than duration
			if start < v.start and stop >= (v.start + v.duration) then
				-- no-op
			else
				-- Out of range, don't update
				update = false
			end
		end

		if update then
			local relativeTime, relativeOldTime = self.time - v.start, oldTime - v.start
			---@diagnostic disable-next-line: param-type-mismatch
			local newdt = math.min(math.max(relativeTime, 0), v.duration) - math.min(math.max(relativeOldTime, 0), v.duration)
			local m = math.min(math.max(relativeTime / v.duration, 0), 1)

			for _, var in ipairs(v.variableList) do
				local value
				-- Guarante values
				if m <= 0 then
					value = var.start
				elseif m >= 1 then
					value = var.finish
				else
					local t = var.easing(m)
					value = var.start * (1 - t) + var.finish * t
				end

				self.source[var.name] = value
			end

			for _, updateHook in ipairs(v.updateHook) do
				updateHook(v.userdata, newdt)
			end
		end
	end

	return self.time <= 0 or self.time >= self.duration
end

---@param timeline nanite.Timeline
---@param resolveNow boolean
---@private
function nanite:_add(timeline, resolveNow)
	-- Normalize interpolated variables
	---@type nanite.SimplifiedTimeline
	local t = {
		id = timeline.id,
		start = timeline.start,
		stop = timeline.stop,
		duration = timeline.duration,
		updateHook = {},
		userdata = timeline.userdata,
		resolved = false,
		parent = self,
		variableList = {},
		inArea = false,
	}

	if timeline.id then
		assert(type(timeline.id) == "string", "timeline identifier must be string")
		assert(timeline.id:match("^[A-Za-z_][A-Za-z0-9_]*$"), "timeline identifier is not a valid identifier")

		-- Ensure it's not been taken
		if self.timelineLookup[timeline.id] then
			error("variable \""..timeline.id.."\" has been taken")
		end

		if self.globalEnvironment then
			self.globalEnvironment[t.id] = t
		end

		self.timelineLookup[timeline.id] = t
	end

	if (timeline.duration and timeline.stop) or ((not timeline.duration) and (not timeline.stop)) then
		error("duration and stop time is mutually exclusive")
	end

	local easing = timeline.easing or linear
	self.timeline[#self.timeline + 1] = t

	if timeline.updateHook then
		for _, v in ipairs(timeline.updateHook) do
			t.updateHook[#t.updateHook + 1] = v
		end
	end

	for key, value in pairs(timeline.variables) do
		if type(key) == "string" then
			---@cast value number
			t.variableList[#t.variableList + 1] = {
				name = key,
				easing = easing,
				start = self.source[key],
				finish = value
			}
		else
			---@cast value table<string,number>
			for name, value2 in pairs(value) do
				t.variableList[#t.variableList + 1] = {
					name = name,
					easing = key,
					start = self.source[name],
					finish = value2
				}
			end
		end
	end

	if resolveNow then
		self:_resolveVariable(t)
		self:_updateStart(t)
	end
end

---@private
function nanite:_resolveTime()
	for _, v in ipairs(self.timeline) do
		self:_resolveVariable(v)
	end

	for _, v in ipairs(self.timeline) do
		self:_updateStart(v)
	end
end

---@param simplified nanite.SimplifiedTimeline
---@private
function nanite:_resolveVariable(simplified)
	if simplified.resolved then return end

	if type(simplified.start) == "string" then
		simplified.start = self:_runFormula(simplified, simplified.start)
	end

	if type(simplified.stop) == "string" then
		simplified.stop = self:_runFormula(simplified, simplified.stop)
	end

	if type(simplified.duration) == "string" then
		simplified.duration = self:_runFormula(simplified, simplified.duration)
	end

	if simplified.stop then
		-- Convert to duration
		simplified.duration = simplified.stop - simplified.start
		simplified.stop = nil
	end

	simplified.resolved = true

	-- Update max duration
	---@private
	self.duration = math.max(self.duration, simplified.start + simplified.duration)
end

---@param a nanite.SimplifiedTimeline
---@param b nanite.SimplifiedTimeline
---@private
function nanite._sortByEndTime(a, b)
	return (a.start + a.duration) > (b.start + b.duration)
end

---@param timeline nanite.SimplifiedTimeline
---@private
function nanite:_updateStart(timeline)
	---@type nanite.SimplifiedTimeline[]
	local temp = {}

	-- Insert with less end time
	for _, v in ipairs(self.timeline) do
		if v ~= timeline and (v.start + v.duration) <= timeline.start then
			temp[#temp + 1] = v
		end
	end

	-- Sort
	table.sort(temp, nanite._sortByEndTime)

	for _, var in ipairs(timeline.variableList) do
		local found = false

		for _, tl in ipairs(temp) do
			for _, tlvar in ipairs(tl.variableList) do
				if tlvar.name == var.name then
					var.start = tlvar.finish
					found = true
					break
				end
			end

			if found then
				break
			end
		end

		if not found then
			var.start = self.source[var.name]
		end
	end
end

---@private
function nanite:_initScriptEnv()
	if not self.globalEnvironment then
		local env = {}
		env._G = env
		---@cast env +mathlib

		for k, v in pairs(math) do
			env[k] = v
		end

		-- emit random, randomseed, and huge
		env.random = nil
		env.randomseed = nil
		env.huge = nil
		env.assert = assert

		-- add our script-specific functions
		for k, v in pairs(nanite.scriptEnv) do
			env[k] = v
		end

		-- add timeline variables
		for k, v in pairs(self.timelineLookup) do
			env[k] = v
		end

		---@private
		self.globalEnvironment = env
		---@type table<nanite.SimplifiedTimeline,boolean>
		---@private
		self.variableInCheck = {}
	end
end

---@param variable nanite.SimplifiedTimeline
---@param formula string
---@private
function nanite:_runFormula(variable, formula)
	self:_initScriptEnv()

	-- Check for cyclic
	assert(not self.variableInCheck[variable], "cyclic reference detected")
	self.variableInCheck[variable] = true
	---@type fun():number
	local chunk = assert(loadstring("return "..formula, formula))
	setfenv(chunk, self.globalEnvironment)
	local result = assert(chunk(), "missing return value")
	assert(type(result) == "number", "invalid return value")
	self.variableInCheck[variable] = false

	return result
end

---@private
nanite.scriptEnv = {}

---@param name nanite.SimplifiedTimeline?
function nanite.scriptEnv.start(name)
	assert(name, "variable is not defined")
	---@diagnostic disable-next-line: invisible
	name.parent:_resolveVariable(name)
	return name.start
end

---@param name nanite.SimplifiedTimeline?
function nanite.scriptEnv.duration(name)
	assert(name, "variable is not defined")
	---@diagnostic disable-next-line: invisible
	name.parent:_resolveVariable(name)
	return name.duration
end

---@param name nanite.SimplifiedTimeline?
function nanite.scriptEnv.finish(name)
	assert(name, "variable is not defined")
	---@diagnostic disable-next-line: invisible
	name.parent:_resolveVariable(name)
	return name.start + name.duration
end

setmetatable(nanite, {__call = function(_, source, timelines)
	local object = setmetatable({}, nanite)
	object:new(source, timelines)
	return object
end})
---@cast nanite +fun(source:table,timelines:nanite.Timeline[]):nanite

return nanite

--[[
Changelog:

v1.0.0: 2022-11-18
> Initial release.
]]
