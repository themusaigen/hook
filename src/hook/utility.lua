-- File: utility.lua
-- Description: Module that contains utilities.
-- Author: themusaigen

local utility = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

local hde = require("hook.hde")

-- -------------------------------------------------------------------------- --

--- Calculates the relative address from `origin` to `target` with size `size`
---@param target integer
---@param origin integer
---@param size integer
function utility.get_relative_address(target, origin, size)
  assert(type(target) == "number")
  assert(type(origin) == "number")
  assert(type(size) == "number")
  assert(target % 1 == 0)
  assert(origin % 1 == 0)
  assert(size % 1 == 0)

  return target - origin - size
end

function utility.restore_absolute_address(relative, origin, size)
  assert(type(relative) == "number")
  assert(type(origin) == "number")
  assert(type(size) == "number")
  assert(relative % 1 == 0)
  assert(origin % 1 == 0)
  assert(size % 1 == 0)

  return relative + origin + size
end

--- Wrapper for ffi.copy
---@param dst any
---@param src any
---@param len integer
function utility.copy(dst, src, len)
  ffi.copy(ffi.cast("void*", dst), ffi.cast("const void*", src), len)
end

--- Iterates on instructions at the specified address until it counts instructions per N bytes.
---@param target integer?
---@param minimal_size integer
---@return integer
function utility.get_at_least_n_bytes(target, minimal_size)
  if not target then
    return 0
  end

  assert(type(target) == "number")
  assert(type(minimal_size) == "number")
  assert(target % 1 == 0)
  assert(minimal_size % 1 == 0)

  local size = 0

  while size < minimal_size do
    local hs = hde.disassemble(target)

    if bit.band(hs.flags, hde.F_ERROR) > 0 then
      break
    end

    size = size + hs.len
    target = target + hs.len
  end

  return size
end

return utility
