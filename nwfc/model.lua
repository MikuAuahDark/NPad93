--[[---------------------------------------------------------------------------
-- Copyright (c) 2020 Miku AuahDark
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
--]]---------------------------------------------------------------------------

local path = (...):gsub("%.model$","")
local Luaoop = require(path..".Luaoop")
local util = require(path..".util")

local Model = Luaoop.class("NWFC.Model")

Model.DX = {-1, 0, 1, 0}
Model.DY = {0, 1, 0, -1}
Model.opposite = {2, 3, 0, 1}

function Model:__construct(base, width, height)
	assert(self == base, "attempt to construct abstract class 'NWFC.Model'")

	self.wave = nil

	self.propagator = {}
	self.compatible = {}
	self.observed = nil -- 1-based indexing value

	self.stack = {}
	self.stacksize = 0

	self.random = math.random
	self.FMX = width
	self.FMY = height
	self.T = 0
	self.periodic = false

	self.weights = {}
	self.weightLogWeights = {}

	self.sumsOfOnes = {}
	self.sumOfWeights = 0
	self.sumOfWeightLogWeights = 0
	self.startingEntropy = 0
	self.sumsOfWeights = {}
	self.sumsOfWeightLogWeights = {}
	self.entropies = {}
end

function Model:_init()
	local waveLen = self.FMX * self.FMY
	self.wave = {}

	for i = 1, waveLen do
		local t = {}
		local compat = {}
		for j = 1, self.T do
			t[j] = false
			compat[j] = {0, 0, 0, 0}
		end

		self.compatible[i] = compat
		self.wave[i] = t
		self.sumsOfOnes[i] = 0
		self.sumsOfWeights[i] = 0
		self.sumsOfWeightLogWeights[i] = 0
		self.entropies[i] = 0
	end

	for i = 1, self.T do
		self.weightLogWeights[i] = self.weights[i] * math.log(self.weights[i])
		self.sumOfWeights = self.sumOfWeights + self.weights[i]
		self.sumOfWeightLogWeights = self.sumOfWeightLogWeights + self.weightLogWeights[i]
	end

	self.startingEntropy = math.log(self.sumOfWeights) - self.sumOfWeightLogWeights / self.sumOfWeights

	for i = 1, waveLen * self.T do
		self.stack[i] = {0, 0}
	end
end

function Model:_observe()
	--print("OBSERVE")
	local min = 1e3
	local argmin = -1

	for i = 1, #self.wave do
		if self:isOnBoundary((i - 1) % self.FMX, math.floor((i - 1) / self.FMX)) == false then
			local amount = self.sumsOfOnes[i]
			if amount == 0 then
				return false
			end

			local entropy = self.entropies[i]
			if amount > 1 and entropy <= min then
				local noise = 1e-6 * self.random()

				if entropy + noise < min then
					min = entropy + noise
					argmin = i
				end
			end
		end
	end

	if argmin == -1 then
		self.observed = {}

		for i = 1, #self.wave do
			self.observed[i] = 0
		end

		for i = 1, #self.wave do
			for t = 1, self.T do
				if self.wave[i][t] then
					self.observed[i] = t
					break
				end
			end
		end

		return true
	end

	local distribution = {}
	for i = 1, self.T do
		distribution[i] = self.wave[argmin][i] and self.weights[i] or 0
	end

	local r = util.random(distribution, self.random()) + 1

	local w = self.wave[argmin]
	for t = 1, self.T do
		if w[t] ~= (t == r) then
			self:_ban(argmin - 1, t - 1)
		end
	end

	return nil
end

function Model:_propagate()
	--print("PROPAGATE")
	while self.stacksize > 0 do
		local e1 = self.stack[self.stacksize]
		local e11, e12 = e1[1], e1[2]
		self.stacksize = self.stacksize - 1

		local i1 = e11
		local x1 = i1 % self.FMX
		local y1 = math.floor(i1 / self.FMX)

		for d = 1, 4 do
			local dx = Model.DX[d]
			local dy = Model.DY[d]
			local x2 = x1 + dx
			local y2 = y1 + dy

			if self:isOnBoundary(x2, y2) == false then
				x2 = x2 % self.FMX
				y2 = y2 % self.FMY

				local i2 = x2 + y2 * self.FMX
				local p = self.propagator[d][e12 + 1]
				local compat = self.compatible[i2 + 1]

				for l = 1, #p do
					local t2 = p[l]
					local comp = compat[t2 + 1]

					comp[d] = comp[d] - 1
					if comp[d] == 0 then
						self:_ban(i2, t2)
					end
				end
			end
		end
	end
end

function Model:_ban(i, t)
	--print("banned", i, t)
	self.wave[i + 1][t + 1] = false

	local comp = self.compatible[i + 1][t + 1]
	for d = 1, 4 do
		comp[d] = 0
	end

	self.stacksize = self.stacksize + 1
	if self.stack[self.stacksize] then
		local p = self.stack[self.stacksize]
		p[1], p[2] = i, t
	else
		self.stack[self.stacksize] = {i, t}
	end

	self.sumsOfOnes[i + 1] = self.sumsOfOnes[i + 1] - 1
	self.sumsOfWeights[i + 1] = self.sumsOfWeights[i + 1] - self.weights[t + 1]
	self.sumsOfWeightLogWeights[i + 1] = self.sumsOfWeightLogWeights[i + 1] - self.weightLogWeights[t + 1]

	local sum = self.sumsOfWeights[i + 1]
	self.entropies[i + 1] = math.log(sum) - self.sumsOfWeightLogWeights[i + 1] / sum
end

function Model:clear()
	for i = 1, #self.wave do
		for t = 1, self.T do
			self.wave[i][t] = true
			for d = 1, 4 do
				self.compatible[i][t][d] = #self.propagator[Model.opposite[d] + 1][t]
			end
		end

		self.sumsOfOnes[i] = #self.weights
		self.sumsOfWeights[i] = self.sumOfWeights
		self.sumsOfWeightLogWeights[i] = self.sumOfWeightLogWeights
		self.entropies[i] = self.startingEntropy
	end
end

function Model:run(rng, limit, step)
	self.random = rng or math.random
	limit = limit or math.huge

	if self.wave == nil then
		self:_init()

		if step then
			self:clear()
		end
	end

	if not(step) then
		self:clear()
	end

	for _ = 1, limit do
		local result = self:_observe()
		if result ~= nil then
			return result
		end

		self:_propagate()
	end

	return not(step)
end

function Model:isOnBoundary(x, y)
	error("attempt to call pure virtual method 'isOnBoundary'", 2)
	return false or true
end

function Model:toImageData(imageData)
	error("attempt to call pure virtual method 'toImageData'", 2)
	return imageData
end

return Model
