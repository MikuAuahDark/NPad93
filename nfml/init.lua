-- NPad's FFI Math Library
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

local type = _G.type

local ffi
local nfml = {}

if rawget(_G, "jit") and jit.status() and package.preload.ffi then
	ffi = require("ffi")
end

ffi.cdef[[
// Vec2
union nfml_vec2
{
	struct {
		double x, y;
	};
	double e[2];
};

// Vec3
union nfml_vec3
{
	struct {
		double x, y, z;
	};
	double e[3];
};

// Vec4
union nfml_vec4
{
	struct {
		double x, y, z, w;
	};
	double e[4];
};

// Mat2x2
union nfml_mat2
{
	struct {
		union nfml_vec2 a, b;
	};
	union nfml_vec2 e[2];
};

// Mat2x3
union nfml_mat2x3
{
	struct {
		union nfml_vec3 a, b;
	};
	union nfml_vec3 e[2];
};

// Mat2x4
union nfml_mat2x4
{
	struct {
		union nfml_vec4 a, b;
	};
	union nfml_vec4 e[2];
};

// Mat3x2
union nfml_mat3x2
{
	struct {
		union nfml_vec2 a, b, c;
	};
	union nfml_vec2 e[3];
};

// Mat3x3
union nfml_mat3
{
	struct {
		union nfml_vec3 a, b, c;
	};
	union nfml_vec3 e[3];
};

// Mat3x4
union nfml_mat3x4
{
	struct {
		union nfml_vec4 a, b, c;
	};
	union nfml_vec4 e[3];
};

// Mat4x2
union nfml_mat4x2
{
	struct {
		union nfml_vec2 a, b, c, d;
	};
	union nfml_vec2 e[4];
};

// Mat4x3
union nfml_mat4x3
{
	struct {
		union nfml_vec3 a, b, c, d;
	};
	union nfml_vec3 e[4];
};

// Mat4x4
union nfml_mat4
{
	struct {
		union nfml_vec4 a, b, c, d;
	};
	union nfml_vec4 e[4];
};
]]

-- Vec2 methods
local vec2, vec2_t = {}, nil
if ffi then
	vec2_t = ffi.typeof("union nfml_vec2")

	function vec2.new(x, y)
		return vec2_t(x or 0, y or 0)
	end

	function vec2.is(a)
		return type(a) == "cdata" and ffi.istype(a, vec2_t)
	end
else
	function vec2.new(x, y)
		return setmetatable({x = x or 0, y = y or 0}, vec2)
	end

	function vec2.is(a)
		return getmetatable(a) == vec2
	end
end

function vec2:__unm()
	return vec2.new(-self.x, -self.y)
end

