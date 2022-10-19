-- NPad Tween Timer, flux-compatible timer and tween system.
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

---@alias ntt.EasingIn '"quadin"' | '"cubicin"' | '"quartin"' | '"expoin"' | '"sinein"' | '"circin"' | '"backin"' | '"elasticin"'
---@alias ntt.EasingOut '"quadout"' | '"cubicout"' | '"quartout"' | '"expoout"' | '"sineout"' | '"circout"' | '"backout"' | '"elasticout"'
---@alias ntt.EasingInOut '"quadinout"' | '"cubicinout"' | '"quartinout"' | '"expoinout"' | '"sineinout"' | '"circinout"' | '"backinout"' | '"elasticinout"'
---@alias ntt.Easing ntt.EasingIn | ntt.EasingOut | ntt.EasingInOut | '"linear"'

---@type table<ntt.Easing, fun(x:number):number>
local easing = {
	linear = function(x) return x end
}

for k, v in pairs({
	quad    = function(p) return p * p end,
	cubic   = function(p) return p * p * p end,
	quart   = function(p) return p * p * p * p end,
	quint   = function(p) return p * p * p * p * p end,
	expo    = function(p) return 2 ^ (10 * (p - 1)) end,
	sine    = function(p) return -math.cos(p * (math.pi * .5)) + 1 end,
	circ    = function(p) return -(math.sqrt(1 - (p * p)) - 1) end,
	back    = function(p) return p * p * (2.7 * p - 1.7) end,
	elastic = function(p) return -(2^(10 * (p - 1)) * math.sin((p - 1.075) * (math.pi * 2) / .3)) end
}) do
	easing[k.."in"] = v
	easing[k.."out"] = function(x)
		return 1 - v(1 - x)
	end
	easing[k.."inout"] = function(x)
		x = x * 2

		if x < 1 then
			return v(x) / 2
		else
			return 0.5 + (1 - v(2 - x)) / 2
		end
	end
end

---@alias ntt.InternalCallbackDef {[1]:fun(userdata:any),[2]:any}

---@param list ntt.InternalCallbackDef[]
local function fireCallback(list)
	for _, v in ipairs(list) do
		v[1](v[2])
	end
end

