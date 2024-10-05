-- NPad's Layouting Library, based on ConstraintLayout
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

---@class NLay._Cache
---@field package x number?
---@field package y number?
---@field package w number?
---@field package h number?
---@field package referenced (NLay.BaseConstraint?)[]
---@field package refLength integer

---@class NLay.BaseConstraint
---@field package cache table<NLay.BaseConstraint, NLay._Cache?>
---@field protected userTag any
---@field public _NLay_type_ string
local BaseConstraint = {
	cache = setmetatable({}, {__mode = "k"})
}

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function BaseConstraint:get(offx, offy)
---@diagnostic disable-next-line: missing-return
end

---Tag this constraint with some userdata, like an id, for example.
---Useful to keep track of constraints when they're rebuilt.
---@generic T: NLay.BaseConstraint
---@param self T
---@param userdata any
---@return T
function BaseConstraint:tag(userdata)
	self.userTag = userdata
	return self
end

---@return any
function BaseConstraint:getTag()
	return self.userTag
end

local function dupmethods(t)
	local r = {}

	for k, v in pairs(t) do
		if type(v) == "function" then
			r[k] = v
		end
	end

	return r
end



---@class NLay.Constraint: NLay.BaseConstraint
---@field package top NLay.BaseConstraint?
---@field package left NLay.BaseConstraint?
---@field package bottom NLay.BaseConstraint?
---@field package right NLay.BaseConstraint?
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
---@field package pad number[]
---@field private relW boolean
---@field private relH boolean
---@field private biasHorz number
---@field private biasVert number
---@field package parent NLay.BaseConstraint
local Constraint = dupmethods(BaseConstraint)
---@private
Constraint.__index = Constraint ---@diagnostic disable-line: inject-field
Constraint._NLay_type_ = "NLay.Constraint"

---@param a number
---@param b number
---@param t number
local function mix(a, b, t)
	return (1 - t) * a + t * b
end

---@param self NLay.Constraint
---@param target NLay.BaseConstraint
local function resolveWithoutPadding(self, target)
	local x, y, w, h = target:get()

	if self.parent ~= target and target._NLay_type_ == Constraint._NLay_type_ then
		---@cast self NLay.Constraint
		x = x - self.pad[2]
		y = y - self.pad[1]
		w = w + self.pad[4] + self.pad[2]
		h = h + self.pad[3] + self.pad[1]
	end

	return x, y, w, h
end

---@param self NLay.Constraint
local function resolveWidthSize0(self)
	local x, width

	if self.left == nil or self.right == nil then
		error("insufficient constraint for width 0")
	end

	-- Left
	local e1x, _, e1w = resolveWithoutPadding(self, self.left)
	if self.inLeft then
		x = e1x + self.marginX
	else
		x = e1x + e1w + self.marginX
	end

	-- Right
	local e2x, _, e2w = resolveWithoutPadding(self, self.right)
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

	local e1y, _, e1h = select(2, resolveWithoutPadding(self, self.top))

	if self.inTop then
		y = e1y + self.marginY
	else
		y = e1y + e1h + self.marginY
	end

	local e2y, _, e2h = select(2, resolveWithoutPadding(self, self.bottom))

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
		error("invalid \""..name.."\" size mode (\"pixel\" or \"percent\" expected)", 2)
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
---@param ... T|nil
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

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function Constraint:get(offx, offy)
	local finalX, finalY, finalW, finalH = getCachedData(self)

	if not (finalX and finalY and finalW and finalH) then
		if (self.left ~= nil or self.right ~= nil) and (self.top ~= nil or self.bottom ~= nil) then
			local x, y, w, h
			local width, height = self.w, self.h

			-- Convert percent values to pixel values
			if self.relW then
				width = select(2, resolveWidthSize0(self)) * self.w
			end

			if self.relH then
				height = select(2, resolveHeightSize0(self)) * self.h
			end

			if width == -1 then
				-- Match parent
				local px, _, pw = resolveWithoutPadding(self, self.parent)
				x, width = px, pw
			elseif width == 0 then
				-- Match constraint
				x, width = resolveWidthSize0(self)
			end

			if height == -1 then
				-- Match parent
				---@type number,number,number
				local py, _, ph = select(2, resolveWithoutPadding(self, self.parent)) ---@diagnostic disable-line: assign-type-mismatch
				y, height = py, ph
			elseif height == 0 then
				-- Match constraint
				y, height = resolveHeightSize0(self)
			end

			do
				local l, r
				w = width

				if self.left then
					-- Left orientation
					local e1x, _, e1w = resolveWithoutPadding(self, self.left)

					if self.inLeft then
						l = e1x + self.marginX
					else
						l = e1x + e1w + self.marginX
					end
				end

				if self.right then
					-- Right orientation
					local e2x, _, e2w = resolveWithoutPadding(self, self.right)

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
					local e1y, _, e1h = select(2, resolveWithoutPadding(self, self.top))

					if self.inTop then
						t = e1y + self.marginY
					else
						t = e1y + e1h + self.marginY
					end
				end

				if self.bottom then
					-- Bottom orientation
					local e2y, _, e2h = select(2, resolveWithoutPadding(self, self.bottom))

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
			finalX = x + self.pad[2]
			finalY = y + self.pad[1]
			finalW = math.max(w - self.pad[4] - self.pad[2], 0)
			finalH = math.max(h - self.pad[3] - self.pad[1], 0)
			insertCached(self, finalX, finalY, finalW, finalH)
		else
			error("insufficient constraint")
		end
	end

	return finalX + (offx or 0), finalY + (offy or 0), finalW, finalH
