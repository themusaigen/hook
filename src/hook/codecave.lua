-- File: codecave.lua
-- Description: Module for creating and interacting with codecaves.
-- Author: themusaigen

---@class Codecave
---@field protected region integer
---@field protected size integer
---@field protected offset integer
local Codecave = {}
Codecave.__index = Codecave

-- -------------------------------------------------------------------------- --

local memory = require("memory")

local allocator = require("hook.allocator")
local errors = require("hook.errors")
local utility = require("hook.utility")

-- -------------------------------------------------------------------------- --

-- The data type sizes.
---@alias DataType string | "int8" | "int16" | "int32" | "int64" | "uint8" | "uint16" | "uint32" | "uint64" | "float" | "double"
local types = {
  int8 = 1,
  int16 = 2,
  int32 = 4,
  int64 = 8,
  uint8 = 1,
  uint16 = 2,
  uint32 = 4,
  uint64 = 8,
  float = 4,
  double = 8
}

--- Creates new codecave
---@param address integer
---@param size integer
---@return Codecave?
---@return integer? # The error code.
function Codecave.new(address, size)
  assert(type(address) == "number")
  assert(type(size) == "number")
  assert(address % 1 == 0)
  assert(size % 1 == 0)

  local region = allocator.allocate(address, size)
  if not region then
    return nil, errors.ERROR_BAD_ALLOCATION
  else
    ---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable({
      region = region,
      offset = 0,
      size = size
    }, Codecave)
  end
end

--- Pushes the new value with specified type.
---@param typeof DataType
---@param value number
---@return boolean # The status of pushing the value.
---@return integer? # The error code.
function Codecave:push(typeof, value)
  assert(type(typeof) == "string")
  assert(type(value) == "number")

  -- Get the size of the data type.
  local size = types[typeof]
  assert(type(size) == "number")

  -- We have this type, so we add the value to the codecave.
  -- We also check that we still have empty bytes in the codecave.
  if (self.offset + size <= self.size) then
    memory[("set%s"):format(typeof)](self.region + self.offset, value, size)

    -- Switch to the next position.
    self.offset = self.offset + size
    return true
  end

  return false, errors.ERROR_CODECAVE_FULL
end

--- Sets certain data within the allocated memory region.
---@param typeof DataType
---@param offset integer
---@param value number
---@return boolean # The status of setting the value
---@return integer? # The error code.
function Codecave:set(typeof, offset, value)
  assert(type(typeof) == "string")
  assert(type(offset) == "number")
  assert(offset % 1 == 0)
  assert(type(value) == "number")

  -- Get the size of the data type.
  local size = types[typeof]
  assert(type(size) == "number")

  -- We check whether the specified offset is located within the memory region.
  if (offset >= 0) and (offset <= (self.size - size)) then
    -- Set the value.
    memory[("set%s"):format(typeof)](self.region + offset, value, size)

    -- All ok.
    return true
  end
  return false, errors.ERROR_OUT_OF_BOUNDS
end

--- Inserts a value into the memory region. Analogue of `memory.copy`
---@param address integer
---@param size integer
---@return boolean # The status of inserting the value.
---@return integer? # The error code.
function Codecave:insert(address, size)
  assert(type(address) == "number")
  assert(type(size) == "number")
  assert(address % 1 == 0)
  assert(size % 1 == 0)
  assert(size > 0)

  -- Check that we are within the memory region.
  if ((self.offset + size) <= self.size) then
    -- Copy the region.
    memory.copy(self.region + self.offset, address, size)

    -- Switch to the next position.
    self.offset = self.offset + size

    -- All ok.
    return true
  end
  return false, errors.ERROR_OUT_OF_BOUNDS
end

--- Fills a value into the memory region. Analogue of `memory.fill`
---@param offset integer
---@param value integer
---@param size integer
---@return boolean # The status of the filling.
---@return integer? # The error code.
function Codecave:fill(offset, value, size)
  assert(type(offset) == "number")
  assert(type(value) == "number")
  assert(type(size) == "number")
  assert(offset % 1 == 0)
  assert(offset >= 0)
  assert(value % 1 == 0)
  assert(value <= 255)
  assert(size % 1 == 0)
  assert(size > 0)

  -- Check that we are within the memory region.
  if ((offset <= (self.size - size))) then
    -- Fill the region.
    memory.fill(self.region + offset, value, size)

    -- All ok.
    return true
  end
  return false, errors.ERROR_OUT_OF_BOUNDS
end

--- Extracts the value at the specified offset to cdata.
---@param destination ffi.cdata*
---@param offset integer
---@param size integer
function Codecave:extract(destination, offset, size)
  assert(type(offset) == "number")
  assert(type(size) == "number")
  assert(offset % 1 == 0)
  assert(size % 1 == 0)
  assert(size > 0)

  -- Process copy.
  utility.copy(destination, self.region + offset, size)
end

--- Returns the address to the starting point of the memory region.
---@return integer
function Codecave:get_region()
  return self.region
end

--- Returns the size of the memory region.
---@return integer
function Codecave:get_size()
  return self.size
end

--- Returns the count of used (filled) bytes.
---@return integer
function Codecave:get_count_of_used_bytes()
  return self.offset
end

--- Returns the point in memory where the writing cursor is currently located.
---@return integer
function Codecave:now()
  return self.region + self.offset
end

--- Frees the memory region.
function Codecave:free()
  allocator.free(self.region)
end

return Codecave
