-- NPad's Layouting Library, based on ConstraintLayout
--
-- Copyright (c) 2023 Miku AuahDark
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

---@class NLay.Cache
---@field package x number?
---@field package y number?
---@field package w number?
---@field package h number?
---@field package referenced (NLay.BaseConstraint?)[]
---@field package refLength integer

---@class NLay.BaseConstraint
---@field package cache table<NLay.BaseConstraint, NLay.Cache?>
local BaseConstraint = {
	cache = setmetatable({}, {__mode = "k"})
}

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number
---@param offy? number
---@return number,number,number,number
function BaseConstraint:get(offx, offy)
---@diagnostic disable-next-line: missing-return
end

---@class NLay.Constraint: NLay.BaseConstraint
---@field package top NLay.BaseConstraint
---@field package left NLay.BaseConstraint
---@field package bottom NLay.BaseConstraint
---@field package right NLay.BaseConstraint
---@field package inTop boolean
---@field package inLeft boolean
---@field package inBottom boolean
---@field package inRight boolean
---@field package marginX number
---@field package marginY number
---@field package marginW number
---@field package marginH number
---@field private w number
---@field private h number
---@field private biasHorz number
---@field private biasVert number
---@field package inside NLay.Inside
---@field private forceIntoFlags boolean
---@field private userTag any
---@field private aspectRatio number
local Constraint = {}
Constraint.__index = Constraint

---@param constraint NLay.Constraint
---@param target NLay.BaseConstraint
---@return number,number,number,number
local function resolveConstraintSize(constraint, target)
	if target == constraint.inside.obj then
		return constraint.inside:_get()
	else
		return target:get()
	end
end

local function mix(a, b, t)
	return (1 - t) * a + t * b
end

---@param self NLay.Constraint
local function resolveWidthSize0(self)
	local x, width

	if self.left == nil or self.right == nil then
		error("insufficient constraint for width 0")
	end

	-- Left
	local e1x, _, e1w = resolveConstraintSize(self, self.left)
	if self.inLeft then
		x = e1x + self.marginX
	else
		x = e1x + e1w + self.marginX
	end

	-- Right
	local e2x, _, e2w = resolveConstraintSize(self, self.right)
	if self.inRight then
		width = e2x + e2w - x - self.marginW
	else
		width = e2x - x - self.marginW
	end

	return x, width
end

---@param self NLay.Constraint
local function resolveHeightSize0(self)
	local y, height

	if self.bottom == nil or self.top == nil then
		error("insufficient constraint for height 0")
	end

	local e1y, _, e1h = select(2, resolveConstraintSize(self, self.top))

	if self.inTop then
		y = e1y + self.marginY
	else
		y = e1y + e1h + self.marginY
	end

	local e2y, _, e2h = select(2, resolveConstraintSize(self, self.bottom))

	if self.inBottom then
		height = e2y + e2h - y - self.marginH
	else
		height = e2y - y - self.marginH
	end

	return y, height
end

local function isPercentMode(str, name)
	if str == "percent" then
		return true
	elseif str == "pixel" then
		return false
	else
		error("invalid \""..name.."\" size mode (\"absolute\" or \"relative\" expected)", 2)
	end
end

---@param constraint NLay.BaseConstraint
local function getCachedData(constraint)
	local c = BaseConstraint.cache[constraint]
	if not c then
		return nil, nil, nil, nil
	end

	return c.x, c.y, c.w, c.h
end

---@param constraint NLay.BaseConstraint
local function getCacheEntry(constraint)
	local c = BaseConstraint.cache[constraint]
	if not c then
		c = {
			referenced = setmetatable({}, {__mode = "v"}),
			refLength = 0
		}
		BaseConstraint.cache[constraint] = c
	end

	return c
end

---@param constraint NLay.BaseConstraint
---@param x number
---@param y number
---@param w number
---@param h number
local function insertCached(constraint, x, y, w, h)
	local c = getCacheEntry(constraint)
	c.x, c.y, c.w, c.h = x, y, w, h
end

---@param constraint NLay.BaseConstraint
local function invalidateCache(constraint)
	local c = getCacheEntry(constraint)

	-- Constraint that reference `constraint` must be invalidated too.
	if c.x and c.y and c.w and c.h then
		local newRefLen = 0

		for i = 1, c.refLength do
			local other = c.referenced[i]

			if other then
				newRefLen = i
				invalidateCache(other)
			end
		end

		c.refLength = newRefLen
		c.x, c.y, c.w, c.h = nil, nil, nil, nil
	end
