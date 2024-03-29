-- NPad Audio Metadata Inspector
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

local nami = {
	_VERSION = "0.0.0",
	_AUTHOR = "MikuAuahDark",
	_LICENSE = "MIT"
}

local helper = {}

-----------------------
--- Helper routines ---
-----------------------

---@param str string
---@param be? boolean
---@param size? integer
function helper.str2uint(str, be, size)
	size = size or #str

	local value = 0

	if not be then
		str = str:sub(1, size):reverse()
	end

	for i = 1, size do
		local v = str:byte(i, i)
		value = value * 256 + v
	end

	return value
end

---Normalized read function
---@param io nami.IO
---@param opaque any
---@param size? integer
function helper.read(io, opaque, size)
	local result = io.read(opaque, size)

	if not result or #result < (size or #result) then
		return nil
	end

	return result
end

---Normalized seek function
---@param io nami.IO
---@param opaque any
---@param whence seekwhence
---@param offset? integer
function helper.seek(io, opaque, whence, offset)
	return io.seek(opaque, whence, offset)
end

function helper.getcstring(io, opaque)
	local s = {}

	while true do
		local b = helper.read(io, opaque, 1)
		if b and b ~= "\0" then
			s[#s + 1] = b
		else
			break
		end
	end

	return table.concat(s)
end

function helper.getbit(value, bitpos)
	return math.floor(value / (2 ^ bitpos)) % 2 == 1
end

---@param str string
---@param be? boolean
function helper.utf16to8(str, be)
	if be == nil then
		-- Determine by BOM
		local bom = str:sub(1, 2)

		if bom == "\254\255" then
			be = true
		elseif bom == "\255\254" then
			be = false
		end

		if be ~= nil then
			str = str:sub(3)
		end
	end

	local u8 = {}
	local skipNext = false

	for i = 1, #str, 2 do
		if skipNext then
			skipNext = false
		else
			local codestr = str:sub(i, i + 1)
			if #codestr < 2 then break end

			local code = helper.str2uint(codestr, be)

			-- For sake of simplicity, we're only handling surrogate pairs, not invalid ranges.
			if code >= 0xD800 and code <= 0xDBFF then
				local codestr2 = str:sub(i + 2, i + 3)
				if #codestr < 2 then break end

				local code2 = helper.str2uint(codestr2, be)
				if code2 >= 0xDC00 and code2 <= 0xDFFF then
					code = 0x10000 + (code - 0xD800) * 0x400 + code2 - 0xDC00
					skipNext = true
				else
					break
				end
			end

			-- Build codepoint
			if code <= 0x7F then
				u8[#u8 + 1] = string.char(code)
			elseif code <= 0x07FF then
				local a, b = string.char(
					math.floor(code / 64) + 192,
					code % 64 + 128
				)
				u8[#u8 + 1] = a
				u8[#u8 + 1] = b
			elseif code <= 0xFFFF then
				local a, b, c = string.char(
					math.floor(code / 4096) + 224,
					math.floor(code / 64) % 64 + 128,
					code % 64 + 128
				)
				u8[#u8 + 1] = a
				u8[#u8 + 1] = b
				u8[#u8 + 1] = c
			elseif code <= 0x10FFFF then
				local a, b, c, d = string.char(
					math.floor(code / 262144) + 240,
					math.floor(code / 4096) % 64 + 128,
					math.floor(code / 64) % 64 + 128,
					code % 64 + 128
				)
				u8[#u8 + 1] = a
				u8[#u8 + 1] = b
				u8[#u8 + 1] = c
				u8[#u8 + 1] = d
			end
		end
	end

	return table.concat(u8)
end

-- IMPORTANT: For this lookup table to work, this Lua script MUST be saved as UTF-8
helper.w1252lookup = {
	"€", nil, "‚", "ƒ", "„", "…", "†", "‡", "ˆ", "‰", "Š", "‹", "Œ", nil, "Ž", nil,
	nil, "‘", "’", "“", "”", "•", "–", "—", "˜", "™", "š", "›", "œ", nil, "ž", "Ÿ",
	"\192\160", "¡", "¢", "£", "¤", "¥", "¦", "§", "¨", "©", "ª", "«", "¬", "\194\173", "®", "¯",
	"°", "±", "²", "³", "´", "µ", "¶", "·", "¸", "¹", "º", "»", "¼", "½", "¾", "¿",
	"À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï",
	"Ð", "Ñ", "Ò", "Ó", "Ô", "Õ", "Ö", "×", "Ø", "Ù", "Ú", "Û", "Ü", "Ý", "Þ", "ß",
	"à", "á", "â", "ã", "ä", "å", "æ", "ç", "è", "é", "ê", "ë", "ì", "í", "î", "ï",
	"ð", "ñ", "ò", "ó", "ô", "õ", "ö", "÷", "ø", "ù", "ú", "û", "ü", "ý", "þ", "ÿ"
}

function helper.w1252toutf8(str)
	local result = {}

	for i = 1, #str do
		local b = str:byte(i, i)

		if b >= 127 then
			local new = helper.w1252lookup[b - 127]

			if new then
				result[#result + 1] = new
			end
		else
			result[#result + 1] = str:sub(i, i)
		end
	end

	return table.concat(result)
end

------------------------------------
--- ID3-specific helper routines ---
------------------------------------

---@param str string
---@param size integer
---@param full32 boolean
function helper.id3str2uint(str, size, full32)
	size = size or #str

	local value = 0

	if full32 then
		for i = 1, size do
			local v = str:byte(i, i)
			value = value * 256 + v
		end
	else
		for i = 1, size do
			local v = str:byte(i, i) % 128
			value = value * 128 + v
		end
	end

	return value
end

---@param encoding '0'|'1'|'2'|'3'
---@param str string
function helper.id3strdecode(encoding, str)
	---@type string
	local result

	if encoding == 0 then
		result = helper.w1252toutf8(str)
	elseif encoding == 1 then
		result = helper.utf16to8(str)
	elseif encoding == 2 then
		result = helper.utf16to8(str, true)
	elseif encoding == 3 then
		result = str
	end

	if result and result:sub(-1) == "\0" then
		result = result:sub(1, -2)
	end

	return result
end

helper.id3textremap = {
	TALB = "album",
	TCOM = "composer",
	TCON = "genre",
	TCOP = "copyright",
	TENC = "encoded_by",
	TIT2 = "title",
	TLAN = "language",
	TPE1 = "artist",
	TPE2 = "album_artist",
	TPE3 = "performer",
	TPOS = "disc",
	TPUB = "publisher",
	TRCK = "track",
	TSSE = "encoder",
}

function helper.id3canaccepttext(frame)
	return not not helper.id3textremap[frame]
end

---@param frame string
---@param backend nami.IO
function helper.id3decodetextframe(frame, backend, opaque)
	local index = assert(helper.id3textremap[frame])
	local encoding = helper.read(backend, opaque, 1)
	if not encoding then
		return nil
	end

	return helper.id3strdecode(encoding:byte(), helper.read(backend, opaque)), index
end

function helper.id3validtag(txt)
	if #txt == 4 then
		for i = 1, 4 do
			local b = txt:byte(i, i)
			if (b < 65 or b > 90) and (b < 48 or b > 57) then
				return false
			end
		end

		return true
	end

	return false
end

-------------------------------
--- Vorbis-specific helpers ---
-------------------------------

helper.vbcommremap = {
	ALBUMARTIST = "album_artist",
	TRACKNUMBER = "track",
	DISCNUMBER = "disc",
	DESCRIPTION = "comment"
}

---@param str string
function helper.vbgetkeyvalue(str)
	local equals = str:find("=", 1, true)
	if not equals then return nil end

	local key = str:sub(1, equals - 1)
	local value = str:sub(equals + 1)

	return helper.vbcommremap[key] or key:lower(), value
end

--------------------------------
--- Zlib decompress function ---
--------------------------------

local function defaultZlibDecompress(data)
	error("zlib decompress is not supported, please provide one with nami.setZlibDecompressFunction")
end

local namiZlibDecompress = defaultZlibDecompress

function nami.setZlibDecompressFunction(func)
	namiZlibDecompress = func or defaultZlibDecompress
end

----------------------------
--- Backend Registration ---
----------------------------

local luaFileMt = getmetatable(io.stdout)

---@class nami.IO
local namiLuaIo = {
	---Read from stream of specified size.
	---@param opaque any User data returned from probe function.
	---@param size? integer Amount to read or nil for all.
	---@return string @Readed data, or nil on EOF.
	read = function(opaque, size)
		return opaque:read(size or "*a")
	end,
	---Seek stream.
	---
	---If it's asking the current position, `whence` is `"cur"` and `offset` is `0`.
	---@param opaque any User data returned from probe function.
	---@param whence seekwhence
	---@param offset integer?
	---@return integer @New stream position or nil on failure.
	seek = function(opaque, whence, offset)
		return opaque:seek(whence, offset)
	end,
	---Function that determine if this IO can handle such data
	---@param data any
	---@return any @New opaque object or nil if this IO can't handle such data.
	probe = function(data)
		if getmetatable(data) == luaFileMt then
			return data
		end

		return nil
	end
}

---@type nami.IO
local namiStringIO = {
	read = function(opaque, size)
		if opaque[2] >= #opaque[1] then
			return nil
		end

		size = size or #opaque[1]
		local result = opaque[1]:sub(opaque[2] + 1, opaque[2] + size)
		opaque[2] = opaque[2] + #result
		return result
	end,
	seek = function(opaque, whence, offset)
		local base

		if whence == "set" then
			base = 0
		elseif whence == "cur" then
			base = opaque[2]
		elseif whence == "end" then
			base = #opaque[1]
		end

		local pos = math.min(math.max(base + (offset or 0), 0), #opaque[1])
		opaque[2] = pos
		return pos
	end,
	probe = function(data)
		if type(data) == "string" then
			return {data, 0}
		end

		return nil
	end
}

-- List of IO backends.
---@type nami.IO[]
local namiIOBackends = {}

function nami.getLuaIOBackend()
	return namiLuaIo
end

function nami.getStringIOBackend()
	return namiStringIO
end

---Register IO backend.
---@param backend nami.IO Backend table to register.
---@return boolean @Backend successfully registered?
function nami.registerBackend(backend)
	for _, v in ipairs(namiIOBackends) do
		if v == backend then
			return false
		end
	end

	namiIOBackends[#namiIOBackends + 1] = backend
	return true
end

---Unregister IO backend.
---@param backend nami.IO Backend table to unregister.
---@return boolean @Backend successfully unregistered?
function nami.unregisterBackend(backend)
	for i, v in ipairs(namiIOBackends) do
		if v == backend then
			table.remove(namiIOBackends, i)
			return true
		end
	end

	return false
end

nami.registerBackend(namiLuaIo)
nami.registerBackend(namiStringIO)

-- If running under LOVE environment, register love.filesystem backend
if rawget(_G, "love") then
	local love = require("love")
	local loveFileMt = getmetatable(love.filesystem.newFile(""))

	---@type nami.IO
	local namiLoveFilesystem = {
		read = function(opaque, size)
			local result

			if size == nil then
				result = opaque:read("string")
			else
				result = opaque:read("string", size)
			end

			if not result or #result == 0 then
				return nil
			end

			return result
		end,
		seek = function(opaque, whence, offset)
			local base

			if whence == "set" then
				base = 0
			elseif whence == "cur" then
				base = opaque:tell()
			elseif whence == "end" then
				base = opaque:getSize()
			end

			local result = opaque:seek(base + (offset or 0))
			if result then
				return opaque:tell()
			end

			return nil
		end,
		probe = function(data)
			if getmetatable(data) == loveFileMt then
				return data
			end

			return nil
		end
	}

	function nami.getLoveFilesystemIOBackend()
		return namiLoveFilesystem
	end

	nami.registerBackend(namiLoveFilesystem)
	nami.setZlibDecompressFunction(function(data)
		return love.data.decompress("string", "zlib", data)
	end)
end

---@class nami.Metadata
---@field public metadata table<string, number|string> Audio metadata with normalized keys.
---@field public coverArt string Cover art, if available.

---@param opaque any
---@param header string
---@param backend nami.IO
---@return nami.Metadata
local function parseID3(opaque, header, backend)
	-- ID3 tag reference can be found here: https://id3.org/id3v2.4.0-structure
	-- Read ID3v2 header data
	local version = helper.str2uint(header:sub(4)..assert(helper.read(backend, opaque, 1), "Unexpected EOF"), false)
	if version >= 255 then
		error("Invalid ID3 version")
	end

	local flags = helper.str2uint(assert(helper.read(backend, opaque,  1), "Unexcepted EOF"), false)
	local dataSize = helper.id3str2uint(assert(helper.read(backend, opaque,  4), "Unexcepted EOF"), nil, false)
	local dataStream = namiStringIO.probe(assert(helper.read(backend, opaque,  dataSize), "Unexcepted EOF"))

	-- Get ID3v2 important bits
	local extHeader = helper.getbit(flags, 6)

	if extHeader then
		-- We don't need extended header for now.
		local extHeaderSize = helper.id3str2uint(
			assert(helper.read(namiStringIO, dataStream,  4), "Insufficient ID3 data"), nil, false
		)

		if version >= 4 then
			-- In v2.4 the length is +4.
			extHeaderSize = extHeaderSize - 4
		end

		assert(extHeaderSize >= 2, "Invalid ID3 extended header size")
		namiStringIO.seek(dataStream, "cur", extHeaderSize) -- Always success
		dataSize = dataSize - extHeaderSize - 4
	end

	local metadata = {}
	local coverArt
	local full32 = nil

	-- Read ID3 frames
	-- https://id3.org/id3v2.4.0-frames
	while dataSize > 0 do
		-- Read frame FourCC
		local frame = helper.read(namiStringIO, dataStream,  4)
		if not frame then break end

		-- Read frame size
		local frameSizeStr = helper.read(namiStringIO, dataStream, 4)
		if not frameSizeStr then break end

		if full32 == nil then
			if version == 3 then
				-- ID3v2.3 uses full 32-bit
				full32 = true
			else
				-- Some non-compilant ID3v2 tagger uses full 32-bit instead of
				-- ID3v2.4-documented synchsafe integer. So check for this!
				-- Thanks to FFmpeg source code for the checking idea
				local size28 = helper.id3str2uint(frameSizeStr, nil, false)
				local size32 = helper.id3str2uint(frameSizeStr, nil, true)

				if size32 >= 127 then
					local current = helper.seek(namiStringIO, dataStream, "cur")
					if helper.seek(namiStringIO, dataStream, "cur", size32 + 2) then
						-- Try to read tag
						local tag = helper.read(namiStringIO, dataStream, 4)
						if tag and helper.id3validtag(tag) then
							-- Ok, full 32-bit integer is used
							full32 = true
						elseif helper.seek(namiStringIO, dataStream, "set", current + 2 + size28) then
							-- Probably not, use synchsafe but don't assume
							tag = helper.read(namiStringIO, dataStream, 4)
							if tag and helper.id3validtag(tag) then
								-- Ok, synchsafe integer is used
								full32 = false
							end
						end
					end
				end
			end
		end

		local frameSize = helper.id3str2uint(frameSizeStr, nil, full32)

		-- Read frame flags
		local frameFlagsStr = helper.read(namiStringIO, dataStream, 2)
		if not frameSizeStr then break end
		local frameFlags = helper.str2uint(frameSizeStr, true)

		-- Frame flags
		local hasGroup = helper.getbit(frameFlags, 6)
		local isCompressed = helper.getbit(frameFlags, 3)
		local isEncrypted = helper.getbit(frameFlags, 2)
		local isUnsynced = helper.getbit(frameFlags, 1)
		local hasDataLength = helper.getbit(frameFlags, 0)

		if isEncrypted or hasGroup or isCompressed or isUnsynced or hasDataLength then
			-- FIXME: Support everything except isEncrypted
			namiStringIO.seek(dataStream, "cur", frameSize)
		else
			local frameDataStr = helper.read(namiStringIO, dataStream, frameSize)
			local frameData = namiStringIO.probe(frameDataStr)

			if frame == "COMM" then
				-- Comment frame
				local encoding = math.min(helper.read(namiStringIO, frameData, 1):byte(), 3)
				local language = helper.read(namiStringIO, frameData, 3) -- unused
				local commentData = helper.read(namiStringIO, frameData)
				local actualComment

				if commentData then
					-- Decode comment data
					local multiByteCommentData = helper.id3strdecode(encoding, commentData)

					-- Find one null byte
					local nullpos = multiByteCommentData:find("\0", 1, true)

					if nullpos then
						actualComment = multiByteCommentData:sub(nullpos + 1)
					else
						actualComment = multiByteCommentData
					end

					if actualComment:sub(-1) == "\0" then
						actualComment = actualComment:sub(1, -2)
					end

					metadata.comment = actualComment

					if metadata.comment then
						-- ID3 says line ending must be in \n
						metadata.comment = metadata.comment:gsub("\r\n", "\n")
					end
				end
			elseif frame == "APIC" then
				-- Cover art
				local encoding = math.min(helper.read(namiStringIO, frameData, 1):byte(), 3)
				local mime = helper.getcstring(namiStringIO, frameData)
				local type = helper.read(namiStringIO, frameData, 1)
				local desc = helper.getcstring(namiStringIO, frameData)

				if type == "\3" and not coverArt then
					coverArt = helper.read(namiStringIO, frameData)
				end
			elseif helper.id3canaccepttext(frame) then
				local text, index = helper.id3decodetextframe(frame, namiStringIO, frameData)
				metadata[index] = text
			end
		end
	end

	return {metadata = metadata, coverArt = coverArt}
end

---@param opaque any
---@param backend nami.IO
---@return nami.Metadata
local function parseFLAC(opaque, backend)
	local endOfMetadata = false
	local foundStreamInfo = false

	local metadata = {}
	local coverArt

	repeat
		local blockHeaderData = assert(helper.read(backend, opaque, 1), "Unexpected EOF"):byte()
		local blockType = blockHeaderData % 128
		endOfMetadata = helper.getbit(blockHeaderData, 7)

		assert(blockType ~= 127, "Invalid block type")

		-- Sanity check
		if blockType == 0 then
			assert(not foundStreamInfo, "Found another STREAMINFO block")
			foundStreamInfo = true
		end

		assert(foundStreamInfo, "STREAMINFO block is not first block")
		local length = helper.str2uint(assert(helper.read(backend, opaque, 3), "Unexpected EOF"), true)

		if blockType == 4 then
			-- Vorbis comments
			local vendorLength = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), false)
			local vendorName = helper.read(backend, opaque, vendorLength) -- unused
			local metadataCount = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), false)

			for _ = 1, metadataCount do
				local len = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), false)
				local data = assert(helper.read(backend, opaque, len), "Unexpected EOF")
				local k, v = helper.vbgetkeyvalue(data)

				if k and v then
					metadata[k] = v
				end
			end
		elseif blockType == 6 then
			-- Picture
			local type = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), true)

			if type == 3 and not coverArt then
				local mimeLength = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), true)
				assert(helper.seek(backend, opaque, "cur", mimeLength), "Unexpected EOF")
				local descLength = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), true)
				-- +16 for the unnecessary informations
				assert(helper.seek(backend, opaque, "cur", descLength + 16), "Unexpected EOF")
				local imageLength = helper.str2uint(assert(helper.read(backend, opaque, 4), "Unexpected EOF"), true)
				coverArt = helper.read(backend, opaque, imageLength)
			else
				-- Skip
				if not helper.seek(backend, opaque, "cur", length - 4) then
					break
				end
			end
		else
			-- Skip
			if not helper.seek(backend, opaque, "cur", length) then
				break
			end
		end
	until endOfMetadata

	return {metadata = metadata, coverArt = coverArt}
end

---Retrieve audio metadata.
---@param data any The audio data/file.
---@param backend? nami.IO IO backend to use (without `probe` function). `nil` means suitable backend will be used.
function nami.getMetadata(data, backend)
	local opaque

	-- Resolve backend
	if backend == nil then
		for _, v in ipairs(namiIOBackends) do
			opaque = v.probe(data)

			if opaque then
				backend = v
				break
			end
		end

		if opaque == nil then
			return nil, "No suitable IO backend found"
		end
	else
		opaque = data
	end

	local header = helper.read(backend, opaque, 4)
	if not header then
		return nil, "Unexpected EOF"
	end

	local status, result = false, "Unknown file"

	if header:sub(1, 3) == "ID3" then
		status, result = pcall(parseID3, opaque, header, backend)
	elseif header == "fLaC" then
		status, result = pcall(parseFLAC, opaque, backend)
	end

	if status and result then
		return result
	else
		return nil, result
	end
end

return nami
