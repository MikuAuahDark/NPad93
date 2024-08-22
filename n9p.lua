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
		if type(x) == "number" then
			return love.graphics.applyTransform(love.math.newTransform(x, y, a, sx, sy, ox, oy, kx, ky))
		else
			return love.graphics.applyTransform(x)
		end
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
---@field private stretchableW integer
---@field private stretchableH integer
local Instance = {}
Instance.__index = Instance ---@diagnostic disable-line: inject-field

---@param horizontals {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@param verticals {[1]:n9p.QuadDrawMode,[2]:integer}[]
---@param quads love.Quad[]
---@param padding {[1]:integer,[2]:integer,[3]:integer,[4]:integer}
local function makeInstance(horizontals, verticals, quads, padding)
	local dimensions = {0, 0, 0, 0}

	for i, regions in ipairs({horizontals, verticals}) do
		for _, v in ipairs(regions) do
			if v[1] == "keep" then
				dimensions[i] = dimensions[i] + v[2]
			else
				dimensions[i + 2] = dimensions[i + 2] + v[2]
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
		stretchableW = dimensions[3],
		stretchableH = dimensions[4],
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
	assert(y >= 0 and y < #self.vmeasure, "invalid Y position")
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

---Retrieve the padding for content area.
---@return integer,integer,integer,integer @Left, top, right, and bottom padding of the content area.
function Instance:getPadding()
	return self.padding[1], self.padding[2], self.padding[3], self.padding[4]
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
			width, height = x, y
		else
			applyTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
		end
		self:_drawInternal(width, height)

		love.graphics.pop()
	end
end

---Draw the stretchable using the specified constraint as the information.
---@param constraint {get:fun(...):(number,number,number,number)} Table containing a `get` function. The `constraint` will be passed as 1st argument during the `get()` call.
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

---@param width number
---@param height number
---@private
function Instance:_drawInternal(width, height)
	local tex = assert(self.texture)
	width = math.max(width, self.minW) - self.minW
	height = math.max(height, self.minH) - self.minH

	local segmentWidth = #self.hmeasure
	local yoff = 0
	local scalex = width / self.stretchableW -- Don't use if it's used to scale segment length
	local scaley = height / self.stretchableH -- Don't use if it's used to scale segment length
	for y, vinfo in ipairs(self.vmeasure) do
		local xoff = 0
		local doyscale = false
		local yrepeat = 1

		if vinfo[1] == "stretch" then
			doyscale = true
		elseif vinfo[1] == "repeat" then
			yrepeat = height / self.stretchableH
		end

		for x, hinfo in ipairs(self.hmeasure) do
			local quad = self.quads[(y - 1) * segmentWidth + x]
			local xrepeat = 1
			local doxscale = false

			if hinfo[1] == "stretch" then
				doxscale = true
			elseif hinfo[1] == "repeat" then
				xrepeat = width / self.stretchableW
			end

			-- Draw
			local yloop = math.floor(yrepeat)
			for yr = 1, yloop do
				local xloop = math.floor(xrepeat)

				for xr = 1, xloop do
					love.graphics.draw(
						tex, quad,
						xoff + (xr - 1) * hinfo[2],
						yoff + (yr - 1) * vinfo[2],
						0,
						doxscale and scalex or 1,
						doyscale and scaley or 1
					)
				end

				local xfract = xrepeat % 1
				if xfract > 0 then
					local vx, vy, vw, vh = quad:getViewport()
					---@diagnostic disable-next-line: missing-parameter
					self.repeatQuad:setViewport(
						vx, vy,
						doxscale and (vw * width / self.stretchableW) or (vw * xfract),
						vh
					)

					love.graphics.draw(
						tex, self.repeatQuad,
						xoff + xloop * vw,
						yoff + (yr - 1) * vh,
						0,
						doxscale and scalex or 1,
						doyscale and scaley or 1
					)
				end
			end

			local yfract = yrepeat % 1
			if yfract > 0 then
				-- TODO: Deduplicate
				local xloop = math.floor(xrepeat)
				local vx, vy, vw, vh = quad:getViewport()
				---@diagnostic disable-next-line: missing-parameter
				self.repeatQuad:setViewport(
					vx, vy,
					vw,
					doyscale and (vh * height / self.stretchableH) or (vh * yfract)
				)

				for xr = 1, xloop do
					love.graphics.draw(
						tex, self.repeatQuad,
						xoff + (xr - 1) * hinfo[2],
						yoff + yloop * vinfo[2],
						0,
						doxscale and scalex or 1,
						doyscale and scaley or 1
					)
				end

				local xfract = xrepeat % 1
				if xfract > 0 then
					---@diagnostic disable-next-line: missing-parameter
					self.repeatQuad:setViewport(
						vx, vy,
						doxscale and (vw * width / self.stretchableW) or (vw * xfract),
						doyscale and (vh * height / self.stretchableH) or (vh * yfract)
					)
					love.graphics.draw(
						tex, self.repeatQuad,
						xoff + xloop * vw,
						yoff + yloop * vh,
						0,
						doxscale and scalex or 1,
						doyscale and scaley or 1
					)
				end
			end

			xoff = xoff + (hinfo[1] == "keep" and hinfo[2] or (hinfo[2] * width / self.stretchableW))
		end

		yoff = yoff + (vinfo[1] == "keep" and vinfo[2] or (vinfo[2] * height / self.stretchableH))
	end
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
---@param wrap boolean? Repeat the area instead of streching it?
function Builder:addHorizontalSlice(startX, endX, wrap)
	assert(startX >= 0, "invalid X position")
	assert(endX >= startX, "invalid X interval")
	self.hregion[#self.hregion+1] = {startX, endX, not not wrap}
	return self:_cleanupIntersectingRegion(self.hregion)
end

---Add stretchable/repeatable region on vertical axis.
---@param startY integer Start Y position of the slice, inclusive.
---@param endY integer End Y position of the slice, **inclusive**.
---@param wrap boolean? Repeat the area instead of streching it?
function Builder:addVerticalSlice(startY, endY, wrap)
	assert(startY >= 0, "invalid Y position")
	assert(endY >= startY, "invalid Y interval")
	self.vregion[#self.vregion+1] = {startY, endY, not not wrap}
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

---Create the new stretchable image instance.
---
---For single-contained .9.png image, only the `textureWidth` and `textureHeight` are necessary.
---
---If the actual .9.png is contained in a texture atlas, additional steps must be taken:
---* Pass the texture atlas dimensions to `textureWidth` and `textureHeight`.
---* Pass the top-left position on where the .9.png image are placed in the texture atlas with the `subX` and `subY` parameter.
---* Pass the actual .9.png image (minus the 1px border on all sides) image dimensions with the `subW` and `subH` parameter.
---@param textureWidth integer Width of reference texture.
---@param textureHeight integer height of reference texture.
---@param subX integer? X offset subregion of the reference texture (for texture atlas)
---@param subY integer? Y offset subregion of the reference texture (for texture atlas)
---@param subW integer? Subregion width of the reference texture (for texture atlas)
---@param subH integer? Subregion width of the reference texture (for texture atlas)
---@return n9p.Instance @New stretchable image instance.
function Builder:build(textureWidth, textureHeight, subX, subY, subW, subH)
	assert(#self.hregion > 0, "no horizontal region")
	assert(#self.vregion > 0, "no vertical region")

	subX = subX or 0
	subY = subY or 0
	subW = subW or textureWidth
	subH = subH or textureHeight

	assert(subX >= 0, "invalid X subregion")
	assert(subY >= 0, "invalid Y subregion")
	assert(subW <= textureWidth, "invalid subregion width")
	assert(subX <= textureHeight, "invalid subregion height")

	local horz = {} ---@type {[1]:n9p.QuadDrawMode,[2]:integer}[]
	local vert = {} ---@type {[1]:n9p.QuadDrawMode,[2]:integer}[]
	local quads = {}

	-- Add unstretchable regions
	if self.hregion[1][1] > subX then
		horz[#horz+1] = {"keep", self.hregion[1][1] - subX}
	end

	if self.vregion[1][1] > subY then
		vert[#vert+1] = {"keep", self.vregion[1][1] - subY}
	end

	-- Loop region
	for _, target in ipairs({
		{horz, self.hregion, subX + subW},
		{vert, self.vregion, subY + subH}
	}) do
		local targetRegions = target[1]

		for i, reg in ipairs(target[2]) do
			targetRegions[#targetRegions+1] = {reg[3] and "repeat" or "stretch", reg[2] - reg[1] + 1}

			local regp1 = target[2][i + 1]

			-- For intermediate region injection
			local length = 0
			if regp1 then
				-- There still more regions. The length is inbetween the next and the previous.
				length = regp1[1] - reg[2] - 1
			else
				-- There are no more regions. The length is the last region and the total length of the region.
				length = target[3] - reg[2] - 1
			end

			if length > 0 then
				targetRegions[#targetRegions+1] = {"keep", length}
			end
		end
	end

	-- Make quads
	local yoff = 0
	for _, ymode in ipairs(vert) do
		local xoff = 0

		for _, xmode in ipairs(horz) do
			quads[#quads+1] = love.graphics.newQuad(subX + xoff, subY + yoff, xmode[2], ymode[2], textureWidth, textureHeight)
			xoff = xoff + xmode[2]
		end

		yoff = yoff + ymode[2]
	end

	local maxPadX = subX + subW
	local maxPadY = subY + subH
	local padX = math.max(self.padding[1] - subX, 0)
	local padY = math.max(self.padding[2] - subY, 0)
	local padW = maxPadX - math.min(self.padding[3] + 1, maxPadX)
	local padH = maxPadY - math.min(self.padding[4] + 1, maxPadY)

	return makeInstance(horz, vert, quads, {padX, padY, padW, padH})
end

---Create new 9-patch builder.
function n9p.newBuilder()
	return makeBuilder()
end

---@class n9p.LoadImageSetting: {[string]:any}
---@field public texture love.Texture? Existing texture to use instead of creating new one.
---@field public tile boolean? Whetever to tile the stretchable areas instead of stretching it.
---@field public subregion? {x:integer,y:integer,w:integer,h:integer} Subregion of the texture atlas.
---@field public criterion? fun(r:number,g:number,b:number,a:number):boolean Criterion function to detect stretchable and padding content area marker pixel.

---@param r number
---@param g number
---@param b number
---@param a number
local function defaultCriterion(r, g, b, a)
	return r == 0 and g == 0 and b == 0 and a > 0
end

---Create new 9-patch drawable image from image path or from ImageData.
---
---This function will automatically detect stretchable area and the padding box from the ImageData.
---* The returned stretchable image instance will have the texture assigned by creating new texture based on the
---  ImageData. If this is undesired, pass `{texture = existingTexture}` to the `settings` table.
---* The returned stretchable image instance will stretch by default. If tiling/repeating pattern is desired, pass
---  `{tile = true}` to the `settings` table.
---* Additionally, the rest of the key-values will be passed to `love.graphics.newImage` (if `texture` key is not set)
---
---For the `settings` table, there's also additional `subregion` that can be specified. This is useful if the actual
---.9.png is contained in the texture atlas (use in conjuction with `{texture = atlas}` in the settings table). This
---will ensure that only the subregion of the whole atlas is considered when making the quads instead of the whole
---atlas.
---
---Additionally, there's also `criterion` option for the `settings` field. This control on how to find stretchable
---pixel marker. By default, it checks for black pixels with opacity larger than 0. Useful if the `image` has `r8`
---pixel format and the actual image is specified using `{texture = existingTexture}` in the `settings` table.
---@param image love.ImageData|love.Data|love.File|string Path to image, or existing image data.
---@param settings table|n9p.LoadImageSetting? Additional key-value field  for this function and to be passed to `love.graphics.newImage`.
function n9p.loadFromImage(image, settings)
	--- Convert to ImageData
	if type(image) == "string" or (not image:typeOf("ImageData")) then
		image = love.image.newImageData(image) ---@diagnostic disable-line: param-type-mismatch
	end

	local dorepeat = false
	local criterion = defaultCriterion
	local targetTexture, subregionX, subregionY, subregionW, subregionH

	-- Populate advanced settings
	if settings then
		dorepeat = not not settings.tile
		criterion = settings.criterion or criterion
		targetTexture = settings.texture

		if settings.subregion then
			subregionX = settings.subregion.x
			subregionY = settings.subregion.y
			subregionW = settings.subregion.w
			subregionH = settings.subregion.h
		end
	end

	---@cast image love.ImageData
	local width, height = image:getDimensions()
	local imageWidth, imageHeight = width - 2, height - 2
	local builder = n9p.newBuilder()

	-- Iterate stretchable area
	for _, target in ipairs({
		{Builder.addHorizontalSlice, 1, 1, 0, imageWidth, 1},
		{Builder.addVerticalSlice, 2, 0, 1, 1, imageHeight},
	}) do
		local startRegion = 0
		local endRegion = 0
		local inRegion = false
		image:mapPixel(function(...)
			---@diagnostic disable-next-line: assign-type-mismatch
			local r, g, b, a = select(3, ...) ---@type number,number,number,number

			if criterion(r, g, b, a) then
				local value = select(target[2], ...)

				-- Black area
				if not inRegion then
					startRegion = value
					inRegion = true
				end

				endRegion = value
			elseif inRegion then
				inRegion = false
				target[1](builder, startRegion - 1, endRegion - 1, dorepeat)
			end

			-- Left unchanged
			return r, g, b, a
		end, target[3], target[4], target[5], target[6])

		-- Edge case if the whole region is marked
		if inRegion then
			target[1](builder, startRegion - 1, endRegion - 1, dorepeat)
		end
	end

	-- Iterate padding area
	for _, target in ipairs({
		{Builder.setHorizontalPadding, 1, 1, height - 1, imageWidth, 1},
		{Builder.setVerticalPadding, 2, width - 1, 1, 1, imageHeight},
	}) do
		local hasEverPadding = false
		local startRegion = 0
		local endRegion = 0

		image:mapPixel(function(...)
			---@diagnostic disable-next-line: assign-type-mismatch
			local r, g, b, a = select(3, ...) ---@type number,number,number,number

			if criterion(r, g, b, a) then
				local value = select(target[2], ...)

				-- Black area
				if not hasEverPadding then
					startRegion = value
					hasEverPadding = true
				end

				endRegion = value
			end

			-- Left unchanged
			return r, g, b, a
		end, target[3], target[4], target[5], target[6])

		if hasEverPadding then
			target[1](builder, startRegion, endRegion)
		end
	end

	if not targetTexture then
		-- Crop 1px border from source ImageData
		local otherImageData = love.image.newImageData(width - 2, height - 2, image:getFormat())
		otherImageData:paste(image, 0, 0, 1, 1, imageWidth, imageHeight)

		-- Create settings table for love.graphics.newImage
		local imageSettings
		if settings then
			imageSettings = {}
			-- Copy
			for k, v in pairs(settings) do
				imageSettings[k] = v
			end

			-- Unset our specific fields
			imageSettings.texture = nil
			imageSettings.tile = nil
			imageSettings.subregion = nil
			imageSettings.criterion = nil
		end

		targetTexture = love.graphics.newImage(otherImageData, imageSettings)
	end

	local textureWidth, textureHeight = targetTexture:getPixelDimensions()
	local instance = builder:build(textureWidth, textureHeight, subregionX, subregionY, subregionW, subregionH)
	instance:setTexture(targetTexture)
	return instance
end

return n9p
