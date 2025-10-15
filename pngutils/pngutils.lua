--[[
The MIT License (MIT)

Copyright (c) 2013 DelusionalLogic

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local Class = require('pngutils.30log')
local deflate = require('pngutils.deflate')
local Stream = require('pngutils.stream')

local Chunk = Class()
Chunk.__name = "Chunk"
Chunk.length = 0
Chunk.name = ""
Chunk.data = ""
Chunk.crc = ""

function Chunk:init(stream)
	if stream.__name == "Chunk" then
		self.length = stream.length
		self.name = stream.name
		self.data = stream.data
		self.crc = stream.crc
	else
		self.length = stream:readInt()
		self.name = stream:readChars(4)
		self.data = stream:readChars(self.length)
		self.crc = stream:readChars(4)
	end
end

function Chunk:getDataStream()
	return Stream({input = self.data})
end

local IHDR = Chunk:extend()
IHDR.__name = "IHDR"
IHDR.width = 0
IHDR.height = 0
IHDR.bitDepth = 0
IHDR.colorType = 0
IHDR.compression = 0
IHDR.filter = 0
IHDR.interlace = 0

function IHDR:init(chunk)
	self.super.init(self, chunk)
	local stream = chunk:getDataStream()
	self.width = stream:readInt()
	self.height = stream:readInt()
	self.bitDepth = stream:readByte()
	self.colorType = stream:readByte()
	self.compression = stream:readByte()
	self.filter = stream:readByte()
	self.interlace = stream:readByte()
end

local IDAT = Chunk:extend()
IDAT.__name = "IDAT"

function IDAT:init(chunk)
	self.super.init(self, chunk)
end

local PLTE = Chunk:extend()
PLTE.__name = "PLTE"
PLTE.numColors = 0
PLTE.colors = {}

function PLTE:init(chunk)
	self.super.init(self, chunk)
	self.numColors = math.floor(chunk.length/3)
	local stream = chunk:getDataStream()
	for i = 1, self.numColors do
		self.colors[i] = {
			R = stream:readByte(),
			G = stream:readByte(),
			B = stream:readByte(),
		}
	end
end

function PLTE:getColor(index)
	return self.colors[index]
end

--Stolen right from w3.
local function paeth_predict(a, b, c)
	local p = a + b - c
	local varA = math.abs(p - a)
	local varB = math.abs(p - b)
	local varC = math.abs(p - c)
	if varA <= varB and varA <= varC then return a end
	if varB <= varC then return b end
	return c
end

local function get_pixel(stream, depth)
	local bps = math.floor(depth/8)
	local r = stream:readInt(bps)
	local g = stream:readInt(bps)
	local b = stream:readInt(bps)
	local a = stream:readInt(bps)
	return {r = r, g = g, b = b}
end

local function scanline(stream, depth, length)
	local bpp = math.floor(depth/8) * 4
	local bpl = bpp*length
	local filterType = stream:readByte()
	local pixels = {}
	stream:seek(-1)
	stream:writeByte(0)
	local startLoc = stream.position
	if filterType == 0 then
		for i = 1, length do
			pixels[i] = get_pixel(stream, depth)
		end
	end
	if filterType == 1 then
		for i = 1, length do
			for j = 1, bpp do
				local curByte = stream:readByte()
				stream:seek(-(bpp+1))
				local lastByte = 0
				if stream.position >= startLoc then lastByte = stream:readByte() or 0 else stream:readByte() end
				stream:seek(bpp-1)
				stream:writeByte((curByte + lastByte) % 256)
			end
			stream:seek(-bpp)
			pixels[i] = get_pixel(stream, depth)
		end
	end
	if filterType == 2 then
		for i = 1, length do
			for j = 1, bpp do
				local curByte = stream:readByte()
				stream:seek(-(bpl+2))
				local lastByte = stream:readByte() or 0
				stream:seek(bpl)
				stream:writeByte((curByte + lastByte) % 256)
			end
			stream:seek(-bpp)
			pixels[i] = get_pixel(stream, depth)
		end
	end
	if filterType == 3 then
		for i = 1, length do
			for j = 1, bpp do
				local curByte = stream:readByte()
				stream:seek(-(bpp+1))
				local lastByte = 0
				if stream.position >= startLoc then lastByte = stream:readByte() or 0 else stream:readByte() end
				stream:seek(-(bpl)+bpp-2)
				local priByte = stream:readByte() or 0
				stream:seek(bpl)
				stream:writeByte((curByte + math.floor((lastByte+priByte)/2)) % 256)
			end
			stream:seek(-bpp)
			pixels[i] = get_pixel(stream, depth)
		end
	end
	if filterType == 4 then
		for i = 1, length do
			for j = 1, bpp do
				local curByte = stream:readByte()
				stream:seek(-(bpp+1))
				local lastByte = 0
				if stream.position >= startLoc then lastByte = stream:readByte() or 0 else stream:readByte() end
				stream:seek(-(bpl + 2 - bpp))
				local priByte = stream:readByte() or 0
				stream:seek(-(bpp+1))
				local lastPriByte = 0
				if stream.position >= startLoc - (length * bpp + 1) then lastPriByte = stream:readByte() or 0 else stream:readByte() end
				stream:seek(bpl + bpp)
				stream:writeByte((curByte + paeth_predict(lastByte, priByte, lastPriByte)) % 256)
			end
			stream:seek(-bpp)
			pixels[i] = get_pixel(stream, depth)
		end
	end
	return pixels
end

local pngImage = Class()
pngImage.__name = "PNG"
pngImage.width = 0
pngImage.height = 0
pngImage.depth = 0
pngImage.colorType = 0
pngImage.pixels = {}

function pngImage:init(handle)
	local str = Stream({handle = handle})
	if str:readChars(8) ~= "\137\080\078\071\013\010\026\010" then error 'Not a PNG' end
	local ihdr = {}
	local plte = {}
	local idat = {}
	local num = 1
	while true do
		ch = Chunk(str)
		if ch.name == "IHDR" then ihdr = IHDR(ch) end
		if ch.name == "PLTE" then plte = PLTE(ch) end
		if ch.name == "IDAT" then idat[num] = IDAT(ch) num = num+1 end
		if ch.name == "IEND" then break end
	end
	self.width = ihdr.width
	self.height = ihdr.height
	self.depth = ihdr.bitDepth

	local dataStr = ""
	for k,v in pairs(idat) do dataStr = dataStr .. v.data end
	local output = {}
	deflate.inflate_zlib {input = dataStr, output = function(byte) output[#output+1] = string.char(byte) end, disable_crc = true}
	local imStr = Stream({input = table.concat(output)})

	for i = 1, self.height do
		self.pixels[i] = scanline(imStr, self.depth, self.width)
	end
end

function pngImage:getPixel(x, y)
	local pixel = self.pixels[y][x]
	return pixel
end

return pngImage