end

---Constraint `constraint` reference `other` constraint.
---@param constraint NLay.BaseConstraint
---@param other NLay.BaseConstraint
local function addRefCache(constraint, other)
	local c = getCacheEntry(other)
	local targetIndex = 0

	for i = 1, c.refLength do
		local r = c.referenced[i]

		-- No duplicates
		if r == constraint then
			return
		elseif not r then
			targetIndex = i
		end
	end

	if targetIndex == 0 then
		c.refLength = c.refLength + 1
		targetIndex = c.refLength
	end

	c.referenced[targetIndex] = constraint
end

---@generic T
---@param ... T
---@return T
local function selectDefault(...)
	local value

	for i = 1, select("#", ...) do
		local v = select(i, ...)

		if v ~= nil then
			value = v
			break
		end
	end

	return value
end

---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
function Constraint:get(offx, offy)
	local finalX, finalY, finalW, finalH = getCachedData(self)

	if not (finalX and finalY and finalW and finalH) then
		if (self.left ~= nil or self.right ~= nil) and (self.top ~= nil or self.bottom ~= nil) then
			local x, y, w, h
			local width, height = self.w, self.h
			local zerodim = false

			-- Convert percent values to pixel values
			if self.relW then
				width = select(2, resolveWidthSize0(self)) * self.w
			end

			if self.relH then
				height = select(2, resolveHeightSize0(self)) * self.h
			end

			-- Resolve aspect ratio part 1
			if self.aspectRatio ~= 0 then
				if width == 0 and height ~= 0 then
					width = height * self.aspectRatio
				elseif width ~= 0 and height == 0 then
					height = width / self.aspectRatio
				else
					zerodim = width == 0 and height == 0
				end
			end

			if zerodim then
				local resolvedWidth, resolvedHeight

				if self.left and self.right then
					resolvedWidth = select(2, resolveWidthSize0(self))
				end

				if self.top and self.bottom then
					resolvedHeight = select(2, resolveHeightSize0(self))
				end

				if resolvedWidth or resolvedHeight then
					if resolvedWidth and resolvedHeight then
						if resolvedWidth/resolvedHeight > self.aspectRatio then
							-- h / ratio, h
							height = resolvedHeight

							if self.aspectRatio > 1 then
								width = resolvedHeight * self.aspectRatio
							else
								width = resolvedHeight / self.aspectRatio
							end
						else
							width = resolvedWidth

							if self.aspectRatio > 1 then
								height = resolvedWidth * self.aspectRatio
							else
								height = resolvedWidth / self.aspectRatio
							end
						end
					elseif resolvedWidth then
						width, height = resolvedWidth, resolvedWidth
					elseif resolvedHeight then
						width, height = resolvedHeight, resolvedHeight
					end
				end
			end

			if width == -1 then
				-- Match parent
				local px, _, pw, _ = self.inside:_get()
				x, width = px, pw
			elseif width == 0 then
				-- Match constraint
				x, width = resolveWidthSize0(self)
			end

			if height == -1 then
				-- Match parent
				local _, py, _, ph = self.inside:_get()
				y, h = py, ph
			elseif height == 0 then
				-- Match constraint
				y, height = resolveHeightSize0(self)
			end

			if self.aspectRatio ~= 0 and zerodim then
				local maxw, maxh = width, height
				local cw, ch = height * self.aspectRatio, width / self.aspectRatio
				if cw > maxw then
					height = ch
				elseif ch > maxh then
					width = cw
				end
			end

			do
				local l, r
				w = width

				if self.left then
					-- Left orientation
					local e1x, _, e1w = resolveConstraintSize(self, self.left)

					if self.inLeft then
						l = e1x + self.marginX
					else
						l = e1x + e1w + self.marginX
					end
				end

				if self.right then
					-- Right orientation
					local e2x, _, e2w = resolveConstraintSize(self, self.right)

					if self.inRight then
						r = e2x + e2w - self.marginW - w
					else
						r = e2x - self.marginW - w
					end
				end

				if l ~= nil and r ~= nil then
					-- Horizontally centered
					x = mix(l, r, self.biasHorz)
				else
					x = l or r
				end
			end

			do
				local t, b
				h = height

				if self.top then
					-- Top orientation
					local e1y, _, e1h = select(2, resolveConstraintSize(self, self.top))

					if self.inTop then
						t = e1y + self.marginY
					else
						t = e1y + e1h + self.marginY
					end
				end

				if self.bottom then
					-- Bottom orientation
					local e2y, _, e2h = select(2, resolveConstraintSize(self, self.bottom))

					if self.inBottom then
						b = e2y + e2h - self.marginH - h
					else
						b = e2y - self.marginH - h
					end
				end

				if t ~= nil and b ~= nil then
					-- Vertically centered
					y = mix(t, b, self.biasVert)
				else
					y = t or b
				end
			end

			assert(x and y and w and h, "fatal error please report!")
			finalX, finalY, finalW, finalH = x, y, math.max(w, 0), math.max(h, 0)
			insertCached(self, finalX, finalY, finalW, finalH)
		else
			error("insufficient constraint")
		end
	end

	return finalX + (offx or 0), finalY + (offy or 0), finalW, finalH
