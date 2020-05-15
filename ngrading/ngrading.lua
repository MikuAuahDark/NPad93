-- NPad's Color Grading Library
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

local love = require("love")
assert(love._version >= "11.0", "ngrading require LOVE 11.0 or later")

local ngradingShader = {}
ngradingShader.old = [[
extern Image lut;
extern number cellPixels;
extern vec2 cellDimensions;

vec4 ngrading(Image tex, vec2 tc)
{
	number cdim = cellDimensions.x * cellDimensions.y - 1.0;
	number cw = cellPixels * cellDimensions.x;
	vec4 texCol = Texel(tex, tc);

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
]]

ngradingShader.volume = [[
extern VolumeImage lut;

vec4 ngrading(Image tex, vec2 tc)
{
	vec4 texCol = Texel(tex, tc);
	return vec4(Texel(lut, texCol.rgb).rgb, texCol.a);
}
]]

local defaultShaderEffect = [[
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	return ngrading(tex, tc) * color;
}
]]

local defaultShader
local defaultShaderObject
local usedShader

local defaultLUTLoadSetting = {linear = true, dpiscale = 1}

local ngrading = {_VERSION = "1.0.1",}
ngrading.__index = ngrading

local function getUsedShader()
	if usedShader == nil then
		usedShader = love.graphics.getTextureTypes().volume
		-- LOVE before 11.3 returns number instead!
		if usedShader == 0 then usedShader = false end
		usedShader = usedShader and "volume" or "old"
	end

	if defaultShader == nil then
		assert(usedShader)
		defaultShader = string.format("%s\n\n%s", ngradingShader[usedShader], defaultShaderEffect)
	end

	return usedShader, defaultShader
end

function ngrading.load(img, pixelsPerCell)
	local imageData
	if type(img) == "userdata" and img.typeOf and img:typeOf("ImageData") then
		imageData = img
	else
		imageData = love.image.newImageData(img)
	end

	local tw = math.floor(imageData:getWidth() / pixelsPerCell)
	local th = math.floor(imageData:getHeight() / pixelsPerCell)

	local self = setmetatable({}, ngrading)
	self.tileDimensions = {tw, th}
	self.pixelsPerCell = pixelsPerCell

	if getUsedShader() == "volume" then
		-- slice images
		local imgs = {}
		local fmt = imageData:getFormat()

		for j = 0, th - 1 do
			for i = 0, tw - 1 do
				local nimg = love.image.newImageData(pixelsPerCell, pixelsPerCell, fmt)
				nimg:paste(imageData, 0, 0, i * pixelsPerCell, j * pixelsPerCell, pixelsPerCell, pixelsPerCell)
				imgs[#imgs + 1] = nimg
			end
		end

		self.volumeImage = love.graphics.newVolumeImage(imgs, defaultLUTLoadSetting)
		self.volumeImage:setFilter("linear", "linear")
		self.volumeImage:setWrap("clamp", "clamp", "clamp")
	else
		-- Just create image
		self.image = love.graphics.newImage(imageData, defaultLUTLoadSetting)
		self.image:setFilter("linear", "linear")
		self.image:setWrap("clamp", "clamp")
	end

	if defaultShaderObject == nil then
		defaultShaderObject = love.graphics.newShader(select(2, getUsedShader()))
	end

	return self
end

-- low-level function
function ngrading.getShader()
	return ngradingShader[getUsedShader()]
end

function ngrading:setupShaderData(shader)
	shader = shader or assert(love.graphics.getShader(), "no shader set")

	if self.image then
		shader:send("lut", self.image)
		shader:send("cellPixels", self.pixelsPerCell)
		shader:send("cellDimensions", self.tileDimensions)
	else
		shader:send("lut", self.volumeImage)
	end
end

-- this overwrite current shader, high-level function
function ngrading:apply()
	love.graphics.setShader(defaultShaderObject)
	self:setupShaderData(defaultShaderObject)
end

return ngrading
