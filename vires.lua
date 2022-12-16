-- Virtual Resolution System
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

local vires = {
	isInit = false, ---@package
	scale = 1, ---@package
}

---@param width integer
---@param height integer
---@param horizontalFreesize boolean?
---@param verticalFreesize boolean?
function vires.init(width, height, horizontalFreesize, verticalFreesize)
	vires.width = width ---@package
	vires.height = height ---@package
	vires.horizontalFreeSize = not not horizontalFreesize ---@package
	vires.verticalFreeSize = not not verticalFreesize ---@package
	vires.isInit = true ---@package
	return vires.update(0, 0, width, height, width, height)
end

---@param safeArea fun():(integer,integer,integer,integer)
---@param graphicsDimensions fun():(integer,integer)
function vires.updateByFunction(safeArea, graphicsDimensions)
	local x, y, w, h = safeArea()
	local gw, gh = graphicsDimensions()
	return vires.update(x, y, w, h, gw, gh)
end

---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param gw integer
---@param gh integer
function vires.update(x, y, w, h, gw, gh)
	assert(vires.isInit, "Virtual resolution is not initialized")

	local updated =
		x ~= vires.x or
		y ~= vires.y or
		w ~= vires.w or
		h ~= vires.h or
		gw ~= vires.gw or
		gh ~= vires.gh

	if updated then
		local scale = math.min(w / vires.width, h / vires.height)
		local offX = vires.horizontalFreeSize and x or ((w - scale * vires.width) / 2 + x)
		local offY = vires.verticalFreeSize and y or ((h - scale * vires.height) / 2 + y)

		vires.scale = scale ---@package
		vires.x = x ---@package
		vires.y = y ---@package
		vires.w = w ---@package
		vires.h = h ---@package
		vires.gw = gw ---@package 
		vires.gh = gh ---@package
		vires.offX = offX ---@package
		vires.offY = offY ---@package
	end
end

---Returns width and height. x and y always starts at 0.
function vires.getArea()
	assert(vires.isInit, "Virtual resolution is not initialized")
	local w = vires.horizontalFreeSize and (vires.w / vires.scale) or vires.width
	local h = vires.verticalFreeSize and (vires.h / vires.scale) or vires.height
	return w, h
end

---Returns all drawable area in form of x, y, width, and height relative to `vires.getArea()`
function vires.getFullscreenArea()
	assert(vires.isInit, "Virtual resolution is not initialized")
	local x = vires.offX / vires.scale
	local y = vires.offY / vires.scale
	local w = vires.gw / vires.scale
	local h = vires.gh / vires.scale
	return -x, -y, w, h
end

---@param currentDPIScale number?
---@nodiscard
function vires.getDPIScale(currentDPIScale)
	assert(vires.isInit, "Virtual resolution is not initialized")
	return vires.scale * (currentDPIScale or 1)
end

---@param x number
---@param y number
---@nodiscard
function vires.toLogical(x, y)
	assert(vires.isInit, "Virtual resolution is not initialized")
	local tx = (x - vires.offX) * vires.scale
	local ty = (y - vires.offY) * vires.scale
	return tx, ty
end

---@param tx number
---@param ty number
---@nodiscard
function vires.toPhysical(tx, ty)
	assert(vires.isInit, "Virtual resolution is not initialized")
	local x = tx / vires.scale + vires.offX
	local y = ty / vires.scale + vires.offY
	return x, y
end

function vires.calculateScissorArea(tx, ty, tw, th)
	assert(vires.isInit, "Virtual resolution is not initialized")
	local x1, y1 = vires.toPhysical(tx, ty)
	local x2, y2 = vires.toPhysical(tx + tw, ty + th)
	return x1, y1, x2 - x1, y2 - y1
end

---Apply transformation to LOVE environment. `vires` does not load `love` so you must pass `love` table.
---@param love love
function vires.apply(love)
	assert(vires.isInit, "Virtual resolution is not initialized")
	love.graphics.translate(vires.offX, vires.offY)
	love.graphics.scale(vires.scale)
end

---Helper function to balance safe areas between left and right.
---Returns the x and width of the balanced safe areas.
---@param x integer Safe area X.
---@param w integer Safe area width.
---@param gw integer Graphics width.
function vires.balanceSafeArea(x, w, gw)
	local x2 = gw - w
	local newX = math.max(x, x2)
	return newX, gw - newX * 2
end

return vires