end

---@package
function Constraint:_overrideIntoFlags()
	self.inTop = self.inTop or self.inside.obj == self.top
	self.inLeft = self.inLeft or self.inside.obj == self.left
	self.inBottom = self.inBottom or self.inside.obj == self.bottom
	self.inRight = self.inRight or self.inside.obj == self.right

	if self.top == self.bottom and self.top ~= nil then
		self.inTop = true
		self.inBottom = true
	end

	if self.left == self.right and self.left ~= nil then
		self.inLeft = true
		self.inRight = true
	end
end

---This function tells that for constraint specified at {top,left,bottom,right}, it should NOT use the opposite sides
---of the constraint. This mainly used to prevent ambiguity.
---@param top boolean
---@param left boolean
---@param bottom boolean
---@param right boolean
---@return NLay.Constraint
function Constraint:into(top, left, bottom, right)
	self.inTop = not not top
	self.inLeft = not not left
	self.inBottom = not not bottom
	self.inRight = not not right

	if not self.forceIntoFlags then
		self:_overrideIntoFlags()
	end

	invalidateCache(self)
	return self
end

---Set the constraint margin
---@param margin number|number[] Either number to apply all margins or table {top, left, bottom, right} margin.
---Defaults to 0 for absent/nil values.
---@return NLay.Constraint
function Constraint:margin(margin)
	margin = margin or 0

	if type(margin) == "number" then
		self.marginX, self.marginY, self.marginW, self.marginH = margin, margin, margin, margin
	else
		self.marginX = margin[2] or 0
		self.marginY = margin[1] or 0
		self.marginW = margin[4] or 0
		self.marginH = margin[3] or 0
	end

	invalidateCache(self)
	return self
end

---Set the size of constraint. If width/height is 0, it will calculate it based on the other connected constraint.
---If it's -1, then it will use parent's width/height minus padding.
---
---"percent" width requires left and right constraint attached. "percent" height requires top and bottom constraint
---attached. Both defaults to "pixel" if not specified, which ensure older code works without modification.
---@param width number Constraint width.
---@param height number Constraint height.
---@param modeW? '"percent"' | '"pixel"'
---@param modeH? '"percent"' | '"pixel"'
---@return NLay.Constraint
function Constraint:size(width, height, modeW, modeH)
	assert(width >= 0 or width == -1, "invalid width")
	assert(height >= 0 or height == -1, "invalid height")
	self.w, self.h = width, height
	self.relW = isPercentMode(modeW or "pixel", "width")
	self.relH = isPercentMode(modeH or "pixel", "height")

	invalidateCache(self)
	return self
end

---Set the constraint bias. By default, for fixed width/height, the position are centered around (bias 0.5).
---@param horz number Horizontal bias, real value between 0..1 inclusive.
---@param vert number Vertical bias, real value between 0..1 inclusive.
---@param unclamped boolean Do not limit bias ratio?
---@return NLay.Constraint
function Constraint:bias(horz, vert, unclamped)
	if horz then
		if unclamped then
			self.biasHorz = horz
		else
			self.biasHorz = math.min(math.max(horz, 0), 1)
		end
	end

	if vert then
		if unclamped then
			self.biasVert = vert
		else
			self.biasVert = math.min(math.max(vert, 0), 1)
		end
	end

	invalidateCache(self)
	return self
end

---Force the "into" flags to be determined by user even if it may result as invalid constraint.
---This function is used for some "niche" cases. You don't have to use this almost all the time.
---@param force boolean
---@return NLay.Constraint
function Constraint:forceIn(force)
	self.forceIntoFlags = not not force
	invalidateCache(self)
	return self
