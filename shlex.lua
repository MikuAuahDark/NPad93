local shlex = {}

if false then
---@class Shlex.IReadableFile
local IReadableFile = {}

---@param n integer
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function IReadableFile:read(n)
	return ""
end

---@param l '"*l"'
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function IReadableFile:read(l)
	return ""
end

---@param whence seekwhence?
---@param offset integer?
function IReadableFile:seek(whence, offset)
	return 0
end

function IReadableFile:close()
end
end

---@param string string
---@param what string
---@param replacement string
local function replace(string, what, replacement)
	local whatReplace = what:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
	return (string:gsub(whatReplace, replacement))
end

---@class Shlex.StringStream: Shlex.IReadableFile
local StringStream = {}
StringStream.__index = StringStream

---@param str string
function StringStream:new(str)
	self.data = str
	self.pos = 0
end

function StringStream:read(n)
	if self.pos >= #self.data then
		return nil
	end

	if n == "*l" then
		local newline = self.data:find("\n", self.pos + 1, true)
		local line

		if newline then
			line = self.data:sub(self.pos + 1, newline - 1)
			self.pos = newline
		else
			line = self.data:sub(self.pos + 1)
			self.pos = #self.data
		end

		if line:sub(-1) == "\r" then
			line = line:sub(1, -2)
		end

		return line
	else
		---@cast n integer
		local data = self.data:sub(self.pos + 1, self.pos + n)
		self.pos = self.pos + n
		return data
	end
end

function StringStream:close()
end

function StringStream:__tostring()
	return self.data
end

setmetatable(StringStream, {__call = function(_, data)
	local test = setmetatable({}, StringStream)
	test:new(data)
	return test
end})
---@cast StringStream +fun(str:string):Shlex.StringStream

---@class Shlex.Shlex
local Shlex = {}
Shlex.__index = Shlex

---@param instream file*|Shlex.IReadableFile|string
---@param infile string?
---@param posix boolean?
---@param punctuation boolean|string?
function Shlex:new(instream, infile, posix, punctuation)
	if type(instream) == "string" then
		instream = StringStream(instream)
	end

	if instream then
		self.instream = instream
		self.infile = infile
	else
		self.instream = io.stdin
		self.infile = nil
	end

	self.posix = not not posix
	if self.posix then
		self.eof = nil
	else
		self.eof = ""
	end

	self.commenters = '#'
	self.wordchars = "abcdfeghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	if self.posix then
		self.wordchars = self.wordchars .. "ßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ"
	end

	self.whitespace = " \t\r\n"
	self.whitespace_split = false
	self.quotes = "'\""
	self.escape = "\\"
	self.escapedquotes = "\""
	self.state = " "
	---@type string[]
	self.pushback = {}
	self.lineno = 1
	self.debug = 0
	self.token = ""
	---@type {[1]:string?,[2]:Shlex.IReadableFile,[3]:integer}[]
	self.filestack = {}
	self.source = nil

	local punctuation_chars
	if not punctuation or punctuation == "" then
		punctuation_chars = ""
	elseif punctuation then
		punctuation_chars = "();<>|&"
	else
		---@cast punctuation string
		punctuation_chars = punctuation
	end
	self.punctuation_chars = punctuation_chars

	if #punctuation_chars > 0 then
		-- _pushback_chars is a push back queue used by lookahead logic
		self._pushback_chars = {}
		-- these chars added because allowed in file names, args, wildcards
		self.wordchars = self.wordchars .. "~-./*?="
		-- remove any punctuation chars from wordchars
		for i = 1, #punctuation_chars do
			self.wordchars = replace(self.wordchars, punctuation_chars:sub(i, i), "")
		end
	end
end

