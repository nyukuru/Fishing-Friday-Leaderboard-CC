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

local class = require('pngutils.30log')

local Stream = class()
Stream.data = {}
Stream.position = 1
Stream.__name = "Stream"

function Stream:bsRight(num, pow)
    return math.floor(num / 2^pow)
end

function Stream:bsLeft(num, pow)
    return math.floor(num * 2^pow)
end

function Stream:bytesToNum(bytes)
	local n = 0
	for k,v in ipairs(bytes) do
		n = self:bsLeft(n, 8) + v
	end
	n = (n > 2147483647) and (n - 4294967296) or n
	return n
end

function Stream:init(param)
    local str = ""
    if (param.handle ~= nil) then
	    str = param.handle:readAll()
    end
    if (param.input ~= nil) then
	    str = param.input
    end

    for i=1,#str do
	self.data[i] = str:byte(i, i)
    end
end

function Stream:seek(amount)
	self.position = self.position + amount
end

function Stream:readByte()
	if self.position <= 0 then self:seek(1) return nil end
	local byte = self.data[self.position]
	self:seek(1)
	return byte
end

function Stream:readChars(num)
	if self.position <= 0 then self:seek(1) return nil end
	local str = ""
	local i = 1
	while i <= num do
		str = str .. self:readChar()
		i = i + 1
	end
	return str, i-1
end

function Stream:readChar()
	if self.position <= 0 then self:seek(1) return nil end
	return string.char(self:readByte())
end

function Stream:readBytes(num)
	if self.position <= 0 then self:seek(1) return nil end
	local tabl = {}
	local i = 1
	while i <= num do
		local curByte = self:readByte()
		if curByte == nil then break end
		tabl[i] = curByte
		i = i + 1
	end
	return tabl, i-1
end

function Stream:readInt(num)
	if self.position <= 0 then self:seek(1) return nil end
	num = num or 4
	local bytes, count = self:readBytes(num)
	return self:bytesToNum(bytes), count
end

function Stream:writeByte(byte)
	if self.position <= 0 then self:seek(1) return end
	self.data[self.position] = byte
	self:seek(1)
end

function Stream:writeChar(char)
	if self.position <= 0 then self:seek(1) return end
	self:writeByte(string.byte(char))
end

function Stream:writeBytes(buffer)
	if self.position <= 0 then self:seek(1) return end
	local str = ""
	for k,v in pairs(buffer) do
		str = str .. string.char(v)
	end
end

return Stream
