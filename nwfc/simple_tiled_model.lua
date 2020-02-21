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

local path = (...):gsub("%.simple_tiled_model$","")

local love = require("love")
local Luaoop = require(path..".Luaoop")
local util = require(path..".util")
local Model = require(path..".model")

local SimpleTiledModel = Luaoop.class("NWFC.SimpleTiledModel", Model)

local symmetryTable = {
	L = {
		cardinality = 4,
		a = function(i) return (i + 1) % 4 end,
		b = function(i) return (i % 2 == 0) and (i + 1) or (i - 1) end
	},
	T = {
		cardinality = 4,
		a = function(i) return (i + 1) % 4 end,
		b = function(i) return (i % 2 == 0) and i or (4 - i) end
	},
	I = {
		cardinality = 2,
		a = function(i) return 1 - i end,
		b = function(i) return i end
	},
	["\\"] = {
		cardinality = 2,
		a = function(i) return 1 - i end,
		b = function(i) return 1 - i end
	},
	X = {
		cardinality = 1,
		a = function(i) return i end,
		b = function(i) return i end
	}
}

function SimpleTiledModel:__construct(data, subsetName, width, height, periodic, black)
	Model.__construct(self, self, width, height)

	-- Data structure:
	--[[
	data = {
		size = tile_size or 16,
		unique = false or true,
		tileImage = {
			[tilename] = love.image.newImageData("path to file"),
			...
		}
		tiles = {
			{
				name = tile_name,
				symmetry = symmetry or "X",
				weight = weight or 1.0
			}
		},
		neighbors = {
			{left, right},
			{left, right},
			...
			{left, right}
		},
		subsets = {
			[name] = {
				"tile1", "tile2", ...
			}
		}
	}
	]]

	self.periodic = not(not(periodic))
	self.black = not(not(black))
	self.tilesize = data.size or 16

	local unique = not(not(data.unique))
	local subset = nil

	if subsetName ~= nil then
		subset = assert(data.subsets[subsetName], "subset not found")
	end

	local function tile(f)
		local result = {}
		for i = 1, self.tilesize * self.tilesize do
			result[i] = f((i - 1) % self.tilesize, (i - 1) / self.tilesize)
		end
		return result
	end

	local function rotate(a)
		return tile(function(x, y)
			return a[self.tilesize - y + x * self.tilesize]
		end)
	end

	self.tiles = {}
	self.tilenames = {}

	local action = {}
	local firstOccurrence = {}

	for _, tileObject in ipairs(data.tiles) do
		local tilename = tileObject.name

		if subset == nil or util.contains(subset, tilename) then
			local sym = symmetryTable[tileObject.symmetry or "X"] or symmetryTable.X;

			self.T = #action
			firstOccurrence[tilename] = self.T

			for t = 0, sym.cardinality - 1 do
				local mapt = {}

				mapt[1] = t
				mapt[2] = sym.a(t)
				mapt[3] = sym.a(mapt[2])
				mapt[4] = sym.a(mapt[3])
				mapt[5] = sym.b(t)
				mapt[6] = sym.b(mapt[2])
				mapt[7] = sym.b(mapt[3])
				mapt[8] = sym.b(mapt[4])

				for s = 1, 8 do
					mapt[s] = mapt[s] + self.T
				end

				action[#action + 1] = mapt
			end

			if unique then
				for t = 0, sym.cardinality - 1 do
					local target = tilename.." "..t
					local imageData = assert(data.tileImage[target], "missing tileimage")

					self.tiles[#self.tiles + 1] = tile(function(x, y)
						return util.colorToNumber(love.math.colorToBytes(imageData:getPixel(x, y)))
					end)
					self.tilenames[#self.tilenames + 1] = target
				end
			else
				local imageData = assert(data.tileImage[tilename], "missing tileimage")

				self.tiles[#self.tiles + 1] = tile(function(x, y)
					return util.colorToNumber(love.math.colorToBytes(imageData:getPixel(x, y)))
				end)
				self.tilenames[#self.tilenames + 1] = tilename.." 0"

				for t = 1, sym.cardinality - 1 do
					self.tiles[#self.tiles + 1] = rotate(self.tiles[self.T + t])
					self.tilenames[#self.tilenames + 1] = tilename.." "..t
				end
			end

			for _ = 1, sym.cardinality do
				self.weights[#self.weights + 1] = tonumber(tileObject.weight) or 1
			end
		end
	end

	self.T = #action
	local tempPropagator = {}

	for d = 1, 4 do
		tempPropagator[d] = {}
		self.propagator[d] = {}

		for t = 1, self.T do
			tempPropagator[d][t] = {}
			self.propagator[d][t] = {}
			for u = 1, self.T do
				tempPropagator[d][t][u] = false
			end
		end
	end

	for _, neighbor in ipairs(data.neighbors) do
		local left = util.splitString(neighbor.left, " ")
		local right = util.splitString(neighbor.right, " ")

		if subset == nil or (util.contains(subset, left[1]) and util.contains(subset, right[1])) then
			local L = action[firstOccurrence[left[1]] + 1][#left == 1 and 1 or (left[2] + 1)]
			local D = action[L + 1][2]
			local R = action[firstOccurrence[right[1]] + 1][#right == 1 and 1 or (right[2] + 1)]
			local U = action[R + 1][2]

			tempPropagator[1][R + 1][L + 1] = true
			tempPropagator[1][action[R + 1][7] + 1][action[L + 1][7] + 1] = true
			tempPropagator[1][action[L + 1][5] + 1][action[R + 1][5] + 1] = true
			tempPropagator[1][action[L + 1][3] + 1][action[R + 1][3] + 1] = true
			tempPropagator[2][U + 1][D + 1] = true
			tempPropagator[2][action[D + 1][7] + 1][action[U + 1][7] + 1] = true
			tempPropagator[2][action[U + 1][5] + 1][action[D + 1][5] + 1] = true
			tempPropagator[2][action[D + 1][3] + 1][action[U + 1][3] + 1] = true
		end
	end

	for t = 0, self.T * self.T - 1 do
		local t2 = math.floor(t / self.T) + 1
		local t1 = t % self.T + 1
		tempPropagator[3][t2][t1] = tempPropagator[1][t1][t2]
		tempPropagator[4][t2][t1] = tempPropagator[2][t1][t2]
	end

	local sparsePropagator = {}
	for d = 1, 4 do
		local sp = {}
		for i = 1, self.T do
			sp[i] = {}
		end
		sparsePropagator[d] = sp
	end

	for d = 1, 4 do
		for t1 = 1, self.T do
			local sp = sparsePropagator[d][t1]
			local tp = tempPropagator[d][t1]

			for t2 = 1, self.T do
				if tp[t2] then
					sp[#sp + 1] = t2 - 1
				end
			end

			local stt = {}
			for i = 1, #sp do
				stt[i] = 0
			end

			self.propagator[d][t1] = stt
			for st = 1, #sp do
				stt[st] = sp[st]
			end
		end
	end
end

function SimpleTiledModel:isOnBoundary(x, y)
	return not(self.periodic) and (x < 0 or y < 0 or x >= self.FMX or y >= self.FMY)
end

function SimpleTiledModel:toImageData(image)
	image = image or love.image.newImageData(self.FMX * self.tilesize, self.FMY * self.tilesize)
	assert(
		image:getWidth() == self.FMX * self.tilesize and
		image:getHeight() == self.FMY * self.tilesize,
		"invalid image size"
	)

	if not(self.imageDataFuncObserved) then
		self.imageDataFuncObserved = function(x, y)
			local px = math.floor(x / self.tilesize)
			local py = math.floor(y / self.tilesize)
			local tile = self.tiles[self.observed[px + py * self.FMX + 1]]
			local tx = x % self.tilesize
			local ty = y % self.tilesize
			return love.math.colorFromBytes(util.colorFromNumber(tile[ty * self.tilesize + tx + 1]))
		end
	end

	if not(self.observed) then
		error("TODO non-observed")
	end

	image:mapPixel(self.observed and self.imageDataFuncObserved or self.imageDataFunc)
	return image
end

return SimpleTiledModel