end

---Set the constraint margin
---@param margin number|number[] Either number to apply all margins or table {top, left, bottom, right} margin. Defaults to 0 for absent/nil values.
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

---@param kind string
---@param c1name string
---@param c2name string
---@param c1 NLay.BaseConstraint?
---@param c2 NLay.BaseConstraint?
local function constraintValidate(kind, c1name, c2name, c1, c2)
	if c1 == nil then
		error(kind.." but "..c1name.." constraint is unset", 2)
	elseif c2 == nil then
		error(kind.." but "..c2name.." constraint is unset", 2)
	end
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

	-- Validate
	if self.w == 0 then
		constraintValidate("size 0 width", "left", "right", self.left, self.right)
	elseif self.relW then
		constraintValidate("relative width", "left", "right", self.left, self.right)
	end

	if self.h == 0 then
		constraintValidate("size 0 height", "top", "bottom", self.top, self.bottom)
	elseif self.relH then
		constraintValidate("relative height", "top", "bottom", self.top, self.bottom)
	end

	-- Ok. Invalidate cache.
	invalidateCache(self)
	return self
end

---Set the constraint bias. By default, for fixed width/height, the position are centered around (bias 0.5).
---@param horz number|nil Horizontal bias, real value between 0..1 inclusive.
---@param vert number|nil Vertical bias, real value between 0..1 inclusive.
---@param unclamped? boolean Do not limit bias ratio?
---@return NLay.Constraint
function Constraint:bias(horz, vert, unclamped)
	if horz then
		constraintValidate("setting horizontal bias", "left", "right", self.left, self.right)

		if unclamped then
			self.biasHorz = horz
		else
			self.biasHorz = math.min(math.max(horz, 0), 1)
		end
	end

	if vert then
		constraintValidate("setting vertical bias", "top", "bottom", self.top, self.bottom)

		if unclamped then
			self.biasVert = vert
		else
			self.biasVert = math.min(math.max(vert, 0), 1)
		end
	end

	invalidateCache(self)
	return self
end



