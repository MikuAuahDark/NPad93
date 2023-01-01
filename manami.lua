-- Manami, library to show text in parts.
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

local love = require("love")
local utf8 = require("utf8")

local hasClear, clear = pcall(require, "table.clear")
if not hasClear then
	---@param tab table
	function clear(tab)
		for k, v in pairs(tab) do
			tab[k] = nil
		end
	end
end

---@alias manami.colort {[1]:number,[2]:number,[3]:number,[4]:number?}
---@alias manami.coloredtext (manami.colort|string)[]

local COLOR_TRANSPARENT = {0, 0, 0, 0}
local COLOR_WHITE = {1, 1, 1}

---@param s string
local function oneByOneSeparator(s)
	return 1
end

---@param sep string
local function splitSeparator(sep)
	---@param s string
	return function(s)
		local start = s:find(sep, #sep, true)
		return utf8.len(s, 1, start or #s) or #s
	end
end

---@param s string
local function defaultLengthCalc(s)
	return utf8.len(s) or 1
end

---@param str string
---@param i integer
---@param j integer?
local function utf8sub(str, i, j)
    local s = assert(utf8.offset(str, i))
	---@cast s integer
	local e

	if j then
		e = utf8.offset(str, j + 1) - 1
	end

	return str:sub(s, e)
end

---`i` are in bytes, not UTF-8 chars.
---@param coloredText (manami.colort|string)[]
---@param i integer
---@return manami.coloredtext
local function substringColored(coloredText, i)
	local result = {}
	local counter = 0

	if i >= 1 then
		-- Find end index
		local endIndex, endPos
		for k = 2, #coloredText, 2 do
			---@type string
			---@diagnostic disable-next-line: assign-type-mismatch
			local text = coloredText[k]
			counter = counter + #text
			if i < counter then
				-- Somewhere in here
				endIndex = k
				endPos = i - counter - 1
				break
			end
		end

		if not endIndex then
			endIndex = #coloredText
			endPos = #coloredText[endIndex]
		end

		-- Insert
		for k = 2, endIndex - 2, 2 do
			result[#result + 1] = coloredText[k - 1]
			result[#result + 1] = coloredText[k]
		end

		-- Last index
		result[#result + 1] = coloredText[endIndex - 1]
		result[#result + 1] = coloredText[endIndex]:sub(1, endPos)
	end

	return result
end

---@class manami
---@field private align love.AlignMode
---@field private font love.Font
---@field private limit number
---@field private position number
local manami = {}
manami._AUTHOR = "Miku AuahDark"
manami._VERSION = "1.0.0"
manami._LICENSE = "MIT"
manami.__index = manami ---@private

---@param text string|manami.coloredtext
---@param limit number
---@param align love.AlignMode?
---@param font love.Font?
---@param separator? string|fun(s:string):integer separator character or function that returns n UTF-8 characters to consume.
---@param lengthCalc? fun(s:string):number
function manami:new(text, limit, align, font, separator, lengthCalc)
	assert(#text > 0, "text is empty")

	local coloredText
	local separatorFunc
	lengthCalc = lengthCalc or defaultLengthCalc

	if type(separator) == "string" then
		separatorFunc = splitSeparator(separator)
	else
		separatorFunc = separator or oneByOneSeparator
	end

	if type(text) == "table" then
		coloredText = text
	else
		---@type manami.coloredtext
		coloredText = {COLOR_WHITE, text}
	end

	local allString = {}
	---@private
	---@type {start:number,string:manami.coloredtext,text:love.Text?}[]
	self.textData = {}
	self.font = font or love.graphics.getFont()
	self.limit = limit
	self.align = align or "left"
	self.position = 0

	for i = 2, #coloredText, 2 do
		allString[#allString + 1] = coloredText[i]
	end

	local fullString = table.concat(allString)
	local unprocessed = fullString
	local pos = 0
	local nextPos = 1
	while #unprocessed > 0 do
		print("a")
		local separateCount = separatorFunc(unprocessed)
		assert(separateCount > 0, "amount of characters to consume cannot be 0")
		print("b", separateCount)
		local separatedString = utf8sub(unprocessed, 1, separateCount)
		local length = lengthCalc(separatedString)

		pos = pos + length
		nextPos = nextPos + separateCount

		-- TODO: Optimize so it only renders up to next 2 lines
		local substr = substringColored(coloredText, (utf8.offset(fullString, nextPos)) - 1)
		unprocessed = utf8sub(unprocessed, separateCount + 1)
		substr[#substr + 1] = COLOR_TRANSPARENT
		substr[#substr + 1] = unprocessed
		self.textData[#self.textData + 1] = {
			start = pos,
			string = substr
		}
	end
end

---Retrieve the total duration needed to display all text in _time units_.
---Setting position to the value returned by this value will result in all text
---being shown.
function manami:getDuration()
	return self.textData[#self.textData].start
end

---Retrieve the current duration of the displayed text in _time units_.
function manami:getPosition()
	return self.position
end

---Set new progress value of the text such that it displays at certain progress.
---Setting this to 0 means no text will be displayed and setting this to
---`:getDuration()` means all text is displayed.
---@param pos number New duration in _time units_.
function manami:setPosition(pos)
	self.position = math.min(pos, self:getDuration())
end

---Shorthand of
---```lua
---manami:setPosition(manami:getPosition() + dpos)
---```
---@param dpos number
function manami:updatePosition(dpos)
	self.position = math.min(self.position + dpos, self:getDuration())
end

---Changes text rendering mechanism from `love.graphics.printf` to `Text` object.
---This is one-time function. Once called, can't be disabled for the whole lifetime
---of the object.
function manami:buildTextCache()
	for _, v in ipairs(self.textData) do
		local text = love.graphics.newText(self.font)
		text:addf(v.string, self.limit, self.align, 0, 0)
		v.text = text
	end
end

---Display the text.
---@param x? number
---@param y? number
---@param r? number
---@param sx? number
---@param sy? number
---@param ox? number
---@param oy? number
---@param kx? number
---@param ky? number
---@overload fun(self:manami,transform:love.Transform)
function manami:print(x, y, r, sx, sy, ox, oy, kx, ky)
	local first, last = self.textData[1], self.textData[#self.textData]
	local target

	-- Out of range
	if self.position < first.start then
		return
	end

	if self.position >= last.start then
		target = last
	else
		-- Binary search
		local i, j = 1, #self.textData
		while i <= j do
			local m = math.floor((i + j) / 2)
			local t = self.textData[m]

			if self.position < t.start then
				j = m
			elseif self.position >= t.start then
				if self.position < self.textData[m + 1].start then
					target = t
					break
				end

				i = m
			end
		end

		assert(target)
	end

	if target.text then
		love.graphics.draw(target.text, x, y, r, sx, sy, ox, oy, kx, ky)
	else
		if type(x) == "userdata" and x.typeOf and x:typeOf("Transform") then
			---@diagnostic disable-next-line: cast-type-mismatch
			---@cast x love.Transform
			love.graphics.printf(target.string, self.font, x, self.limit, self.align)
		else
			love.graphics.printf(target.string, self.font, x or 0, y or 0, self.limit, self.align, r, sx, sy, ox, oy, kx, ky)
		end
	end
end

setmetatable(manami, {
	__call = function(_, text, limit, align, lengthCalc, separator)
		local object = setmetatable({}, manami)
		object:new(text, limit, align, lengthCalc, separator)
		return object
	end
})
---@cast manami +fun(text:string|manami.coloredtext,limit:number,align?:love.AlignMode,font?:love.Font,separator?:string|(fun(s:string):integer),lengthCalc?:fun(s:string):number):manami

---An alternative reflowprint-compatible API that displays text one-by-one.
---@param i number|{progress:number,text:string,x:number,y:number,w:number,a:love.AlignMode,sx:number,sy:number}
---@param text string
---@param x number
---@param y number
---@param w number
---@param a love.AlignMode?
---@param sx number?
---@param sy number?
function manami.reflowprint(i, text, x, y, w, a, sx, sy)
	if type(i) == "table" then
		text = i.text
		x = i.x
		y = i.y
		w = i.w
		a = i.a
		sx = i.sx
		sy = i.sy
		i = i.progress
	end

	local obj = manami(text, w, a)
	obj:setPosition(obj:getDuration() * i)
	obj:print(x, y, 0, sx, sy)
end

return manami
