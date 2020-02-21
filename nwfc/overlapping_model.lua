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

local path = (...):gsub("%.overlapping_model$","")

local love = require("love")
local Luaoop = require(path..".Luaoop")
local util = require(path..".util")
local Model = require(path..".model")

local OverlappingModel = Luaoop.class("NWFC.OverlappingModel", Model)

local function rotatePattern(p, N)
	local result = {}
	for i = 0, #p - 1 do
		local x = i % N
		local y = math.floor(i / N)
		result[i + 1] = assert(p[x * N + N - y])
	end
	return result
end

local function reflectPattern(p, N)
	local result = {}
	for i = 0, #p - 1 do
		local x = i % N
		local y = math.floor(i / N)
		result[i + 1] = assert(p[y * N + N - x])
	end
	return result
end

local function agrees(N, p1, p2, dx, dy)
	local xmin = math.max(dx, 0)
	local xmax = dx < 0 and dx + N or N
	local ymin = math.max(dy, 0)
	local ymax = dy < 0 and dy + N or N

	for y = ymin, ymax - 1 do
		for x = xmin, xmax - 1 do
			if p1[y * N + x + 1] ~= p2[(y - dy) * N + x - dx + 1] then
				return false
			end
		end
	end

	return true
end

function OverlappingModel:__construct(image, N, width, height, periodicInput, periodicOutput, symmetry, ground)
	Model.__construct(self, self, width, height)

	self.N = N
	self.periodic = periodicOutput

	local SMX, SMY = image:getDimensions()
	local sample = {}
	self.colors = {}

	image:mapPixel(function(x, y, r, g, b, a)
		local color = util.colorToNumber(love.math.colorToBytes(r, g, b, a))
		local found = 0

		for i, v in ipairs(self.colors) do
			if v == color then
				found = i
				break
			end
		end

		if found == 0 then
			found = #self.colors + 1
			self.colors[found] = color
		end

		sample[y * SMX + x + 1] = found
		return r, g, b, a
	end)

	local W = (#self.colors) ^ (N * N)
	local weights = {}
	local ordering = {}

	for y = 0, (periodicInput and SMY or (SMY - N + 1)) - 1 do
		for x = 0, (periodicInput and SMX or (SMX - N + 1)) - 1 do
			local ps = {}
			local psb = {}
			for i = 0, N * N - 1 do
				local dx = i % N
				local dy = math.floor(i / N)
				psb[i + 1] = sample[((y + dy) % SMY) * SMX + (x + dx) % SMX + 1]
			end

			ps[1] = psb
			ps[2] = reflectPattern(ps[1], N)
			ps[3] = rotatePattern(ps[1], N)
			ps[4] = reflectPattern(ps[3], N)
			ps[5] = rotatePattern(ps[3], N)
			ps[6] = reflectPattern(ps[5], N)
			ps[7] = rotatePattern(ps[5], N)
			ps[8] = reflectPattern(ps[7], N)

			for k = 1, symmetry do
				local ind = 0
				local power = 1

				for i = #ps[k], 1, -1 do
					ind = ind + (ps[k][i] - 1) * power
					power = power * #self.colors
				end

				if weights[ind] then
					weights[ind] = weights[ind] + 1
				else
					weights[ind] = 1
					ordering[#ordering + 1] = ind
				end
			end
		end
	end

	self.T = #ordering
	self.ground = (ground + self.T) % self.T
	self.patterns = {}

	for i, v in ipairs(ordering) do
		local residue = v
		local power = W
		local result = {}

		for j = 1, N * N do
			power = math.floor(power / #self.colors)
			local count = 0
			while residue >= power do
				residue = residue - power
				count = count + 1
			end

			result[j] = count % 255
		end

		self.patterns[i] = result
		self.weights[i] = weights[v]
	end

	for d = 1, 4 do
		local prop = {}
		self.propagator[d] = prop

		for t = 1, self.T do
			local list = {}

			for t2 = 1, self.T do
				if agrees(N, self.patterns[t], self.patterns[t2], Model.DX[d], Model.DY[d]) then
					list[#list + 1] = t2 - 1
				end
			end

			prop[t] = list
		end
	end
end

function OverlappingModel:isOnBoundary(x, y)
	-- !periodic && (x + N > FMX || y + N > FMY || x < 0 || y < 0)
	return not(self.periodic) and (x + self.N > self.FMX or y + self.N > self.FMY or x < 0 or y < 0)
end

function OverlappingModel:toImageData(image)
	image = image or love.image.newImageData(self.FMX, self.FMY)
	assert(image:getWidth() == self.FMX and image:getHeight() == self.FMY, "invalid image size")

	if not(self.imageDataFuncObserved) then
		self.imageDataFuncObserved = function(x, y)
			local dy = y < self.FMY - self.N + 1 and 0 or self.N - 1
			local dx = x < self.FMX - self.N + 1 and 0 or self.N - 1

			local c = self.colors[self.patterns[self.observed[(y - dy) * self.FMX + x - dx + 1]][dy * self.N + dx + 1] + 1]
			return love.math.colorFromBytes(util.colorFromNumber(c))
		end
	end

	if not(self.imageDataFunc) then
		self.imageDataFunc = function(x, y)
			local contrib = 0
			local r, g, b = 0, 0, 0

			for di = 0, self.N * self.N - 1 do
				local dx = di % self.N
				local dy = math.floor(di / self.N)
				local sx = (x - dx) % self.FMX
				local sy = (y - dy) % self.FMY
				local s = sy * self.FMX + sx

				if self:isOnBoundary(sx, sy) == false then
					for t = 1, self.T do
						if self.wave[s + 1][t] then
							contrib = contrib + 1
							local c = assert(self.colors[self.patterns[t][dy * self.N + dx + 1] + 1])
							local ar, ag, ab = love.math.colorFromBytes(util.colorFromNumber(c))
							r = r + ar
							g = g + ag
							b = b + ab
						end
					end
				end
			end

			--print(r, g, b, contrib)
			return r / contrib, g / contrib, b / contrib, 1
		end
	end

	image:mapPixel(self.observed and self.imageDataFuncObserved or self.imageDataFunc)
	return image
end

function OverlappingModel:clear()
	Model.clear(self)

	--print("ground", self.ground, self.T)
	if self.ground ~= 0 then
		for x = 0, self.FMX - 1 do
			for t = 0, self.T - 1 do
				if t ~= self.ground then
					self:_ban(x + (self.FMY - 1) * self.FMX, t)
				end
			end

			for y = 0, self.FMY - 2 do
				self:_ban(x + y * self.FMX, self.ground)
			end
		end

		self:_propagate()
	end
end

return OverlappingModel
