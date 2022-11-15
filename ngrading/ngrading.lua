-- NPad's Color Grading Library
--[[---------------------------------------------------------------------------
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
--]]---------------------------------------------------------------------------

local love = require("love")
assert(love._version >= "11.0", "ngrading require LOVE 11.0 or later")

local ngradingShader = {
old = [[
extern Image lut;
extern number cellPixels;
extern vec2 cellDimensions;

vec4 ngrading(vec4 texCol)
{
	number cdim = cellDimensions.x * cellDimensions.y - 1.0;
	number cw = cellPixels * cellDimensions.x;

	// Sampling must be done at 0.5-increments
	vec2 cpos = clamp(texCol.rg * cellPixels, 0.0, cellPixels - 1.0) + 0.5;
	number z = clamp(texCol.b * cdim, 0.0, cdim);
	number zf = fract(z);
	number zp = floor(z);

	// Calculate cell position
	vec2 tp1 = vec2(mod(zp, cellDimensions.x), floor(zp / cellDimensions.x)) * cellPixels + cpos;
	vec2 tp2 = vec2(mod((zp + 1.0), cellDimensions.x), floor((zp + 1.0) / cellDimensions.x)) * cellPixels + cpos;

	// Sample
	vec4 p1 = Texel(lut, tp1 / cw);
	vec4 p2 = Texel(lut, tp2 / cw);
	return vec4(mix(p1.rgb, p2.rgb, zf), texCol.a);
}

vec4 ngrading(Image tex, vec2 tc)
{
	return ngrading(Texel(tex, tc));
}
]],
volume = [[
extern VolumeImage lut;

vec4 ngrading(vec4 texCol)
{
	return vec4(Texel(lut, texCol.rgb).rgb, texCol.a);
}

vec4 ngrading(Image tex, vec2 tc)
{
	return ngrading(Texel(tex, tc));
}
]]
}

local defaultShaderEffect = [[
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	return ngrading(tex, tc) * color;
}
]]

local supportVolumeTextureChecked = nil
local loadedShader = {}

local defaultLUTLoadSetting = {linear = true, dpiscale = 1}

---@alias ngrading.Mode
---Tiled 2D texture.
---| "old"
---Volume texture.
---| "volume"

---@class ngrading
---@field private image love.Texture?
---@field private volumeImage love.Texture?
---@field private mode ngrading.Mode
---@field private pixelsPerCell integer?
---@field private tileDimensions {[1]:integer,[2]:integer}?
---@field private shader love.Shader
local ngrading = {
	_VERSION = "2.0.0",
	_AUTHOR = "MikuAuahDark",
	_LICENSE = "MIT"
}
ngrading.__index = ngrading

---@param type string
---@return love.Shader
local function getDefaultShaderByType(type)
	if not loadedShader[type] then
		local shader = (assert(ngradingShader[type])).."\n\n"..defaultShaderEffect
		loadedShader[type] = love.graphics.newShader(shader)
	end

	return loadedShader[type]
end

---@return boolean
local function isVolumeTextureSupported()
	if supportVolumeTextureChecked == nil then
		local supportVolume = love.graphics.getTextureTypes().volume
		-- LOVE before 11.3 returns number instead!
		if supportVolume == 0 then supportVolume = false end
		supportVolumeTextureChecked = supportVolume
	end

	return supportVolumeTextureChecked
end