---@class NLay.MaxConstraint: NLay.BaseConstraint
---@field private list NLay.BaseConstraint[]
local MaxConstraint = dupmethods(BaseConstraint)
---@private
MaxConstraint.__index = MaxConstraint ---@diagnostic disable-line: inject-field
MaxConstraint._NLay_type_ = "NLay.MaxConstraint"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
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
---@field private constraint NLay.BaseConstraint
---@field private direction '"horizontal"' | '"vertical"'
---@field private mode '"percent"' | '"pixel"'
---@field private lineOffset number
---@field private flip boolean
local LineConstraint = dupmethods(BaseConstraint)
---@private
LineConstraint.__index = LineConstraint ---@diagnostic disable-line: inject-field
LineConstraint._NLay_type_ = "NLay.LineConstraint"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function LineConstraint:get(offx, offy)
	local fx, fy, fw, fh = getCachedData(self)

	if not (fx and fy and fw and fh) then
		local x, y, w, h = self.constraint:get()

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
local GridCellConstraint = dupmethods(BaseConstraint)
---@private
GridCellConstraint.__index = GridCellConstraint ---@diagnostic disable-line: inject-field
GridCellConstraint._NLay_type_ = "NLay.GridCellConstraint"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
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
---@field public _NLay_type_ string
local Grid = {_NLay_type_ = "NLay.Grid"}
---@private
Grid.__index = Grid ---@diagnostic disable-line: inject-field

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

---@private
function Grid:_invalidateCellCache()
	-- Invalidate cache for cells
	for y = 1, self.rows do
		for x = 1, self.cols do
			local constraint = self.list[(y - 1) * self.cols + x]

			if constraint then
				invalidateCache(constraint)
			end
		end
	end
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

	self:_invalidateCellCache()
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

local function dummy() end

---Forcefully initialize all the grid cell constraint in the list.
function Grid:preload()
	return self:foreach(dummy)
end

---Set fixed grid cell size.
---
---On dynamic mode, this function does nothing.
---@param width number
---@param height number
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
	self:_invalidateCellCache()
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



---@class NLay.RatioConstraint: NLay.BaseConstraint
---@field private parent NLay.BaseConstraint
---@field private numerator number
---@field private denominator number
---@field private biasHorz number
---@field private biasVert number
---@field private expand boolean
local RatioConstraint = dupmethods(BaseConstraint)
---@private
RatioConstraint.__index = RatioConstraint ---@diagnostic disable-line: inject-field
RatioConstraint._NLay_type_ = "NLay.RatioConstraint"

---@param constraint NLay.BaseConstraint
---@param expand boolean
local function makeRatioConstraint(constraint, expand)
	local result = setmetatable({
		parent = constraint,
		numerator = 1,
		denominator = 1,
		biasHorz = 0.5,
		biasVert = 0.5,
		expand = expand,
	}, RatioConstraint)
	addRefCache(result, constraint)
	return result
end

---Set constraint aspect ratio.
---@param num number Rational number in form of `numerator/denominator` for `numerator:denominator` aspect ratio (absolute value is taken).
---@return NLay.RatioConstraint
---@diagnostic disable-next-line: duplicate-set-field, missing-return
function RatioConstraint:ratio(num) end

---Set constraint aspect ratio.
---@param numerator number Aspect ratio numerator (absolute value is taken).
---@param denominator number Aspect ratio denominator (absolute value is taken).
---@return NLay.RatioConstraint
---@diagnostic disable-next-line: duplicate-set-field
function RatioConstraint:ratio(numerator, denominator)
	local den = math.abs(denominator or 1)
	assert(den > 0, "divide by zero")
	self.numerator = math.abs(numerator)
	self.denominator = den

	invalidateCache(self)
	return self
end

---Set the constraint bias. By default, the position are centered around (bias 0.5).
---@param horz number|nil Horizontal bias, real value between 0..1 inclusive.
---@param vert number|nil Vertical bias, real value between 0..1 inclusive.
---@param unclamped? boolean Do not limit bias ratio?
---@return NLay.RatioConstraint
function RatioConstraint:bias(horz, vert, unclamped)
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

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function RatioConstraint:get(offx, offy)
	local x, y, w, h = self.parent:get()
	local rx, ry, rw, rh, scale

	-- TODO: Reduce division operation?
	if self.expand then
		scale = math.max(w / self.numerator, h / self.denominator)
	else
		scale = math.min(w / self.numerator, h / self.denominator)
	end

	rw = self.numerator * scale
	rh = self.denominator * scale
	rx = mix(0, w - rw, self.biasHorz)
	ry = mix(0, h - rh, self.biasVert)

	return x + rx + (offx or 0), y + ry + (offy or 0), rw, rh