end

---Tag this constraint with some userdata, like an id, for example.
---Useful to keep track of constraints when they're rebuilt.
---@param userdata any
---@return NLay.Constraint
function Constraint:tag(userdata)
	self.userTag = userdata
	return self
end

---@return any
function Constraint:getTag()
	return self.userTag
end

---Set the size aspect ratio. The `ratio` is in format `numerator/denominator`, so for aspect ratio
---of 16:9, pass `16/9`.
function Constraint:ratio(ratio)
	if ratio ~= ratio or math.abs(ratio) == math.huge then ratio = 0 end
	self.aspectRatio = ratio or 0
	invalidateCache(self)
	return self
end

---@class NLay.MaxConstraint: NLay.BaseConstraint
---@field private list NLay.BaseConstraint[]
local MaxConstraint = {}
MaxConstraint.__index = MaxConstraint

---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number
function MaxConstraint:get(offx, offy)
	local minx, miny, maxx, maxy = self.list[1]:get()
	maxx = maxx + minx
	maxy = maxy + miny

	for i = 2, #self.list do
		local x, y, w, h = self.list[i]:get()
		minx = math.min(minx, x)
		miny = math.min(miny, y)
		maxx = math.max(maxx, x + w)
		maxy = math.max(maxy, y + h)
	end

	return minx + (offx or 0), miny + (offy or 0), maxx - minx, maxy - miny
end

---@class NLay.LineConstraint: NLay.BaseConstraint
---@field private constraint NLay.BaseConstraint | NLay.Inside
---@field private direction '"horizontal"' | '"vertical"'
---@field private mode '"percent"' | '"pixel"'
---@field private lineOffset number
---@field private flip boolean
local LineConstraint = {}
LineConstraint.__index = LineConstraint

---@param offx? number
---@param offy? number
---@return number,number,number,number
function LineConstraint:get(offx, offy)
	local x, y, w, h

	if self.constraint.obj then
		x, y, w, h = self.constraint:_get()
	else
		x, y, w, h = self.constraint:get()
	end

	local fx, fy, fw, fh = getCachedData(self)

	if not (fx and fy and fw and fh) then
		if self.direction == "horizontal" then
			-- Vertical line for horizontal constraint
			if self.mode == "percent" then
				-- Interpolate
				--return mix(x, x + w, (self.flip and 1 or 0) + self.lineOffset) + offx, y + offy, 0, h
				fx, fy, fw, fh = mix(x, x + w, (self.flip and 1 or 0) + self.lineOffset), y, 0, h
			else
				-- Offset
				-- x + (self.flip and w or 0) + self.lineOffset + offx, y + offy, 0, h
				fx, fy, fw, fh = x + (self.flip and w or 0) + self.lineOffset, y, 0, h
			end
		else
			-- Horizontal line for vertical constraint
			if self.mode == "percent" then
				-- Interpolate
				-- x + offx, mix(y, y + h, (self.flip and 1 or 0) + self.lineOffset) + offy, w, 0
				fx, fy, fw, fh = x, mix(y, y + h, (self.flip and 1 or 0) + self.lineOffset), w, 0
			else
				-- Offset
				--return x + offx, y + (self.flip and h or 0) + self.lineOffset + offy, w, 0
				fx, fy, fw, fh = x, y + (self.flip and h or 0) + self.lineOffset, w, 0
			end
		end

		insertCached(self, fx, fy, fw, fh)
	end

	return fx + (offx or 0), fy + (offy or 0), fw, fh
end

-- (Re)-set the line offset.
function LineConstraint:offset(off)
	self.lineOffset = off + 0
	invalidateCache(self)
	return self
end

---@class NLay.GridCellConstraint: NLay.BaseConstraint
---@field private context NLay.Grid
---@field private x0 integer
---@field private y0 integer
local GridCellConstraint = {}
GridCellConstraint.__index = GridCellConstraint

---@param offx? number
---@param offy? number
---@return number,number,number,number
function GridCellConstraint:get(offx, offy)
	local x, y, w, h = self.context:_resolveCell(self.x0, self.y0)
	return x + (offx or 0), y + (offy or 0), w, h
end