function vec2.__add(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a + b.x, a + b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x + b, a.y + b)
		elseif vec2.is(b) then
			return vec2.new(a.x + b.x, a.y + b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__sub(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a - b.x, a - b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x - b, a.y - b)
		elseif vec2.is(b) then
			return vec2.new(a.x - b.x, a.y - b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__mul(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a * b.x, a * b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x * b, a.y * b)
		elseif vec2.is(b) then
			return vec2.new(a.x * b.x, a.y * b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__div(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a / b.x, a / b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x / b, a.y / b)
		elseif vec2.is(b) then
			return vec2.new(a.x / b.x, a.y / b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__mod(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a % b.x, a % b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x % b, a.y % b)
		elseif vec2.is(b) then
			return vec2.new(a.x % b.x, a.y % b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__pow(a, b)
	if type(a) == "number" and vec2.is(b) then
		return vec2.new(a ^ b.x, a ^ b.y)
	elseif vec2.is(a) then
		if type(b) == "number" then
			return vec2.new(a.x ^ b, a.y ^ b)
		elseif vec2.is(b) then
			return vec2.new(a.x ^ b.x, a.y ^ b.y)
		end
	end

	error("number or vec2 expected")
end

function vec2.__eq(a, b)
	return a.x == b.x and a.y == b.y
end

function vec2:__tostring()
	return string.format("vec2(%.14g, %.14g)", self:unpack())
end

function vec2:clone()
	return vec2.new(self.x, self.y)
end

function vec2:unpack()
	return self.x, self.y
end

vec2.__index = vec2

if vec2_t then
	ffi.metatype(vec2_t, vec2)
end

nfml.vec2 = setmetatable(vec2, {__call = function(_, x, y)
	return vec2.new(x, y)
end})
-- End of Vec2 methods

-- Vec3 methods
local vec3, vec3_t = {}, nil
if ffi then
	vec3_t = ffi.typeof("union nfml_vec3")

	function vec3.new(x, y, z)
		return vec3_t(x or 0, y or 0, z or 0)
	end

	function vec3.is(a)
		return type(a) == "cdata" and ffi.istype(a, vec3_t)
	end
else
	function vec3.new(x, y, z)
		return setmetatable({x = x or 0, y = y or 0, z = z or 0}, vec3)
	end

	function vec3.is(a)
		return getmetatable(a) == vec3
	end
end


function vec3:__unm()
	return vec3.new(-self.x, -self.y, -self.z)
end

function vec3.__add(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a + b.x, a + b.y, a + b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x + b, a.y + b, a.z + b)
		elseif vec3.is(b) then
			return vec3.new(a.x + b.x, a.y + b.y, a.z + b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__sub(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a - b.x, a - b.y, a - b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x - b, a.y - b, a.z - b)
		elseif vec3.is(b) then
			return vec3.new(a.x - b.x, a.y - b.y, a.z - b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__mul(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a * b.x, a * b.y, a * b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x * b, a.y * b, a.z * b)
		elseif vec3.is(b) then
			return vec3.new(a.x * b.x, a.y * b.y, a.z * b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__div(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a / b.x, a / b.y, a / b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x / b, a.y / b, a.z / b)
		elseif vec3.is(b) then
			return vec3.new(a.x / b.x, a.y / b.y, a.z / b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__mod(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a % b.x, a % b.y, a % b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x % b, a.y % b, a.z % b)
		elseif vec3.is(b) then
			return vec3.new(a.x % b.x, a.y % b.y, a.z % b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__pow(a, b)
	if type(a) == "number" and vec3.is(b) then
		return vec3.new(a ^ b.x, a ^ b.y, a ^ b.z)
	elseif vec3.is(a) then
		if type(b) == "number" then
			return vec3.new(a.x ^ b, a.y ^ b, a.z ^ b)
		elseif vec3.is(b) then
			return vec3.new(a.x ^ b.x, a.y ^ b.y, a.z ^ b.z)
		end
	end

	error("number or vec3 expected")
end

function vec3.__eq(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z
end

function vec3:__tostring()
	return string.format("vec3(%.14g, %.14g, %.14g)", self:unpack())
end

function vec3:clone()
	return vec3.new(self.x, self.y, self.z)
end

function vec3:unpack()
	return self.x, self.y, self.z
end

vec3.__index = vec3

if vec3_t then
	ffi.metatype(vec3_t, vec3)
end

nfml.vec3 = setmetatable(vec3, {__call = function(_, x, y, z)
	return vec3.new(x, y, z)
end})
-- End of Vec3 methods

-- Vec4 methods
local vec4, vec4_t = {}, nil
if ffi then
	vec4_t = ffi.typeof("union nfml_vec4")

	function vec4.new(x, y, z, w)
		return vec4_t(x or 0, y or 0, z or 0, w or 0)
	end

	function vec4.is(a)
		return type(a) == "cdata" and ffi.istype(a, vec4_t)
	end
else
	function vec4.new(x, y, z, w)
		return setmetatable({x = x or 0, y = y or 0, z = z or 0, w = w or 0}, vec4)
	end

	function vec4.is(a)
		return getmetatable(a) == vec4
	end
end

function vec4:__unm()
	return vec4.new(-self.x, -self.y, -self.z, -self.w)
end

function vec4.__add(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a + b.x, a + b.y, a + b.z, a + b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x + b, a.y + b, a.z + b, a.w + b)
		elseif vec4.is(b) then
			return vec4.new(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__sub(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a - b.x, a - b.y, a - b.z, a - b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x - b, a.y - b, a.z - b, a.w - b)
		elseif vec4.is(b) then
			return vec4.new(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__mul(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a * b.x, a * b.y, a * b.z, a * b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x * b, a.y * b, a.z * b, a.w * b)
		elseif vec4.is(b) then
			return vec4.new(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__div(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a / b.x, a / b.y, a / b.z, a / b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x / b, a.y / b, a.z / b, a.w / b)
		elseif vec4.is(b) then
			return vec4.new(a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__mod(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a % b.x, a % b.y, a % b.z, a % b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x % b, a.y % b, a.z % b, a.w % b)
		elseif vec4.is(b) then
			return vec4.new(a.x % b.x, a.y % b.y, a.z % b.z, a.w % b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__pow(a, b)
	if type(a) == "number" and vec4.is(b) then
		return vec4.new(a ^ b.x, a ^ b.y, a ^ b.z, a ^ b.w)
	elseif vec4.is(a) then
		if type(b) == "number" then
			return vec4.new(a.x ^ b, a.y ^ b, a.z ^ b, a.w ^ b)
		elseif vec4.is(b) then
			return vec4.new(a.x ^ b.x, a.y ^ b.y, a.z ^ b.z, a.w ^ b.w)
		end
	end

	error("number or vec4 expected")
end

function vec4.__eq(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

function vec4:__tostring()
	return string.format("vec4(%.14g, %.14g, %.14g, %.14g)", self:unpack())
end

function vec4:clone()
	return vec4.new(self.x, self.y, self.z, self.w)
end

function vec4:unpack()
	return self.x, self.y, self.z, self.w
end

vec4.__index = vec4

if vec4_t then
	ffi.metatype(vec4_t, vec4)
end

nfml.vec4 = setmetatable(vec4, {__call = function(_, x, y, z, w)
	return vec4.new(x, y, z, w)
end})
-- End of Vec4 methods

-- Mat2 methods
local mat2, mat2_t = {}, nil
if ffi then
	mat2_t = ffi.typeof("union nfml_mat2")

	function mat2.new(a, b)
		if type(a) == "number" then
			return mat2_t({a, 0}, {0, a})
		else
			assert(vec2.is(a) and vec2.is(b), "invalid vec2 passed")
			return mat2_t(a, b)
		end
	end

	function mat2.is(a)
		return type(a) == "cdata" and ffi.istype(a, mat2_t)
	end
else
	function mat2.new(a, b)
		if type(a) == "number" then
			return setmetatable({a = vec2(a, 0), b = vec2(0, a)}, mat2)
		else
			assert(vec2.is(a) and vec2.is(b), "invalid vec2 passed")
			return setmetatable({a = a, b = b}, mat2)
		end
	end

	function mat2.is(a)
		return getmetatable(a) == mat2
	end
end

mat2.__index = mat2

if mat2_t then
	ffi.metatype(mat2_t, mat2)
end

nfml.mat2 = setmetatable(mat2, {__call = function(_, a, b)
	return mat2.new(a, b)
end})
nfml.mat2x2 = nfml.mat2
-- End of Mat2 methods

-- Mat3 methods
local mat3, mat3_t = {}, nil
if ffi then
	mat3_t = ffi.typeof("union nfml_mat3")

	function mat3.new(a, b, c)
		if type(a) == "number" then
			return mat3_t({a, 0, 0}, {0, a, 0}, {0, 0, a})
		else
			assert(vec3.is(a) and vec3.is(b) and vec3.is(c), "invalid vec3 passed")
			return mat3_t(a, b, c)
		end
	end

	function mat3.is(a)
		return type(a) == "cdata" and ffi.istype(a, mat3_t)
	end
else
	function mat3.new(a, b, c)
		if type(a) == "number" then
			return setmetatable({a = vec3(a, 0, 0), b = vec3(0, a, 0), c = vec3(0, 0, a)}, mat3)
		else
			assert(vec3.is(a) and vec3.is(b) and vec3.is(c), "invalid vec3 passed")
			return setmetatable({a = a, b = b, c = c}, mat3)
		end
	end

	function mat3.is(a)
		return getmetatable(a) == mat3
	end
end

mat3.__index = mat3

if mat3_t then
	ffi.metatype(mat3_t, mat3)
end

nfml.mat3 = setmetatable(mat3, {__call = function(_, a, b, c)
	return mat3.new(a, b, c)
end})
nfml.mat3x3 = nfml.mat3
-- End of Mat3 methods

-- Mat4 methods
local mat4, mat4_t = {}, nil
if ffi then
	mat4_t = ffi.typeof("union nfml_mat4")

	function mat4.new(a, b, c, d)
		if type(a) == "number" then
			return mat4_t({a, 0, 0, 0}, {0, a, 0, 0}, {0, 0, a, 0}, {0, 0, 0, a})
		else
			assert(vec4.is(a) and vec4.is(b) and vec4.is(c) and vec4.is(d), "invalid vec4 passed")
			return mat4_t(a, b, c, d)
		end
	end

	function mat4.is(a)
		return type(a) == "cdata" and ffi.istype(a, mat4_t)
	end
else
	function mat4.new(a, b, c, d)
		if type(a) == "number" then
			return setmetatable({a = vec4(a, 0, 0), b = vec4(0, a, 0), c = vec4(0, 0, a)}, mat4)
		else
			assert(vec4.is(a) and vec4.is(b) and vec4.is(c) and vec4.is(d), "invalid vec4 passed")
			return setmetatable({a = a, b = b, c = c, d = d}, mat4)
		end
	end

	function mat4.is(a)
		return getmetatable(a) == mat4
	end
end

mat4.__index = mat4

if mat4_t then
	ffi.metatype(mat4_t, mat4)
end

nfml.mat4 = setmetatable(mat4, {__call = function(_, a, b, c, d)
	return mat4.new(a, b, c, d)
end})
nfml.mat4x4 = nfml.mat4
-- End of Mat4 methods

-- Utils function
local rad, deg, log, sqrt = math.rad, math.deg, math.log, math.sqrt
local sin, cos, tan = math.sin, math.cos, math.tan
local acos, asin, atan, atan2 = math.acos, math.asin, math.atan, math.atan2
local abs, floor, ceil = math.abs, math.floor, math.ceil

function nfml.radians(a)
	if type(a) == "number" then
		return rad(a)
	elseif vec2.is(a) then
		return vec2.new(rad(a.x), rad(a.y))
	elseif vec3.is(a) then
		return vec3.new(rad(a.x), rad(a.y), rad(a.z))
	elseif vec4.is(a) then
		return vec4.new(rad(a.x), rad(a.y), rad(a.z), rad(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.degrees(a)
	if type(a) == "number" then
		return deg(a)
	elseif vec2.is(a) then
		return vec2.new(deg(a.x), deg(a.y))
	elseif vec3.is(a) then
		return vec3.new(deg(a.x), deg(a.y), deg(a.z))
	elseif vec4.is(a) then
		return vec4.new(deg(a.x), deg(a.y), deg(a.z), deg(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.sin(a)
	if type(a) == "number" then
		return sin(a)
	elseif vec2.is(a) then
		return vec2.new(sin(a.x), sin(a.y))
	elseif vec3.is(a) then
		return vec3.new(sin(a.x), sin(a.y), sin(a.z))
	elseif vec4.is(a) then
		return vec4.new(sin(a.x), sin(a.y), sin(a.z), sin(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.cos(a)
	if type(a) == "number" then
		return cos(a)
	elseif vec2.is(a) then
		return vec2.new(cos(a.x), cos(a.y))
	elseif vec3.is(a) then
		return vec3.new(cos(a.x), cos(a.y), cos(a.z))
	elseif vec4.is(a) then
		return vec4.new(cos(a.x), cos(a.y), cos(a.z), cos(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.tan(a)
	if type(a) == "number" then
		return tan(a)
	elseif vec2.is(a) then
		return vec2.new(tan(a.x), tan(a.y))
	elseif vec3.is(a) then
		return vec3.new(tan(a.x), tan(a.y), tan(a.z))
	elseif vec4.is(a) then
		return vec4.new(tan(a.x), tan(a.y), tan(a.z), tan(a.w))
	else
		error("number or vec(n) expected")
	end
end


function nfml.asin(a)
	if type(a) == "number" then
		return asin(a)
	elseif vec2.is(a) then
		return vec2.new(asin(a.x), asin(a.y))
	elseif vec3.is(a) then
		return vec3.new(asin(a.x), asin(a.y), asin(a.z))
	elseif vec4.is(a) then
		return vec4.new(asin(a.x), asin(a.y), asin(a.z), asin(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.acos(a)
	if type(a) == "number" then
		return acos(a)
	elseif vec2.is(a) then
		return vec2.new(acos(a.x), acos(a.y))
	elseif vec3.is(a) then
		return vec3.new(acos(a.x), acos(a.y), acos(a.z))
	elseif vec4.is(a) then
		return vec4.new(acos(a.x), acos(a.y), acos(a.z), acos(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.atan(a, b)
	if b ~= nil then
		if type(a) == "number" and type(b) == "number" then
			return atan2(a, b)
		elseif vec2.is(a) and vec2.is(b) then
			return vec2.new(atan2(a.x, b.x), atan2(a.y, b.y))
		elseif vec3.is(a) and vec3.is(b) then
			return vec3.new(atan2(a.x, b.x), atan2(a.y, b.y), atan2(a.z, b.z))
		elseif vec4.is(a) and vec4.is(b) then
			return vec4.new(atan2(a.x, b.x), atan2(a.y, b.y), atan2(a.z, b.z), atan2(a.w, b.w))
		else
			error("number or vec(n) expected (unmatching types?)")
		end
	else
		if type(a) == "number" then
			return atan(a)
		elseif vec2.is(a) then
			return vec2.new(atan(a.x), atan(a.y))
		elseif vec3.is(a) then
			return vec3.new(atan(a.x), atan(a.y), atan(a.z))
		elseif vec4.is(a) then
			return vec4.new(atan(a.x), atan(a.y), atan(a.z), atan(a.w))
		else
			error("number or vec(n) expected")
		end
	end
end

local expValue = math.exp(1)
function nfml.exp(a)
	if type(a) == "number" then
		return expValue ^ a
	elseif vec2.is(a) then
		return vec2.new(expValue ^ a.x, expValue ^ a.y)
	elseif vec3.is(a) then
		return vec2.new(expValue ^ a.x, expValue ^ a.y, expValue ^ a.z)
	elseif vec4.is(a) then
		return vec2.new(expValue ^ a.x, expValue ^ a.y, expValue ^ a.z, expValue ^ a.w)
	else
		error("number or vec(n) expected")
	end
end

function nfml.log(a)
	if type(a) == "number" then
		return log(a)
	elseif vec2.is(a) then
		return vec2.new(log(a.x), log(a.y))
	elseif vec3.is(a) then
		return vec3.new(log(a.x), log(a.y), log(a.z))
	elseif vec4.is(a) then
		return vec4.new(log(a.x), log(a.y), log(a.z), log(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.exp2(a)
	if type(a) == "number" then
		return 2 ^ a
	elseif vec2.is(a) then
		return vec2.new(2 ^ a.x, 2 ^ a.y)
	elseif vec3.is(a) then
		return vec2.new(2 ^ a.x, 2 ^ a.y, 2 ^ a.z)
	elseif vec4.is(a) then
		return vec2.new(2 ^ a.x, 2 ^ a.y, 2 ^ a.z, 2 ^ a.w)
	else
		error("number or vec(n) expected")
	end
end

local log2 = log(2)
function nfml.log2(a)
	if type(a) == "number" then
		return log(a) / log2
	elseif vec2.is(a) then
		return vec2.new(log(a.x) / log2, log(a.y) / log2)
	elseif vec3.is(a) then
		return vec3.new(log(a.x) / log2, log(a.y) / log2, log(a.z) / log2)
	elseif vec4.is(a) then
		return vec4.new(log(a.x) / log2, log(a.y) / log2, log(a.z) / log2, log(a.w) / log2)
	else
		error("number or vec(n) expected")
	end
end

function nfml.sqrt(a)
	if type(a) == "number" then
		return sqrt(a)
	elseif vec2.is(a) then
		return vec2.new(sqrt(a.x), sqrt(a.y))
	elseif vec3.is(a) then
		return vec3.new(sqrt(a.x), sqrt(a.y), sqrt(a.z))
	elseif vec4.is(a) then
		return vec4.new(sqrt(a.x), sqrt(a.y), sqrt(a.z), sqrt(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.inversesqrt(a)
	if type(a) == "number" then
		return 1 / sqrt(a)
	elseif vec2.is(a) then
		return vec2.new(1 / sqrt(a.x), 1 / sqrt(a.y))
	elseif vec3.is(a) then
		return vec3.new(1 / sqrt(a.x), 1 / sqrt(a.y), 1 / sqrt(a.z))
	elseif vec4.is(a) then
		return vec4.new(1 / sqrt(a.x), 1 / sqrt(a.y), 1 / sqrt(a.z), 1 / sqrt(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.abs(a)
	if type(a) == "number" then
		return abs(a)
	elseif vec2.is(a) then
		return vec2.new(abs(a.x), abs(a.y))
	elseif vec3.is(a) then
		return vec3.new(abs(a.x), abs(a.y), abs(a.z))
	elseif vec4.is(a) then
		return vec4.new(abs(a.x), abs(a.y), abs(a.z), abs(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.floor(a)
	if type(a) == "number" then
		return floor(a)
	elseif vec2.is(a) then
		return vec2.new(floor(a.x), floor(a.y))
	elseif vec3.is(a) then
		return vec3.new(floor(a.x), floor(a.y), floor(a.z))
	elseif vec4.is(a) then
		return vec4.new(floor(a.x), floor(a.y), floor(a.z), floor(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.ceil(a)
	if type(a) == "number" then
		return ceil(a)
	elseif vec2.is(a) then
		return vec2.new(ceil(a.x), ceil(a.y))
	elseif vec3.is(a) then
		return vec3.new(ceil(a.x), ceil(a.y), ceil(a.z))
	elseif vec4.is(a) then
		return vec4.new(ceil(a.x), ceil(a.y), ceil(a.z), ceil(a.w))
	else
		error("number or vec(n) expected")
	end
end

function nfml.fract(a)
	return a - nfml.floor(a)
end

-- TODO: min, max, clamp

function nfml.mix(a, b, c)
	return (1 - c) * a + c * b
end

-- TODO: step, smoothstep

function nfml.length(a)
	if type(a) == "number" then
		return abs(a)
	else
		local b = 0

		if vec2.is(a) then
			b = a.x * a.x + a.y * a.y
		elseif vec3.is(a) then
			b = a.x * a.x + a.y * a.y + a.z * a.z
		elseif vec4.is(a) then
			b = a.x * a.x + a.y * a.y + a.z * a.z + a.w * b.w
		else
			error("vec(n) expected")
		end

		return sqrt(b)
	end
end

function nfml.distance(a, b)
	return nfml.length(b - a)
end

function nfml.dot(a, b)
	if type(a) == "number" and type(b) == "number" then
		return a + b
	elseif vec2.is(a) and vec2.is(b) then
		return a.x * b.x + a.y * b.y
	elseif vec3.is(a) and vec3.is(b) then
		return a.x * b.x + a.y * b.y + a.z * b.z
	elseif vec4.is(a) and vec4.is(b) then
		return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
	else
		error("number or vec(n) expected (unmatching types?)")
	end
end

function nfml.cross(a, b)
	if vec3.is(a) and vec3.is(b) then
		return vec3.new(
			a.y * b.z - b.y * a.z,
			a.z * b.x - b.z * a.x,
			a.x * b.y - b.x * a.y
		)
	else
		error("vec3 expected")
	end
end

function nfml.normalize(a)
	if type(a) == "number" then
		return 1
	else
		local len = nfml.length(a)
		return len == 0 and a or (a / len)
	end
end

-- TODO: faceforward, reflect, refract, matrixCompMult
-- TODO: lessThan, lessThanEqual, greaterThan, greaterThanEqual, equal, notEqual

function nfml.export()
	_G.vec2 = nfml.vec2
	_G.vec3 = nfml.vec3
	_G.vec4 = nfml.vec4
	_G.mat2 = nfml.mat2
	_G.mat3 = nfml.mat3
	_G.mat4 = nfml.mat4
end

return nfml