end



---@class NLay.FloatingConstraint: NLay.BaseConstraint
---@field private x number
---@field private y number
---@field private w number
---@field private h number
local FloatingConstraint = dupmethods(BaseConstraint)
---@private
FloatingConstraint.__index = FloatingConstraint ---@diagnostic disable-line: inject-field
FloatingConstraint._NLay_type_ = "NLay.FloatingConstraint"

---Set floating constraint position.
---@param x? number Floating constraint X position
---@param y? number Floating constraint Y position
---@return NLay.FloatingConstraint
function FloatingConstraint:pos(x, y)
	x = x or self.x
	y = y or self.y

	local diff = x ~= self.x or y ~= self.y
	self.x = x
	self.y = y

	if diff then
		invalidateCache(self)
	end

	return self
end

---Set floating constraint size.
---@param w? number Floating constraint width (absolute value is taken)
---@param h? number Floating constraint height (absolute value is taken)
---@return NLay.FloatingConstraint
function FloatingConstraint:size(w, h)
	w = math.abs(w or self.w)
	h = math.abs(h or self.h)

	local diff = w ~= self.w or h ~= self.h
	self.w = w
	self.h = h

	if diff then
		invalidateCache(self)
	end

	return self
end

---Set floating constraint position and dimensions
---@param x? number Floating constraint X position
---@param y? number Floating constraint Y position
---@param w? number Floating constraint width (absolute value is taken)
---@param h? number Floating constraint height (absolute value is taken)
function FloatingConstraint:update(x, y, w, h)
	self:size(w, h)
	return self:pos(x, y)
end

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function FloatingConstraint:get(offx, offy)
	return self.x + (offx or 0), self.y + (offy or 0), self.w, self.h
end

---@class NLay.ForeignConstraint: NLay.BaseConstraint
---@field private getter {get:fun(self:any):(number,number,number,number)}
---@field private manualupdate boolean
local ForeignConstraint = dupmethods(BaseConstraint)
---@private
ForeignConstraint.__index = ForeignConstraint ---@diagnostic disable-line: inject-field
ForeignConstraint._NLay_type_ = "NLay.ForeignConstraint"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function ForeignConstraint:get(offx, offy)
	if not self.manualupdate then
		invalidateCache(self)
	end

	local x, y, w, h = self.getter:get()
	return x + (offx or 0), y + (offy + 0), w, h
end



---@class NLay.SelectableConstraint: NLay.BaseConstraint
---@field package constraints NLay.BaseConstraint[]
---@field private selectedIndex integer
local SelectableConstraint = dupmethods(BaseConstraint)
---@private
SelectableConstraint.__index = SelectableConstraint ---@diagnostic disable-line: inject-field
SelectableConstraint._NLay_type_ = "NLay.SelectableConstraint"

