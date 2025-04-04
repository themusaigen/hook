-- File: context.lua
-- Description: Module that implements CPU context.
-- Author: themusaigen

---@class Hook.Context
---@field private eax ffi.ctype*
---@field private ebx ffi.ctype*
---@field private ecx ffi.ctype*
---@field private edx ffi.ctype*
---@field private esp ffi.ctype*
---@field private ebp ffi.ctype*
---@field private esi ffi.ctype*
---@field private edi ffi.ctype*
local context = {}
context.__index = context

local ffi = require("ffi")

--- Creates a new CPU context with all registers initialized to 0x00000000.
---@return Hook.Context
function context.new()
  return setmetatable({
    eax = ffi.new("uint32_t[1]", 0x00000000),
    ebx = ffi.new("uint32_t[1]", 0x00000000),
    ecx = ffi.new("uint32_t[1]", 0x00000000),
    edx = ffi.new("uint32_t[1]", 0x00000000),
    esp = ffi.new("uint32_t[1]", 0x00000000),
    ebp = ffi.new("uint32_t[1]", 0x00000000),
    esi = ffi.new("uint32_t[1]", 0x00000000),
    edi = ffi.new("uint32_t[1]", 0x00000000),
  }, context)
end

--- Returns the address of the specified register as a number.
---@param register string
---@return number
function context:address(register)
  assert(type(register) == "string")
  assert(#register > 0)

  local address = tonumber(ffi.cast("uint32_t", self[register]))

  ---@cast address number
  return address
end

--- Returns the value stored in the specified register.
---@param register string
---@return number
function context:value(register)
  assert(type(register) == "string")
  assert(#register > 0)

  return self[register][0]
end

--- Casts the value of the specified register to the specified type and returns it.
---@param register string
---@param typeof string
---@return any
function context:as(register, typeof)
  assert(type(register) == "string")
  assert(type(typeof) == "string")
  assert(#typeof > 0)
  assert(#register > 0)

  return ffi.cast(typeof .. "*", self:value(register))[0]
end

--- Retrieves a value from the stack at the specified offset and casts it to the specified type.
---@param param number
---@param typeof string
---@return any
function context:stack(param, typeof)
  assert(type(param) == "number")
  assert(type(typeof) == "string")
  assert(#typeof > 0)
  assert(param % 1 == 0)
  assert(param > 0)

  return ffi.cast(typeof .. "*", self:value("esp") + param * ffi.sizeof("void*"))[0]
end

return context