---Push a token onto the stack popped by the get_token method
---@param tok string
function Shlex:push_token(tok)
	if self.debug >= 1 then
		print(string.format("shlex: pushing token %q", tok))
	end

	self.pushback[#self.pushback + 1] = tok
end

---Push an input source onto the lexer's input source stack.
---@param newstream file*|Shlex.IReadableFile|string
---@param newfile string?
function Shlex:push_source(newstream, newfile)
	if type(newstream) == "string" then
		newstream = StringStream(newstream)
	end

	self.filestack[#self.filestack + 1] = {self.infile, self.instream, self.lineno}
	self.infile = newfile
	self.instream = newstream
	self.lineno = 1

	if self.debug > 0 then
		if newfile then
			print("shlex: pushing to file "..self.infile)
		else
			print("shlex: pushing to stream "..tostring(self.instream))
		end
	end
end

---Pop the input source stack.
function Shlex:pop_source()
	self.instream:close()

	local filestack = self.filestack[#self.filestack]
	self.filestack[#self.filestack] = nil
	self.infile, self.instream, self.lineno = filestack[1], filestack[2], filestack[3]

	if self.debug > 0 then
		print("shlex: popping to "..tostring(self.instream)..", line "..self.lineno)
	end

	self.state = " "
end

---Get a token from the input stream (or from stack if it's nonempty)
function Shlex:get_token()
	if #self.pushback > 0 then
		local tok = self.pushback[#self.pushback]
		self.pushback[#self.pushback] = nil

		if self.debug >= 1 then
			print(string.format("shlex: popping token %q", tok))
		end

		return tok
	end

	-- No pushback. Get a token.
	local raw = self:read_token()

	-- Handle inclusions
	if self.source then
		while raw == self.source do
			local spec = self:sourcehook(self:read_token())
			if spec then
				self:push_source(spec[1], spec[2])
			end

			raw = self:get_token()
		end
	end

	-- Maybe we got EOF instead?
	while raw == self.eof do
		if #self.filestack == 0 then
			return self.eof
		else
			self:pop_source()
			raw = self:get_token()
		end
	end

	-- Neither inclusion nor EOF
	if self.debug >= 1 then
		if raw ~= self.eof then
			print(string.format("shlex: token=%q", raw))
		else
			print("shlex: token=EOF")
		end
	end

	return raw
end

function Shlex:read_token()
	local quoted = false
	local escapedstate = " "

	while true do
		local nextchar

		if #self.punctuation_chars > 0 and #self._pushback_chars > 0 then
			nextchar = table.remove(self._pushback_chars)
		else
			nextchar = self.instream:read(1) or ""
		end

		---@cast nextchar string
		if nextchar == "\n" then
			self.lineno = self.lineno + 1
		end
		if self.debug >= 3 then
			print(string.format("shlex: in state %q I see character: %q", self.state, nextchar))
		end

		if self.state == nil then
			-- past end of file
			self.token = ""
			break
		elseif self.state == " " then
			if #nextchar == 0 then
				-- end of file
				self.state = nil
				break
			elseif self.whitespace:find(nextchar, 1, true) then
				if self.debug >= 2 then
					print("shlex: I see whitespace in whitespace state")
				end

				if self.token or (self.posix and quoted) then
					-- emit current token
					break
				end
			elseif self.commenters:find(nextchar, 1, true) then
				self.instream:read("*l")
				self.lineno = self.lineno + 1
			elseif self.posix and self.escape:find(nextchar, 1, true) then
				escapedstate = "a"
				self.state = nextchar
			elseif self.wordchars:find(nextchar, 1, true) then
				self.token = nextchar
				self.state = "a"
			elseif self.punctuation_chars:find(nextchar, 1, true) then
				self.token = nextchar
				self.state = "c"
			elseif self.quotes:find(nextchar, 1, true) then
				if not self.posix then
					self.token = nextchar
				end
				self.state = nextchar
			elseif self.whitespace_split then
				self.token = nextchar
				self.state = "a"
			else
				self.token = nextchar
				if #self.token > 0 or (self.posix and quoted) then
					-- emit current token
					break
				end
			end
		elseif self.quotes:find(self.state, 1, true) then
			quoted = true
			if #nextchar == 0 then
				if self.debug >= 2 then
					print("shlex: I see EOF in quotes state")
				end

				-- XXX what error should be raised here?
				error("No closing quotation")
			elseif nextchar == self.state then
				if not self.posix then
					self.token = self.token..nextchar
					self.state = " "
					break
				else
					self.state = "a"
				end
			elseif self.posix and self.escape:find(nextchar, 1, true) and self.escapedquotes:find(self.state, 1, true) then
				escapedstate = self.state
				self.state = nextchar
			else
				self.token = self.token..nextchar
			end
		elseif self.escape:find(self.state, 1, true) then
			if #nextchar == 0 then
				if self.debug >= 2 then
					print("shlex: I see EOF in escape state")
				end

				-- XXX what error should be raised here?
				error("No escaped character")
			end

			-- In posix shells, only the quote itself or the escape
			-- character may be escaped within quotes.
			if self.quotes:find(escapedstate, 1, true) and nextchar ~= self.state and nextchar ~= escapedstate then
				self.token = self.token..self.state
			end

			self.token = self.token..nextchar
			self.state = escapedstate
		elseif self.state == "a" or self.state == "c" then
			if #nextchar == 0 then
				-- end of file
				self.state = nil
				break
			elseif self.whitespace:find(nextchar, 1, true) then
				if self.debug >= 2 then
					print("shlex: I see whitespace in word state")
				end

				self.state = " "
				if #self.token > 0 or (self.posix and quoted) then
					-- emit current token
					break
				end
			elseif self.commenters:find(nextchar, 1, true) then
				self.instream:read("*l")
				self.lineno = self.lineno + 1

				if self.posix then
					self.state = " "

					if #self.token > 0 or (self.posix and quoted) then
						-- emit current token
						break
					end
				end
			elseif self.state == "c" then
				if self.punctuation_chars:find(nextchar, 1, true) then
					self.token = self.token..nextchar
				else
					if self.whitespace:find(nextchar, 1, true) == nil then
						self._pushback_chars[#self._pushback_chars + 1] = nextchar
					end

					self.state = " "
					break
				end
			elseif self.posix and self.quotes:find(nextchar, 1, true) then
				self.state = nextchar
			elseif self.posix and self.escape:find(nextchar, 1, true) then
				escapedstate = "a"
				self.state = nextchar
			elseif self.wordchars:find(nextchar, 1, true) or self.quotes:find(nextchar, 1, true) or (self.whitespace_split and self.punctuation_chars:find(nextchar, 1, true) == nil) then
				self.token = self.token..nextchar
			else
				if #self.punctuation_chars > 0 then
					self._pushback_chars[#self._pushback_chars + 1] = nextchar
				else
					self.pushback[#self.pushback + 1] = nextchar
				end

				if self.debug >= 2 then
					print("shlex: I see punctuation in word state")
				end

				self.state = " "
				if #self.token > 0 or (self.posix and quoted) then
					-- emit current token
					break
				end
			end
		end
	end

	local result = self.token
	self.token = ""

	if self.posix and (not quoted) and result == "" then
		---@diagnostic disable-next-line: cast-local-type
		result = nil
	end

	if self.debug > 1 then
		if result and #result > 0 then
			print(string.format("shlex: raw token=%q", result))
		else
			print("shlex: raw token=EOF")
		end
	end

	return result
end

---Hook called on a filename to be sourced.
---@param newfile string
function Shlex:sourcehook(newfile)
	if newfile:sub(1, 1) == "\"" then
		newfile = newfile:sub(2, -2)
	end

	-- This implements cpp-like semantics for relative-path inclusion.
	if type(self.infile) == "string" then
		-- Check if it's not absolute path
		if newfile:sub(1, 1) ~= "/" and newfile:sub(1, 1) ~= "\\" and newfile:sub(2, 2) ~= ":" then
			local backslash = not not self.infile:find("\\", 1, true)
			local dirrev = self.infile:gsub("\\", "/"):reverse()
			local s = dirrev:find("/", 1, true)
			local dir
			if s then
				dir = dirrev:sub(s + 1):reverse()
			else
				dir = "."
			end

			newfile = dir.."/"..newfile
			if backslash then
				newfile = newfile:gsub("/", "\\")
			end
		end
	end

	return {newfile, io.open(newfile, "r")}
end

---@param infile string?
---@param lineno integer?
function Shlex:error_leader(infile, lineno)
	infile = infile or self.infile
	lineno = lineno or self.lineno

	return string.format("%q, line %d: ", infile, lineno)
end

function Shlex:iterator()
	return function()
		local token = self:get_token()

		if token == self.eof then
			return nil
		else
			return token
		end
	end
end

function Shlex:list()
	local result = {}
	---@cast result string[]

	for token in self:iterator() do
		result[#result + 1] = token
	end

	return result
end

setmetatable(Shlex, {__call = function(_, instream, infile, posix, punctuation)
	local test = setmetatable({}, Shlex)
	test:new(instream, infile, posix, punctuation)
	return test
end})
---@cast Shlex +fun(instream:file*|Shlex.IReadableFile|string,infile:string?,posix:boolean?,punctuation:boolean|string?):Shlex.Shlex
shlex.Shlex = Shlex

---Split the string `s` using shell-like syntax.
---@param s string
---@param comments boolean?
---@param posix boolean?
function shlex.split(s, comments, posix)
	if posix == nil then posix = true end
	local lex = Shlex(s, nil, posix)
	lex.whitespace_split = true

	if not comments then
		lex.commenters = ""
	end

	return lex:list()
end

---Return a shell-escaped string from `split_command`.
---@param split_command string[]
function shlex.join(split_command)
	local result = {}

	for _, v in ipairs(split_command) do
		result[#result + 1] = shlex.quote(v)
	end

	return table.concat(result, " ")
end

local UNSAFE_PATTERN = "[^a-zA-Z0-9_@%%%+=:,%./%-]"

---Return a shell-escaped version of the string `s`.
---@param s string
function shlex.quote(s)
	if #s == 0 then
		return "''"
	elseif s:find(UNSAFE_PATTERN) then
		-- use single quotes, and put single quotes into double quotes
		-- the string $'b is then quoted as '$'"'"'b'
		return "'"..s:gsub("'", "'\"'\"'").."'"
	else
		return s
	end
end

return shlex