---Select active constraint by specified index.
---@param i integer Constraint index.
function SelectableConstraint:index(i)
	assert(i > 0 and i <= #self.constraints, "index out of range")
	self.selectedIndex = i
	invalidateCache(self)
	return self
end

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function SelectableConstraint:get(offx, offy)
	return self.constraints[self.selectedIndex]:get(offx, offy)
end



---@class NLay.TransposedConstraint: NLay.BaseConstraint
---@field private parent NLay.BaseConstraint
local TransposedConstraint = dupmethods(BaseConstraint)
---@private
TransposedConstraint.__index = TransposedConstraint ---@diagnostic disable-line: inject-field
TransposedConstraint._NLay_type_ = "NLay.TransposedConstraint"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function TransposedConstraint:get(offx, offy)
	local x, y, w, h = self.parent:get(offx, offy)
	return x, y, h, w -- note the order
end



---This class is used to mark to consider the inner border of a constraint instead of the outer.
---@class NLay.Into
---@field public value NLay.BaseConstraint
---@field public _NLay_type_ string
local Into = {_NLay_type_ = "NLay.Into"}
---@private
Into.__index = Into ---@diagnostic disable-line: inject-field

---@param constraintOrInto? NLay.BaseConstraint|NLay.Into
local function extractConstraint(constraintOrInto)
	if constraintOrInto and constraintOrInto._NLay_type_ == Into._NLay_type_ then
		return constraintOrInto.value
	end

	---@cast constraintOrInto -NLay.Into
	---@cast constraintOrInto +nil
	return constraintOrInto
end

---@param constraintOrInto? NLay.BaseConstraint|NLay.Into
local function isInto(constraintOrInto)
	return constraintOrInto and constraintOrInto._NLay_type_ == Into._NLay_type_
end



---NPad's Layouting Library, based on ConstraintLayout
---@class NLay.RootConstraint: NLay.BaseConstraint
local NLay = dupmethods(BaseConstraint)
NLay.__index = NLay
NLay.x = 0
NLay.y = 0
NLay.width = 800
NLay.height = 600
NLay._VERSION = "2.0.1"
NLay._AUTHOR = "MikuAuahDark"
NLay._LICENSE = "MIT"

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx? number X offset (default to 0)
---@param offy? number Y offset (default to 0)
---@return number,number,number,number @Position (x, y) and dimensions (width, height) of the constraint.
function NLay:get(offx, offy)
	return NLay.x + (offx or 0), NLay.y + (offy or 0), NLay.width, NLay.height
end

---Update the game window dimensions. Normally all return values from `love.window.getSafeArea` should be passed.
---@param x number
---@param y number
---@param w number (absolute value is taken)
---@param h number (absolute value is taken)
function NLay.update(x, y, w, h)
	w = math.abs(w)
	h = math.abs(h)

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

---Invalidate specific or all constraint cache. Use sparingly!
---
---This function is automatically called after resolution change is detected
---in `NLay.update()`
---@param constraint? NLay.BaseConstraint Specific constraint to invalidate its cache such as transposed constraint or foreign constraint (or `nil` to invalidate all constraint cache)
function NLay.flushCache(constraint)
	if constraint then
		return invalidateCache(constraint)
	else
		for k in pairs(BaseConstraint.cache) do
			invalidateCache(k)
		end
	end
end

---Mark that the inner part of this specific constraint should be used instead of the outer part.
---Note that these condition automatically assume inner part of constraint to be considered:
---* Specified constraint (top/left/bottom/right) is the parent.
---* Same constraint is specified for the adjacent axis (top and bottom is same or left and right is same)
---
---This function has underscore after the function name because `in` is reserved keyword in Lua.
---
---Example diagram without `in_` of left constraint:
---```txt
---o------------o
---|            |
---|            | <-- anchor
---|            |
---o------------o
---```
---
---Example diagram **with** `in_` of left constraint:
---```txt
---o------------o
---|            |
---| <-- anchor |
---|            |
---o------------o
---```
---@param constraint NLay.BaseConstraint
---@return NLay.Into
function NLay.in_(constraint)
	return setmetatable({value = constraint}, Into)
end

---Create new normal constraint.
---@param parent NLay.BaseConstraint Parent constraint.
---@param top? NLay.BaseConstraint|NLay.Into Top constraint to attach to.
---@param left? NLay.BaseConstraint|NLay.Into Left constraint to attach to.
---@param bottom? NLay.BaseConstraint|NLay.Into Bottom constraint to attach to.
---@param right? NLay.BaseConstraint|NLay.Into Right constraint to attach to.
---@param padding? number|number[]
---@nodiscard
function NLay.constraint(parent, top, left, bottom, right, padding)
	local ctop = extractConstraint(top)
	local cleft = extractConstraint(left)
	local cbottom = extractConstraint(bottom)
	local cright = extractConstraint(right)

	local inHorz = cleft ~= nil and cright ~= nil and cleft == cright
	local inVert = ctop ~= nil and cbottom ~= nil and ctop == cbottom

	local tabpad = {0, 0, 0, 0}
	if padding then
		if type(padding) == "number" then
			tabpad[1] = padding
			tabpad[2] = padding
			tabpad[3] = padding
			tabpad[4] = padding
		else
			tabpad[1] = padding[1] or 0
			tabpad[2] = padding[2] or 0
			tabpad[3] = padding[3] or 0
			tabpad[4] = padding[4] or 0
		end
	end

	local result = setmetatable({
		top = ctop,
		left = cleft,
		bottom = cbottom,
		right = cright,
		inTop = ctop == parent or inVert or isInto(top),
		inLeft = cleft == parent or inHorz or isInto(left),
		inBottom = cbottom == parent or inVert or isInto(bottom),
		inRight = cright == parent or inHorz or isInto(right),
		marginX = 0,
		marginY = 0,
		marginW = 0,
		marginH = 0,
		w = -1,
		h = -1,
		pad = tabpad,
		relW = false,
		relH = false,
		biasHorz = 0.5,
		biasVert = 0.5,
		parent = parent,
	}, Constraint)

	if ctop then
		addRefCache(result, ctop)
	end

	if cleft then
		addRefCache(result, cleft)
	end

	if cbottom then
		addRefCache(result, cbottom)
	end

	if cright then
		addRefCache(result, cright)
	end

	return result
end

---Create new constraint whose the size and the position is based on maximum bounding box of the other constraint.
---@vararg NLay.BaseConstraint
---@return NLay.MaxConstraint
---@nodiscard
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
---@param constraint NLay.BaseConstraint
---@param direction '"horizontal"' | '"vertical"'
---@param mode '"percent"' | '"pixel"'
---@param offset number
---@return NLay.LineConstraint
---@nodiscard
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
	addRefCache(result, constraint)
	return result
end

---@class NLay.GridSetting
---@field public hspacing? number Horizontal spacing of the cell
---@field public vspacing? number Vertical spacing of the cell
---@field public spacing? number Spacing of the cell. `hspacing` and `vspacing` takes precedence.
---@field public hspacingfl? boolean Should the horizontal spacing applies before the first and after the last columm?
---@field public vspacingfl? boolean Should the vertical spacing applies before the first and after the last row?
---@field public spacingfl? boolean Should the spacing applies before the first and after the last element? `hspacingfl` and `vspacingfl` takes precedence.
---@field public cellwidth? number Fixed width of single cell. Setting this requires `cellheight` to be specified.
---@field public cellheight? number Fixed height of single cell. Setting this requires `cellwidth` to be specified.

---Create new grid object.
---
---When fixed size mode is used, the Grid object will take the ownership of the constraint.
---@param constraint NLay.Constraint
---@param nrows integer
---@param ncols integer
---@param settings? NLay.GridSetting
---@nodiscard
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

---Create new constraint that fits exactly inside other constraint, downscaling the constraint if necessary.
---This is equivalent to [`object-fit: contain`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit) in CSS3.
---
---Default aspect ratio is 1:1.
---@param constraint NLay.BaseConstraint Parent constraint.
---@return NLay.RatioConstraint
---@nodiscard
function NLay.contain(constraint)
	return makeRatioConstraint(constraint, false)
end

---Create new constraint that cover all area inside other constraint, upscaling the constraint if necessary.
---This is equivalent to [`object-fit: cover`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit) in CSS3.
---
---Default aspect ratio is 1:1.
---@param constraint NLay.BaseConstraint Parent constraint.
---@return NLay.RatioConstraint
---@nodiscard
function NLay.cover(constraint)
	return makeRatioConstraint(constraint, true)
end

---Create new free-floating constraint. This can serve as "alternaive" root for another constraints.
---@param x number Floating constraint X position
---@param y number Floating constraint Y position
---@param w number Floating constraint width (absolute value is taken)
---@param h number Floating constraint height (absolute value is taken)
---@return NLay.FloatingConstraint
---@nodiscard
function NLay.floating(x, y, w, h)
	return setmetatable({
		x = x,
		y = y,
		w = w,
		h = h,
	}, FloatingConstraint)
end

---Create new foreign constraint. This is mainly used for interopability with other layouting library.
---@param object {get:fun(self:any):(number,number,number,number)} Foreign constraint object with `:get()` function that returns the position (x, y) and dimension (w, h) of it.
---@param manualupdate? boolean Do you want to manually invalidate the cache for this constraint or let NLay do it? **If set to `true`, you're responsible of invalidating the cache of this constraint yourself using `NLay.flushCache()` if the underlying region/constraint value changes!**
---@return NLay.ForeignConstraint
---@nodiscard
function NLay.foreign(object, manualupdate)
	return setmetatable({
		getter = object,
		manualupdate = not not manualupdate
	}, ForeignConstraint)
end

---Create new selectable constraint.
---@param constraint1 NLay.BaseConstraint First constraint.
---@param ... NLay.BaseConstraint Additional constraints.
---@return NLay.SelectableConstraint
function NLay.selectable(constraint1, ...)
	local result = setmetatable({
		constraints = {constraint1, ...}
	}, SelectableConstraint)

	for _, c in result.constraints do
		addRefCache(result, c)
	end

	return result
end

---Creates normal constraints by splitting other constraint, either horizontal or vertically.
---@param constraint NLay.BaseConstraint The container.
---@param direction '"horizontal"' | '"vertical"' "horizontal" means from left to right, "vertical" means from top to bottom
---@param weights1 number First section weight.
---@param weights2 number Second section weight.
---@param ... number Additional section weights.
---@return NLay.Constraint ... List of constraints.
---@nodiscard
function NLay.split(constraint, direction, weights1, weights2, ...)
	assert(direction == "horizontal" or direction == "vertical", "invalid direction")

	local weights = {weights1, weights2, ...}
	local totalWeights = 0
	for _, w in ipairs(weights) do
		totalWeights = totalWeights + w
	end

	local constraints = {}

	-- Start splitting
	local currentCumulative = 0
	local prev = constraint
	local next = constraint
	for i = 1, #weights do
		currentCumulative = currentCumulative + weights[i]

		if i == #weights then
			next = constraint
		else
			next = NLay.line(constraint, direction, "percent", currentCumulative / totalWeights)
		end

		local top, left, bottom, right
		if direction == "horizontal" then
			top, left, bottom, right = constraint, prev, constraint, next
		elseif direction == "vertical" then
			top, left, bottom, right = prev, constraint, next, constraint
		end

		constraints[#constraints+1] = NLay.constraint(constraint, top, left, bottom, right):size(0, 0)
		prev = next
	end

	return unpack(constraints)
end

---Create new transposed constraint. Transposed constraint has its width and height swapped.
---@param constraint NLay.BaseConstraint Base constraint.
---@return NLay.TransposedConstraint
---@nodiscard
function NLay.transposed(constraint)
	local result = setmetatable({
		parent = constraint
	}, TransposedConstraint)
	addRefCache(result, constraint)
	return result
end

---Check if a value is any kind of NLay constraint.
---@param object any
---@return boolean
function NLay.isConstraint(object)
	if type(object) == "table" and object._NLay_type_ then
		---@cast object NLay.BaseConstraint
		return object._NLay_type_:sub(1, 5) == "NLay." and object._NLay_type_:sub(-10) == "Constraint"
	end

	return false
end

return NLay

--[[
Changelog:

v2.0.1: 2024-10-05
> Fixed annotation of NLay.grid.
> Fixed behavior on constraint padding.
> Workaround annotation issue with recent LuaLS plugin.

v2.0.0: 2024-10-03
> Replaced NLay.inside(c, pad):constraint(...) with simpler NLay.constraint(c, ..., pad).
> Replaced Constraint:ratio(num/den) with NLay.contain(constraint):ratio(num, den).
> Replaced Constraint:forceIn() with NLay.in_().
> Removed NLay.batchGet().
> Added NLay.cover(constraint).
> Added NLay.floating(x, y, w, h) to create floating constraint.
> Added NLay.foreign(object) to ease interopability with other layouting library.
> Added NLay.selectable(...constraint) to allow dynamically selectable constraint.
> Added NLay.split(direction, constraint, ...ratio) to create dividable constraint by ratios.
> Added NLay.transposed(constraint) which swap the width and height of a constraint.
> Added NLay.isConstraint to test if a value is an NLay constraint.

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
