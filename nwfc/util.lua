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

local util = {}

function util.random(a, r)
	local sum = 0
	for i = 1, #a do
		sum = sum + a[i]
	end

	for i = 1, #a do
		a[i] = a[i] / sum
	end

	local i = 1
	local x = 0

	while i <= #a do
		x = x + a[i]
		if r <= x then
			return i - 1
		end
		i = i + 1
	end

	return 0
end

function util.colorToNumber(r, g, b, a)
	return r * 16777216 + g * 65536 + b * 256 + a
end

function util.colorFromNumber(n)
	return
		math.floor(n / 16777216) % 256,
		math.floor(n / 65536) % 256,
		math.floor(n / 256) % 256,
		n % 256
end

function util.contains(a, b)
	for _, v in ipairs(a) do
		if v == b then
			return true
		end
	end

	return false
end

function util.splitString(str, chr)
	local ret = {}
	local pos = 1

	if str then
		while true do
			local fpos = string.find(str, chr, pos, true)
			if fpos == nil then
				ret[#ret + 1] = str:sub(pos)
				break
			end

			local sub = str:sub(pos, fpos - 1)
			if #sub > 0 then
				ret[#ret + 1] = sub
			end

			pos = fpos + #chr
		end
	end

	return ret
end

return util
