-- NPad Neural Network. A very simple, inference-only, no backprop, Neural Network in Lua.
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

---@class npnn.module
local npnn = {
	_VERSION = "0.1.0",
	_AUTHOR = "MikuAuahDark",
	_LICENSE = "MIT"
}

---Identity function (returns itself).
---@param x number
function npnn.none(x)
	return x
end

---Sigmoid function.
---@param x number
function npnn.sigmoid(x)
	return 1 / (1 + math.exp(-x))
end

---Rectified-Linear Unit function.
---@param x number
---@return number
function npnn.relu(x)
	return math.max(0, x)
end

---@class npnn.NNBase
local NNBase = {}

---@param input number[]
---@return number[]
function NNBase:forward(input)
	error("")
end

---@param t {new:fun(...)}
local function makeCallable(t)
	assert(t.new, "missing new function")

	return setmetatable(t, {__call = function(self, ...)
		return t.new(...)
	end})
end

---@param weights number[][]
---@param input number[]
---@param bias number[]
---@param dst number[]?
local function matrixMultiply(weights, input, bias, dst)
	assert(#weights[1] == #input, "invalid input size")
	assert(#weights == #bias, "invalid bias size")

	local result = dst or {}

	for i = 1, #weights do
		local w = weights[i]
		local v = bias[i]

		for j = 1, #w do
			v = v + w[j] * input[j]
		end

		result[i] = v
	end

	return result
end

---A simple NN chaining. For more advanced chaining please create your own.
---@class (exact) npnn.Chain: npnn.NNBase
---@field package chains npnn.NNBase[]
local Chain = {}
---@diagnostic disable-next-line: inject-field
Chain.__index = Chain

---@param input number[]
function Chain:forward(input)
	local indata = input

	for _, chain in ipairs(self.chains) do
		indata = chain:forward(indata)
	end

	return indata
end

---@param ... npnn.NNBase
---@overload fun(chains:npnn.NNBase[]):npnn.Chain
---@diagnostic disable-next-line: inject-field
function Chain.new(...)
	local chain

	if type(...) == "table" then
		chain = ...
	else
		chain = {...}
	end

	return setmetatable({
		chains = chain
	}, Chain)
end

makeCallable(Chain)
---@cast Chain +fun(...:npnn.NNBase):npnn.Chain
---@cast Chain +fun(chains:npnn.NNBase[]):npnn.Chain
npnn.Chain = Chain

---Simple layer that wraps activation function.
---@class (exact) npnn.Activation: npnn.NNBase
---@field package values number[]
---@field package func fun(x:number):number
local Activation = {}
---@diagnostic disable-next-line: inject-field
Activation.__index = Activation

---@param input number[]
function Activation:forward(input)
	for i, v in ipairs(input) do
		self.values[i] = self.func(v)
	end

	return self.values
end

---@param func fun(x:number):number
---@diagnostic disable-next-line: inject-field
function Activation.new(func)
	return setmetatable({
		func = func,
		values = {}
	}, Activation)
end

makeCallable(Activation)
---@cast Activation +fun(func:fun(x:number):number):npnn.Activation
npnn.Activation = Activation

---Softmax activation function.
---@class (exact) npnn.Softmax: npnn.NNBase
---@field package values number[]
local Softmax = {}
---@diagnostic disable-next-line: inject-field
Softmax.__index = Softmax

---@param input number[]
function Softmax:forward(input)
	local sum = 0

	for _, v in ipairs(input) do
		sum = sum + math.exp(v)
	end

	for i, v in ipairs(input) do
		self.values[i] = math.exp(v) / sum
	end

	return self.values
end

---@diagnostic disable-next-line: inject-field
function Softmax.new()
	return setmetatable({
		values = {}
	}, Softmax)
end

makeCallable(Softmax)
---@cast Softmax +fun():npnn.Softmax
npnn.Softmax = Softmax

---Fully-Connected Layer (nn.Linear in PyTorch, Dense in Tensorflow).
---@class (exact) npnn.Linear: npnn.NNBase
---@field package weights number[][]
---@field package biases number[]
---@field package tempValues number[]
---@field package values number[]
local Linear = {}
---@diagnostic disable-next-line: inject-field
Linear.__index = Linear

---@param weights number[][] Array of number with length of `outsize` and `insize`
---@param biases number[] Array of number with length of `outsize`.
---@diagnostic disable-next-line: inject-field
function Linear.new(weights, biases)
	assert(#biases == #weights, "invalid weight or bias size")

	return setmetatable({
		values = {},
		tempValues = {},
		weights = weights,
		biases = biases
	}, Linear)
end

---@param input number[]
function Linear:forward(input)
	return matrixMultiply(self.weights, input, self.biases, self.values)
end

makeCallable(Linear)
---@cast Linear +fun(weights:number[][],biases:number[]):npnn.Linear
npnn.Linear = Linear

---Long Short-Term Memory layer.
---
---Mathematical formula is roughly taken from
---https://pytorch.org/docs/stable/generated/torch.nn.LSTM.html#torch.nn.LSTM
---@class (exact) npnn.LSTM: npnn.NNBase
---@field package iiweights number[][]
---@field package ifweights number[][]
---@field package igweights number[][]
---@field package ioweights number[][]
---@field package hiweights number[][]
---@field package hfweights number[][]
---@field package hgweights number[][]
---@field package howeights number[][]
---@field package iibiases number[]
---@field package ifbiases number[]
---@field package igbiases number[]
---@field package iobiases number[]
---@field package hibiases number[]
---@field package hfbiases number[]
---@field package hgbiases number[]
---@field package hobiases number[]
---@field package hstate number[]
---@field package cstate number[]
---@field package hstateout number[]
---@field package cstateout number[]
---@field package tempmm1 number[]
---@field package tempmm2 number[]
---@field package tempit number[]
---@field package tempft number[]
---@field package tempgt number[]
---@field package tempot number[]
---@field package tempinput number[]
---@field package tempresult number[]
local LSTM = {}
---@diagnostic disable-next-line: inject-field
LSTM.__index = LSTM

---@param iweights number[][] Weights data with size of `4*hidden_size x input_size` with first dimension is interleaved of input, forget, cell, output.
---@param hweights number[][] Weights data with size of `4*hidden_size x hidden_size` with first dimension is interleaved of input, forget, cell, output.
---@param ibiases number[] Bias data with size of `4*hidden_size` interleaved of input, forget, cell, output.
---@param hbiases number[] Bias data with size of `4*hidden_size` interleaved of input, forget, cell, output.
---@diagnostic disable-next-line: inject-field 
function LSTM.new(iweights, hweights, ibiases, hbiases)
	assert(#iweights == #hweights, "invalid weight size")
	assert(#hweights / 4 == #hweights[1], "invalid inner weight size")
	assert(#ibiases == #hbiases, "invalid bias size")
	assert(#ibiases == #iweights, "invalid weight and bias size")

	local iiweights, ifweights, igweights, ioweights = {}, {}, {}, {}
	local hiweights, hfweights, hgweights, howeights = {}, {}, {}, {}
	local iibiases, ifbiases, igbiases, iobiases = {}, {}, {}, {}
	local hibiases, hfbiases, hgbiases, hobiases = {}, {}, {}, {}

	local wz = #iweights / 4

	for i = 1, wz do
		-- https://github.com/pytorch/pytorch/issues/750#issuecomment-280671871
		iiweights[i] = iweights[i]
		hiweights[i] = hweights[i]
		iibiases[i] = ibiases[i]
		hibiases[i] = hbiases[i]
		ifweights[i] = iweights[i + wz]
		hfweights[i] = hweights[i + wz]
		ifbiases[i] = ibiases[i + wz]
		hfbiases[i] = hbiases[i + wz]
		igweights[i] = iweights[i + wz * 2]
		hgweights[i] = hweights[i + wz * 2]
		igbiases[i] = ibiases[i + wz * 2]
		hgbiases[i] = hbiases[i + wz * 2]
		ioweights[i] = iweights[i + wz * 3]
		howeights[i] = hweights[i + wz * 3]
		iobiases[i] = ibiases[i + wz * 3]
		hobiases[i] = hbiases[i + wz * 3]
	end

	return setmetatable({
		iiweights = iiweights,
		ifweights = ifweights,
		igweights = igweights,
		ioweights = ioweights,
		hiweights = hiweights,
		hfweights = hfweights,
		hgweights = hgweights,
		howeights = howeights,
		iibiases = iibiases,
		ifbiases = ifbiases,
		igbiases = igbiases,
		iobiases = iobiases,
		hibiases = hibiases,
		hfbiases = hfbiases,
		hgbiases = hgbiases,
		hobiases = hobiases,
		hstateout = {},
		cstateout = {},
		tempmm1 = {},
		tempmm2 = {},
		tempit = {},
		tempft = {},
		tempgt = {},
		tempot = {},
		tempresult = {},
		tempinput = {}
	}, LSTM)
end

---@param v1 number[]
---@param v2 number[]
---@param v number[]?
local function lstmPointwiseAdd(v1, v2, v)
	assert(#v1 == #v2)
	v = v or {}

	for i = 1, #v1 do
		v[i] = v1[i] + v2[i]
	end

	return v
end

---@type number[]
local zeroVector = setmetatable({}, {__index = function() return 0 end})

---@param input number[] Input with size of `input_size * hidden_size` (single array)
---@param hs number[]? Initial hidden state with size of `hidden_size` (optional).
---@param cs number[]? Initial cell state with size of `hidden_size` (optional).
function LSTM:forward(input, hs, cs)
	local hstate = hs or zeroVector
	local cstate = cs or zeroVector

	local featuresize = #self.iiweights[1]
	local hiddensize = #self.iiweights
	local seqlen = #input / featuresize

	-- Initialize hidden and cell state
	for i = 1, hiddensize do
		self.hstateout[i] = hstate[i]
		self.cstateout[i] = cstate[i]
	end

	---@type number[]
	local result = self.tempresult
	local x = self.tempinput

	for t = 1, seqlen do
		for i = 1, featuresize do
			x[i] = input[(t - 1) * featuresize + i]
		end

		local it = lstmPointwiseAdd(
			matrixMultiply(self.iiweights, x, self.iibiases, self.tempmm1),
			matrixMultiply(self.hiweights, self.hstateout, self.hibiases, self.tempmm2),
			self.tempit
		)
		local ft = lstmPointwiseAdd(
			matrixMultiply(self.ifweights, x, self.ifbiases, self.tempmm1),
			matrixMultiply(self.hfweights, self.hstateout, self.hfbiases, self.tempmm2),
			self.tempft
		)
		local gt = lstmPointwiseAdd(
			matrixMultiply(self.igweights, x, self.igbiases, self.tempmm1),
			matrixMultiply(self.hgweights, self.hstateout, self.hgbiases, self.tempmm2),
			self.tempgt
		)
		local ot = lstmPointwiseAdd(
			matrixMultiply(self.ioweights, x, self.iobiases, self.tempmm1),
			matrixMultiply(self.howeights, self.hstateout, self.hobiases, self.tempmm2),
			self.tempot
		)

		for i = 1, hiddensize do
			local cout = npnn.sigmoid(ft[i]) * self.cstateout[i] + npnn.sigmoid(it[i]) * math.tanh(gt[i])
			local hout = npnn.sigmoid(ot[i]) * math.tanh(cout)
			self.cstateout[i] = cout
			self.hstateout[i] = hout
			result[(t - 1) * hiddensize + i] = hout
		end
	end

	result[seqlen * hiddensize + 1] = nil

	return result, self.cstateout
end

makeCallable(LSTM)
---@cast LSTM +fun(iweights:number[][],hweights:number[][],ibiases:number[],hbiases:number[]):npnn.LSTM
npnn.LSTM = LSTM

return npnn