---@class NLay.Grid
---@field private constraint NLay.Constraint
---@field private list NLay.GridCellConstraint[]
---@field private rows integer
---@field private cols integer
---@field private hspacing number
---@field private vspacing number
---@field private hfl boolean
---@field private vfl boolean
---@field private cellW number
---@field private cellH number
local Grid = {}
Grid.__index = Grid

---Retrieve GridCellConstraint at specified rows and columns.
---@param row integer Row number from 1 to max rows inclusive.
---@param col integer Column number from 1 to max columns inclusive.
function Grid:get(row, col)
	local constraint = self.list[(row - 1) * self.cols + col]

	if not constraint then
		constraint = setmetatable({
			context = self,
			x0 = col - 1,
			y0 = row - 1
		}, GridCellConstraint)
		self.list[(row - 1) * self.cols + col] = constraint
	end

	return constraint
end

function Grid:spacing(h, v, hfl, vfl)
	self.hspacing = h or self.hspacing
	self.vspacing = v or self.vspacing

	if hfl ~= nil then
		self.hfl = not not hfl
	end

	if vfl ~= nil then
		self.vfl = not not vfl
	end

	return self
end

---Calls a function for each grid cell constraint.
---
---NOTE: This initializes all the grid cell constraint in the list, which may slow.
---@param func fun(constraint:NLay.GridCellConstraint,row:integer,col:integer,...)
function Grid:foreach(func, ...)
	for y = 1, self.rows do
		for x = 1, self.cols do
			func(self:get(y, x), y, x, ...)
		end
	end

	return self
end

---Set fixed grid cell size.
---
---On dynamic mode, this function does nothing.
function Grid:cellSize(width, height)
	if self:isFixed() then
		self.cellW, self.cellH = width or self.cellW, height or self.cellH
		self:_updateSize()
	end

	return self
end

---Is the grid in dynamic mode or fixed mode?
---
---Dynamic mode means the cell size is calculated on-the-fly.
function Grid:isFixed()
	return not not (self.cellW or self.cellH)
end

---Retrieve dimensions of a single cell.
---
---NOTE: On dynamic mode, this function resolve the whole constraint so use with care!
---@return number,number
function Grid:getCellDimensions()
	local w, h = select(3, self:_resolveCell(0, 0))
	---@diagnostic disable-next-line: return-type-mismatch
	return w, h
end

---@package
function Grid:_updateSize()
	local width = self.hspacing * (self.cols + (self.hfl and 1 or -1)) + self.cellW * self.cols
	local height = self.vspacing * (self.rows + (self.vfl and 1 or -1)) + self.cellH * self.rows
	self.constraint:size(width, height)
end

---@package
---@param x number
---@param y number
function Grid:_resolveCell(x, y)
	-- x and y must be 0-based
	local xc, yc, w, h = self.constraint:get()
	if self.cellW and self.cellH then
		w, h = self.cellW, self.cellH
	else
		local cellW = (w - self.hspacing * (self.cols + (self.hfl and 1 or -1))) / self.cols
		local cellH = (h - self.vspacing * (self.rows + (self.vfl and 1 or -1))) / self.rows
		w, h = cellW, cellH
	end

	local xp = (x + (self.hfl and 1 or 0)) * self.hspacing + x * w
	local yp = (y + (self.vfl and 1 or 0)) * self.vspacing + y * h
	return xp + xc, yp + yc, w, h
end

---This class is not particularly useful other than creating new `NLay.Constraint` object.
---However it's probably better to cache this object if lots of same constraint creation is done with same
---"inside" parameters
---@class NLay.Inside
---@field package obj NLay.BaseConstraint
---@field private pad number[]
local Inside = {}
Inside.__index = Inside

---Create new `NLay.Constraint` object.
---@param top? NLay.BaseConstraint
---@param left? NLay.BaseConstraint
---@param bottom? NLay.BaseConstraint
---@param right? NLay.BaseConstraint
---@return NLay.Constraint
function Inside:constraint(top, left, bottom, right)
	local result = setmetatable({
		top = top,
		left = left,
		bottom = bottom,
		right = right,
		inTop = top == self.obj,
		inLeft = left == self.obj,
		inBottom = bottom == self.obj,
		inRight = right == self.obj,
		marginX = 0,
		marginY = 0,
		marginW = 0,
		marginH = 0,
		w = -1,
		h = -1,
		relW = false,
		relH = false,
		biasHorz = 0.5,
		biasVert = 0.5,
		inside = self,
		forceIntoFlags = false,
		aspectRatio = 0,
	}, Constraint)

	if top then
		addRefCache(result, top)
	end

	if left then
		addRefCache(result, left)
	end

	if bottom then
		addRefCache(result, bottom)
	end

	if right then
		addRefCache(result, right)
	end

	-- Deduce "into" flags
	result:_overrideIntoFlags()

	return result