---Create new `ngrading` object from specified RGB lookup-table.
---
---If `img` is `Texture`, the filter and wrap mode is **not** set. Setting the filter mode to `"linear"` and wrap mode
---to `"clamp"` is recommended for best results, but user must do this themselves!
---@param img string|love.ImageData|love.Texture RGB lookup-table image path or existing `ImageData` or existing `Texture`.
---@param pixelsPerCell integer? Width and height of single cell in pixels. Ignored for volume textures, required for `string` or `ImageData` or 2D textures.
---@nodiscard
function ngrading.load(img, pixelsPerCell)
	---@type love.ImageData|love.Texture
	local destination
	local isImageData

	if type(img) == "userdata" and img.typeOf then
		if img:typeOf("ImageData") then
			---@cast img love.ImageData
			destination = img
			isImageData = true
		elseif img:typeOf("Texture") then
			---@cast img love.Texture
			destination = img
			isImageData = false
		end
	else
		---@cast img string
		destination = love.image.newImageData(img)
		isImageData = true
	end

	local self = setmetatable({}, ngrading)

	-- If img is ImageData (or string): Check if VolumeTexture is supported
	-- If img is Texture: Depends on the image type
	if isImageData then
		---@cast destination love.ImageData
		if isVolumeTextureSupported() then
			-- Slice images
			assert(pixelsPerCell, "need pixels per cell")
			local tw = math.floor(destination:getWidth() / pixelsPerCell)
			local th = math.floor(destination:getHeight() / pixelsPerCell)
			local imgs = {}
			local fmt = destination:getFormat()

			for j = 0, th - 1 do
				for i = 0, tw - 1 do
					local nimg = love.image.newImageData(pixelsPerCell, pixelsPerCell, fmt)
					nimg:paste(destination, 0, 0, i * pixelsPerCell, j * pixelsPerCell, pixelsPerCell, pixelsPerCell)
					imgs[#imgs + 1] = nimg
				end
			end

			self.mode = "volume"
			self.volumeImage = love.graphics.newVolumeImage(imgs, defaultLUTLoadSetting)
			self.volumeImage:setFilter("linear", "linear")
			self.volumeImage:setWrap("clamp", "clamp", "clamp")
		else
			-- Just create image
			assert(pixelsPerCell, "need pixels per cell")
			self.mode = "old"
			self.tileDimensions = {
				math.floor(destination:getWidth() / pixelsPerCell),
				math.floor(destination:getHeight() / pixelsPerCell)
			}
			self.pixelsPerCell = pixelsPerCell
			self.image = love.graphics.newImage(destination, defaultLUTLoadSetting)
			self.image:setFilter("linear", "linear")
			self.image:setWrap("clamp", "clamp")
		end
	else
		---@cast destination love.Texture
		assert(destination:isReadable(), "texture is not readable")
		local type = destination:getTextureType()

		if type == "volume" then
			self.mode = "volume"
			self.volumeImage = destination
		elseif type == "2d" then
			assert(pixelsPerCell, "need pixels per cell")
			self.mode = "old"
			self.tileDimensions = {
				math.floor(destination:getWidth() / pixelsPerCell),
				math.floor(destination:getHeight() / pixelsPerCell)
			}
			self.pixelsPerCell = pixelsPerCell
			self.image = destination
		else
			error("invalid texture type '"..type.."'")
		end
	end

	self.shader = getDefaultShaderByType(self.mode)

	return self
end

---Prepares the shader to apply color LUT data.
---
---**This is a low-level function. Only use this if you plan on using custom shaders but with color grading!**
---@param shader love.Shader Shader to prepare the color grading data. Defaults to `love.graphics.getShader()` and error if there are no active shader.
function ngrading:setupShaderData(shader)
	shader = shader or assert(love.graphics.getShader(), "no shader set")

	if self.mode == "old" then
		shader:send("lut", self.image)
		shader:send("cellPixels", self.pixelsPerCell)
		shader:send("cellDimensions", self.tileDimensions)
	elseif self.mode == "volume" then
		shader:send("lut", self.volumeImage)
	end
end

---Set the shader to color grading shader. Any subsequent drawing will use the color grading shader. To disable it,
---call `love.graphics.setShader(othershader)` or `love.graphics.setShader()`.
---
---**This function replaces the current active shader to color grading shader!**
function ngrading:apply()
	love.graphics.setShader(self.shader)
	self:setupShaderData(self.shader)
end

---Get the internal shader string used for the color grading effect. The shader string contains this function
---```glsl
---vec4 ngrading(Image tex, vec2 textureCoords); // if you have Image texture
---vec4 ngrading(vec4 color); // if you have existing color values
---```
---Which can be concatenated with a custom shader.
---
---**This is a low-level function. Only use this if you plan on using custom shaders but with color grading!**
---@see ngrading.setupShaderData
function ngrading:getShader()
	assert(self, "ngrading.getShader is now a method function")
	return ngradingShader[self.mode]
end

function ngrading:getMode()
	return self.mode
end

return ngrading

--[[
Changelog:

v2.0.0: 2022-11-15
> Added support for generic Texture types as LUT tables.
> Changed ngading.getShader from static method to class method.

v1.0.2: 2021-01-03
> Add vec4 ngrading(vec4 color) variant to low-level shader code.

v1.0.1: 2020-05-15
> Always load LUT image with dpiscale = 1 and linear = true

v1.0.0: 2019-08-03
> Initial release.
]]
