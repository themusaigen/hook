-- File: allocator.lua
-- Description: Module that allocates and frees the memory.
-- Author: themusaigen

local allocator = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

local const = require("hook.const")

-- -------------------------------------------------------------------------- --

ffi.cdef [[
  void* VirtualAlloc(void* lpAddress, unsigned long dwSize, unsigned long  flAllocationType, unsigned long flProtect);
  int VirtualFree(void* lpAddress, unsigned long dwSize, unsigned long dwFreeType);
]]

-- -------------------------------------------------------------------------- --

--- Allocates the memory region with specified size.
---@param size integer
---@return number?
function allocator.allocate(size)
  assert(type(size) == "number")
  assert(size % 1 == 0)

  return tonumber(ffi.cast("unsigned int",
    ffi.C.VirtualAlloc(ffi.cast("void*", 0), size, bit.bor(const.MEM_COMMIT, const.MEM_RESERVE),
      const.PAGE_EXECUTE_READWRITE)))
end

--- Frees up the memory region.
---@param address integer
function allocator.free(address)
  assert(type(address) == "number")
  assert(address % 1 == 0)

  ffi.C.VirtualFree(ffi.cast("void*", address), 0, const.MEM_RELEASE)
end

return allocator