end

---@package
---@return number,number,number,number
function Inside:_get()
	local x, y, w, h = self.obj:get()
	return x + self.pad[2], y + self.pad[1], w - self.pad[4] - self.pad[2], h - self.pad[3] - self.pad[1]
end

---@class NLay.RootConstraint: NLay.BaseConstraint
local NLay = {}
NLay.__index = NLay
NLay.x = 0
NLay.y = 0
NLay.width = 800
NLay.height = 600
NLay._VERSION = "1.4.2"
NLay._AUTHOR = "MikuAuahDark"
NLay._LICENSE = "MIT"

---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number
function NLay:get(offx, offy)
	return NLay.x + (offx or 0), NLay.y + (offy or 0), NLay.width, NLay.height
end

---Update the game window dimensions. Normally all return values from `love.window.getSafeArea` should be passed.
---@param x number
---@param y number
---@param w number
---@param h number
function NLay.update(x, y, w, h)
	if
		NLay.x ~= x or
		NLay.y ~= y or
		NLay.width ~= w or
		NLay.height ~= h
	then
		NLay.x, NLay.y, NLay.width, NLay.height = x, y, w, h
		NLay.flushCache()
	end
end

---Invalidate all constraint cache. Use sparingly!
---
---This function is automatically called after resolution change is detected
---in `NLay.update()`
function NLay.flushCache()
	for k in pairs(BaseConstraint.cache) do
		invalidateCache(k)
	end
end

---Create new `NLay.Inside` object used to construct `NLay.Constraint`.
---@param object NLay.BaseConstraint
---@param padding? number|number[]
---@return NLay.Inside
function NLay.inside(object, padding)
	padding = padding or 0

	-- Copy padding values
	local tabpad
	if type(padding) == "number" then
		tabpad = {padding, padding, padding, padding}
	else
		tabpad = {0, 0, 0, 0}
		for i = 1, 4 do
			tabpad[i] = padding[i] or 0
		end
	end

	-- TODO check if padding values were correct?
	return setmetatable({
		obj = object,
		pad = tabpad
	}, Inside)
end

---Create new constraint whose the size and the position is based on bounding box of the other constraint.
---@vararg NLay.BaseConstraint
---@return NLay.MaxConstraint
function NLay.max(...)
	assert(select("#", ...) > 1, "need at least 2 constraint")

	local list = {...}
	local result = setmetatable({
		list = {...}
	}, MaxConstraint)

	for _, v in ipairs(list) do
		addRefCache(result, v)
	end

	return result
end

---Create new guideline constraint. Horizontal direction creates vertical line with width of 0 for constraint to
---attach horizontally. Vertical direction creates horizontal line with height of 0 for constraint to attach
---vertically.
---@param constraint NLay.BaseConstraint | NLay.Inside
---@param direction '"horizontal"' | '"vertical"'
---@param mode '"percent"' | '"pixel"'
---@param offset number
---@return NLay.LineConstraint
function NLay.line(constraint, direction, mode, offset)
	if direction ~= "horizontal" and direction ~= "vertical" then
		error("invalid direction")
	end

	if mode ~= "percent" and mode ~= "pixel" then
		error("invalid mode")
	end

	local result = setmetatable({
		constraint = constraint,
		direction = direction,
		mode = mode,
		lineOffset = offset,
		flip = 1/offset < 0
	}, LineConstraint)
	addRefCache(result, constraint.obj and constraint.obj or constraint)
	return result
end

