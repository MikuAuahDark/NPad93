-- NPad's 9-patch Slicing Library
--
-- Copyright (c) 2024 Miku AuahDark
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
local n9p = {}

local applyTransform

if love.getVersion() >= 12 then
	applyTransform = love.graphics.applyTransform
else
	function applyTransform(x, y, a, sx, sy, ox, oy, kx, ky)
		return love.graphics.applyTransform(love.math.newTransform(x, y, a, sx, sy, ox, oy, kx, ky))
	end
end

---@alias n9p.QuadDrawMode
--- Draw it as-is (don't scale; don't tile).
---| "keep"
--- Scale to fit.
---| "stretch"
--- Tile to fit (don't scale).
---| "repeat"

---@class (exact) n9p.Instance
---@field private hmeasure {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@field private vmeasure {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@field private padding {[1]:integer,[2]:integer,[3]:integer,[4]:integer} order is left top right bottom
---@field private quads love.Quad[]
---@field private repeatQuad love.Quad
---@field private texture love.Texture?
---@field private minW integer
---@field private minH integer
local Instance = {}
Instance.__index = Instance ---@diagnostic disable-line: inject-field

---@param horizontals {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@param verticals {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@param quads love.Quad[]
---@param padding {[1]:integer,[2]:integer,[3]:integer,[4]:integer}
local function makeInstance(horizontals, verticals, quads, padding)
	local dimensions = {0, 0}

	for i, regions in ipairs({horizontals, verticals}) do
		for _, v in ipairs(horizontals) do
			if v[1] == "keep" then
				dimensions[i] = dimensions[i] + v[2]
			end
		end
	end

	local sw, sh = quads[1]:getTextureDimensions()
	return setmetatable({
		hmeasure = horizontals,
		vmeasure = verticals,
		quads = quads,
		padding = padding,
		repeatQuad = love.graphics.newQuad(0, 0, 1, 1, sw, sh),
		minW = dimensions[1],
		minH = dimensions[2],
	}, Instance)
end

---Retrieve how many rectangle segments used to construct this 9-patch instance.
---@return integer,integer @How many rectangles, on horizontal and vertical axis respectively.
function Instance:getRectangleSegments()
	return #self.hmeasure, #self.vmeasure
end

---Retrieve the quad and the quad drawing option for each axis.
---@param x integer X position for the rectangle segment (starting from 0).
---@param y integer Y position for the rectangle segment (starting from 0).
---@return love.Quad @The quad used to draw subsection of the texture. Do not modify the quad!
---@return n9p.QuadDrawMode @What should be done with the horizontal axis of the quad?
---@return n9p.QuadDrawMode @What should be done with the vertical axis of the quad?
function Instance:getQuadInfo(x, y)
	assert(x >= 0 and x < #self.hmeasure, "invalid X position")
	assert(y >= 0 and x < #self.vmeasure, "invalid Y position")
	return self.quads[y * #self.hmeasure + x + 1], self.hmeasure[x + 1][1], self.vmeasure[y + 1][1]
end

---Retrieve minimum dimensions that this stretchable image can be drawn.
function Instance:getMinDimensions()
	return self.minW, self.minH
end

---Retrieve the content area of the stretchable image.
---@param width number Desired width of the whole stretchable image.
---@param height number Desired height of the whole stretchable image.
---@return integer,integer,number,number @x, y, w, h of the content area.
function Instance:getContentArea(width, height)
	local w = width - self.padding[1] - self.padding[3]
	local h = height - self.padding[2] - self.padding[4]
	return self.padding[1], self.padding[2], w, h
end

---Get texture used to draw the stretchable image.
---@return love.Texture?
function Instance:getTexture()
	return self.texture
end

---Set the texture that will be used to draw the stretchable image.
---@param texture love.Texture?
function Instance:setTexture(texture)
	self.texture = texture
end

---Draw the stretchable image.
---@param width number Width of the stretchable image.
---@param height number Height of the stretchable image.
---@param transform love.Transform Transformation stack to apply.
---@diagnostic disable-next-line: duplicate-set-field
function Instance:draw(width, height, transform) end

---Draw the stretchable image.
---@param x number
---@param y number
---@param width number Width of the stretchable image.
---@param height number Height of the stretchable image.
---@param angle number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@diagnostic disable-next-line: duplicate-set-field
function Instance:draw(x, y, width, height, angle, sx, sy, ox, oy, kx, ky)
	if self.texture then
		love.graphics.push()

		-- Apply transformation stack
		if type(width) == "userdata" and type(width.typeOf) == "function" and width:typeOf("Transform") then
			applyTransform(width)
		else
			applyTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
		end
		self:_drawInternal()

		love.graphics.pop()
	end
end

---Draw the stretchable using the specified constraint as the information.
---@param constraint {get:fun(...):(number,number,number,number)}
---@param angle number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
function Instance:drawConstraint(constraint, angle, sx, sy, ox, oy, kx, ky)
	local x, y, width, height = constraint:get()
	return self:draw(x, y, width, height, angle, sx, sy, ox, oy, kx, ky)
end

---@private
function Instance:_drawInternal()
	assert(self.texture)


end

---@class (exact) n9p.Builder
---@field private hregion {[1]:integer,[2]:integer,[3]:boolean}[]
---@field private vregion {[1]:integer,[2]:integer,[3]:boolean}[]
---@field private padding {[1]:integer,[2]:integer,[3]:integer,[4]:integer}
local Builder = {}
Builder.__index = Builder ---@diagnostic disable-line: inject-field

local function makeBuilder()
	return setmetatable({
		hregion = {},
		vregion = {},
		padding = {0, 0, math.huge, math.huge}
	}, Builder)
end

---Add stretchable/repeatable region on horizontal axis.
---@param startX integer Start X position of the slice, inclusive.
---@param endX integer End X position of the slice, **inclusive**.
---@param wrap boolean? Should the slice be stretched or repeated?
function Builder:addHorizontalSlice(startX, endX, wrap)
	assert(startX >= 0, "invalid X position")
	assert(endX >= startX, "invalid X interval")
	self.hregion[#self.hregion+1] = {startX, endX, not not wrap}
	return self:_cleanupIntersectingRegion(self.hregion)
end

---Add stretchable/repeatable region on vertical axis.
---@param startY integer Start Y position of the slice, inclusive.
---@param endY integer End Y position of the slice, **inclusive**.
---@param wrap boolean?
function Builder:addVerticalSlice(startY, endY, wrap)
	assert(startY >= 0, "invalid Y position")
	assert(endY >= startY, "invalid Y interval")
	self.hregion[#self.hregion+1] = {startY, endY, not not wrap}
	return self:_cleanupIntersectingRegion(self.vregion)
end

---@param rega {[1]:integer,[2]:integer,[3]:boolean}
---@param regb {[1]:integer,[2]:integer,[3]:boolean}
local function sortRegion(rega, regb)
	return rega[1] < regb[1]
end

---@param reg {[1]:integer,[2]:integer,[3]:boolean}
---@param point integer
local function isValueInRegion(reg, point)
	return point >= reg[1] and point <= reg[2]
end

---@param rega {[1]:integer,[2]:integer,[3]:boolean} larger region
---@param regb {[1]:integer,[2]:integer,[3]:boolean} smaller region
local function isRegionIntersectOrInOther(rega, regb)
	return isValueInRegion(rega, regb[1]) or isValueInRegion(rega, regb[2])
end

---@param rega {[1]:integer,[2]:integer,[3]:boolean}
---@param regb {[1]:integer,[2]:integer,[3]:boolean}
local function isRegionOverlap(rega, regb)
	return isRegionIntersectOrInOther(rega, regb) or isRegionIntersectOrInOther(regb, rega)
end

---@param reg {[1]:integer,[2]:integer,[3]:boolean}[]
---@private
function Builder:_cleanupIntersectingRegion(reg)
	table.sort(reg, sortRegion)

	local i = 1
	while #reg > 1 do
		local regA = reg[i]
		local regB = reg[i + 1]
		if not (regA and regB) then
			break
		end

		-- Is both region overlap?
		if isRegionOverlap(regA, regB) then
			assert(regA[3] == regB[3], "inconsistent slice drawing type")
			-- merge
			regA[1] = math.min(regA[1], regB[1])
			regA[2] = math.max(regA[2], regB[2])
			table.remove(reg, i + 1)
		else
			-- increment
			i = i + 1
		end
	end

	return self
end

---@param startX integer Start X position of the content area, inclusive.
---@param endX integer End X position of the content area, **inclusive**.
function Builder:setHorizontalPadding(startX, endX)
	assert(startX >= 0, "invalid starting X position")
	assert(endX >= startX, "invalid X interval")
	self.padding[1], self.padding[3] = startX, endX
	return self
end

---@param startY integer Start Y position of the content area, inclusive.
---@param endY integer End Y position of the content area, **inclusive**.
function Builder:setVerticalPadding(startY, endY)
	assert(startY >= 0, "invalid starting Y position")
	assert(endY >= startY, "invalid Y interval")
	self.padding[2], self.padding[4] = startY, endY
	return self
end

function Builder:build()
	
end

function n9p.newBuilder()
	return makeBuilder()
end

return n9p