---@param table ntt.InternalCallbackDef[]
---@param func function
---@param data any
local function insertCallback(table, func, data)
	table[#table + 1] = {func, data}
end

---@class ntt.Tween
---@field private completeCallback ntt.InternalCallbackDef[]
---@field private delayTime number
---@field private duration number
---@field private easing fun(x:number):number
---@field private next ntt.Tween?
---@field private nextVariables table?
---@field private parent ntt.Group
---@field private previous ntt.Tween?
---@field private previousdt number
---@field private source table
---@field private startCallback ntt.InternalCallbackDef[]
---@field private startValue table<any,number>
---@field private stopValue table<any,number>
---@field private started boolean
---@field private time number
---@field private updateCallback ntt.InternalCallbackDef[]
---@field private variables any[]
local Tween = {}
Tween.__index = Tween

---@param parent ntt.Group
---@param state table
---@param duration number
---@return ntt.Tween
local function newTween(parent, state, duration)
	return setmetatable({
		completeCallback = {},
		delayTime = 0,
		duration = duration,
		easing = easing["quadout"],
		next = nil,
		nextVariables = nil,
		parent = parent,
		previous = nil,
		previousdt = 0,
		source = state,
		startCallback = {},
		startValue = {},
		started = false,
		stopValue = {},
		time = 0,
		updateCallback = {},
		variables = {}
	}, Tween)
end

---Creates a new tween and chains it to the end of the existing tween; the chained tween will be called after the
---original one has finished. Any additional chained function used after :after() will effect the chained tween.
---There is no limit to how many times :after() can be used in a chain, allowing the creation of long tween sequences.
---The tweened variables are taken from the original tween object.
---@param duration number
---@param variables table
---@return ntt.Tween @The **new** tween object.
---@diagnostic disable-next-line: duplicate-set-field
function Tween:after(duration, variables)
end

---Creates a new tween and chains it to the end of the existing tween; the chained tween will be called after the
---original one has finished. Any additional chained function used after :after() will effect the chained tween.
---There is no limit to how many times :after() can be used in a chain, allowing the creation of long tween sequences.
---@param state table
---@param duration number
---@param variables table
---@diagnostic disable-next-line: duplicate-set-field
function Tween:after(state, duration, variables)
	assert(self.parent, "this tween has been stopped")

	if type(state) == "number" then
		---@diagnostic disable-next-line: cast-local-type
		state, duration, variables = self.source, state, duration
	end

	---@cast duration number
	local tween = newTween(self.parent, state, duration)
	self.next = tween
	self.nextVariables = variables
	tween.previous = self

	return tween
end

---Set the easing type which should be used by the tween.
---@param ease ntt.Easing | fun(x:number):number Easing name or function with domain of [0, 1] and codomain of [0, 1].
function Tween:ease(ease)
	if type(ease) == "function" then
		self.easing = ease
	else
		self.easing = assert(easing[ease], "unknown easing function")
	end

	return self
end

---Set the amount of time it should wait before starting the tween.
---@param n number Delay in seconds.
function Tween:delay(n)
	self.delayTime = self.delayTime - n
	return self
end

---Sets the function `fun` to be called once the tween has finished and reached its destination values.
---This function can be called multiple times to add more than one function.
---@param fun function
---@param userdata? any
function Tween:oncomplete(fun, userdata)
	insertCallback(self.completeCallback, fun, userdata)
	return self
end

---Sets the function `fun` to be called when the tween starts (once the delay has finished).
---This function can be called multiple times to add more than one function.
---@param fun function
---@param userdata? any
function Tween:onstart(fun, userdata)
	insertCallback(self.startCallback, fun, userdata)
	return self
end

---Sets the function `fun` to be called each frame the tween updates a value.
---This function can be called multiple times to add more than one function.
---@param fun function
---@param userdata? any
function Tween:onupdate(fun, userdata)
	insertCallback(self.updateCallback, fun, userdata)
	return self
end

---Stop the current tween. This will cause the tween to immediatly be removed from its parent group and will leave its
---tweened variables at their current values. Functions registered at `:oncomplete()` won't be called. Tweens created
---with `:after()` also won't be started.
function Tween:stop()
	if self.parent == nil then return end
	local tweens = self.parent:_getTweens()

	-- Cancel
	self.parent = nil
	self.next = nil
	self.nextVariables = nil

	for i, v in ipairs(tweens) do
		if v == self then
			table.remove(tweens, i)
			break
		end
	end

	-- Break link with previous chain
	if self.previous then
		assert(self.previous.next == self)
		self.previous.next = nil
		self.previous.nextVariables = nil
	end
end

function Tween:_internalUpdate(dt)
	if self.delayTime < 0 then
		self.delayTime = self.delayTime + dt
		dt = 0
	end

	if self.delayTime >= 0 and not self.started then
		fireCallback(self.startCallback)

		self.startCallback = nil -- try to free some memory :stare:
		self.started = true
		dt = dt + self.delayTime + self.previousdt
	end

	if self.started then
		-- Calculate timer
		local t = self.time + dt
		self.time = math.min(t, self.duration)
		local complete = self.time >= self.duration

		-- Prevent divide by 0
		local x = complete and 1 or self.easing(self.time / self.duration)

		-- Update variables
		for _, v in ipairs(self.variables) do
			-- Essentially linear interpolation
			self.source[v] = self.startValue[v] * (1 - x) + self.stopValue[v] * x
		end

		-- Update callback
		fireCallback(self.updateCallback)

		if complete then
			-- Complete
			fireCallback(self.completeCallback)

			if self.next then
				self.next.previousdt = t - self.time
			end

			return true
		end
	end

	return false
end

function Tween:_loadVariables(destination)
	for k, v in pairs(destination) do
		self.variables[#self.variables + 1] = k

		local s = self.source[k]
		if type(s) ~= "number" then
			error("variable '"..tostring(k).."' is not a number")
		end

		self.startValue[k] = s
		self.stopValue[k] = v
	end
end

function Tween:_hasVariable(name)
	for _, v in ipairs(self.variables) do
		if v == name then
			return true
		end
	end

	return false
end

function Tween:_getVariables()
	return self.variables
end

function Tween:_getNext()
	return self.next
end

function Tween:_getNextVariables()
	return self.nextVariables
end

function Tween:_isStopped()
	return self.parent == nil
end

function Tween:_getSource()
	return self.source
end

---@class ntt.Group
---@field private tweens ntt.Tween[]
local Group = {}
Group.__index = Group

---Create new tween associated to the current tween group.
---@param state table
---@param duration number
---@param variables table
function Group:to(state, duration, variables)
	local tween = newTween(self, state, duration)
	tween:_loadVariables(variables)
	self:_check(tween, true)
	return tween
end

---@param tween ntt.Tween
---@param insert boolean
function Group:_check(tween, insert)
	-- Check if the variable is currently tweened
	for _, t in ipairs(self.tweens) do
		if t ~= tween and t:_getSource() == tween:_getSource() then
			for _, v in ipairs(tween:_getVariables()) do
				if t:_hasVariable(v) then
					error("variable '"..tostring(v).."' is currently tweened")
				end
			end
		end
	end

	if insert then
		self.tweens[#self.tweens + 1] = tween
	end
end

function Group:_getTweens()
	return self.tweens
end

---Update the current tween group.
---@param dt number
function Group:update(dt)
	for i = #self.tweens, 1, -1 do
		local tween = self.tweens[i]

		-- If it's currently not stopped, continue
		if not tween:_isStopped() then
			local done = tween:_internalUpdate(dt)

			if done then
				local next = tween:_getNext()

				if next then
					self.tweens[i] = next
					next:_loadVariables(tween:_getNextVariables())
					self:_check(next, false)
				else
					table.remove(self.tweens, i)
				end
			end
		else
			table.remove(self.tweens, i)
		end
	end
end

local ntt = {
	_VERSION = "1.0.0",
	_AUTHOR = "Miku AuahDark",
	_LICENSE = "MIT"
}

---Create new tween group.
function ntt.group()
	return setmetatable({
		tweens = {}
	}, Group)
end

local default = ntt.group()

---Create new tween associated to the default tween group.
---@param state table
---@param duration number
---@param variables table
---@return ntt.Tween
---@diagnostic disable-next-line: duplicate-set-field
function ntt.to(state, duration, variables)
end

---Create new tween associated to the specified tween group.
---@param group ntt.Group
---@param state table
---@param duration number
---@param variables table
---@diagnostic disable-next-line: duplicate-set-field
function ntt.to(group, state, duration, variables)
	if group == ntt then
		group = default
	elseif variables == nil then
		---@diagnostic disable-next-line: cast-local-type
		state, duration, variables = group, state, duration
		group = default
	end

	---@cast duration number
	return group:to(state, duration, variables)
end

---Update the default tween group.
---@param dt number
---@diagnostic disable-next-line: duplicate-set-field
function ntt.update(dt)
end

---Update the specified tween group.
---@param group ntt.Group
---@param dt number
---@diagnostic disable-next-line: duplicate-set-field
function ntt.update(group, dt)
	if group == ntt then
		group = default
	elseif dt == nil then
		---@diagnostic disable-next-line: cast-local-type
		dt, group = group, default
	end

	---@cast dt number
	return group:update(dt)
end

---Retrieve the current tween group object.
function ntt.default()
	return default
end

return ntt

--[[
Changelog:

v1.0.0: 2022-10-17
> Initial release.
]]