---Performs batched retrieval of constraint values, improves performance when resolving
---different constraints with identical attached constraints.
---@param ... NLay.BaseConstraint|number Constraint object followed by its x and y offset. The offsets are required, pass 0 if necessary.
---@return number[] @Interleaved resolved constraint values {x1, y1, w1, h1, ..., xn, yn, wn, hn}
---@deprecated
function NLay.batchGet(...)
	local count = select("#", ...)
	assert(count % 3 == 0, "invalid amount of values passed")

	local values = {}

	for i = 1, count, 3 do
		local constraint = select(i, ...)
		local offx, offy = select(i + 1, ...), select(i + 2, ...)

		local x, y, w, h = constraint:get(offx or 0, offy or 0)
		values[#values + 1] = x
		values[#values + 1] = y
		values[#values + 1] = w
		values[#values + 1] = h
	end

	return values
end

---@class NLay.GridSetting
---@field public hspacing number Horizontal spacing of the cell
---@field public vspacing number Vertical spacing of the cell
---@field public spacing number Spacing of the cell. `hspacing` and `vspacing` takes precedence.
---@field public hspacingfl boolean Should the horizontal spacing applies before the first and after the last columm?
---@field public vspacingfl boolean Should the vertical spacing applies before the first and after the last row?
---@field public spacingfl boolean Should the spacing applies before the first and after the last element? `hspacingfl` and `vspacingfl` takes precedence.
---@field public cellwidth number Fixed width of single cell. Setting this requires `cellheight` to be specified.
---@field public cellheight number Fixed height of single cell. Setting this requires `cellwidth` to be specified.

---Create new grid object.
---
---When fixed size mode is used, the Grid object will take the ownership of the constraint.
---@param constraint NLay.Constraint
---@param nrows integer
---@param ncols integer
---@param settings? NLay.GridSetting
function NLay.grid(constraint, nrows, ncols, settings)
	settings = settings or {}
	local vspace = math.max(selectDefault(settings.vspacing, settings.spacing, 0), 0)
	local hspace = math.max(selectDefault(settings.hspacing, settings.spacing, 0), 0)
	local vspacefl = selectDefault(settings.vspacingfl, settings.spacingfl, false)
	local hspacefl = selectDefault(settings.hspacingfl, settings.spacingfl, false)

	local cwidth, cheight

	if settings.cellwidth or settings.cellheight then
		cwidth = math.max(assert(settings.cellwidth, "missing fixed width"), 0)
		cheight = math.max(assert(settings.cellheight, "missing fixed height"), 0)
	end

	-- Prepopulate table
	local table = {}

	for _ = 1, nrows * ncols do
		table[#table + 1] = false
	end

	local obj = setmetatable({
		constraint = constraint,
		vspacing = vspace,
		hspacing = hspace,
		vfl = vspacefl,
		hfl = hspacefl,
		cellW = cwidth,
		cellH = cheight,
		rows = nrows,
		cols = ncols,
		list = table,
	}, Grid)

	if cwidth and cheight then
		obj:_updateSize()
	end

	return obj
end

return NLay

--[[
Changelog:

v1.4.2: 2023-01-18
> Fixed cache invalidation on NLay.update()

v1.4.1: 2022-12-17
> Fixed Constraint:ratio returns invalid values in certain cases.

v1.4.0: 2022-12-16
> Implemented a new caching mechanism. This should gives significant boost of
performance with complex constraints.
> Deprecated NLay.batchGet. Retrieving individual constraint is as fast as this
function.

v1.3.0: 2022-06-04
> Added modeW and modeH parameter to Constraint:size to calculate the size
either by relative size of the "size 0" constraint ("percent") or by absolute
value ("pixel"). The default is "pixel", which allows existing code unchanged.
> Added NLay.batchGet(constraint1, constraint2, ...) to resolve constraints in
one go, improving performance.
> Added NLay.grid for grid-based layouting.

v1.2.3: 2022-02-18
> Fixed aspect ratio logic again

v1.2.2: 2022-01-24
> Fixed aspect ratio logic

v1.2.1: 2021-12-15
> Added LineConstraint:offset()

v1.2.0: 2021-10-11
> Added aspect ratio size 0 constraint support (see Constraint:ratio() function)
> Fixed some "into" flag overriding.
> Prevent negative width/height in Constraint:get()

v1.1.2: 2021-09-29
> Added 3rd `unclamped` parameter to Constraint.bias.

v1.1.1: 2021-07-12
> Fixed Constraint:tag not working.

v1.1.0: 2021-07-11
> Added guideline constraint, created with NLay.line function.
> Added constraint tagging.

v1.0.4: 2021-06-27
> Implemented per-`:get()` value caching.

v1.0.3: 2021-06-25
> Added "Constraint:forceIn" function.

v1.0.2: 2021-06-23
> Added "offset" parameter to BaseConstraint:get()

v1.0.1: 2021-06-16
> Bug fixes on certain constraint combination.
> Added "bias" feature.

v1.0.0: 2021-06-15
> Initial release.
]]
