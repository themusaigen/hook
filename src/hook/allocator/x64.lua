-- File: x64/allocator.lua
-- Description: Module that allocates and frees the memory on 64-bit architecture.
-- Author: themusaigen

local allocator = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

local memmap = require("hook.sys.memmap")
local sysinfo = require("hook.sys.sysinfo")

local const = require("hook.const")

-- -------------------------------------------------------------------------- --

ffi.cdef [[
  void* VirtualAlloc(void* lpAddress, unsigned long dwSize, unsigned long  flAllocationType, unsigned long flProtect);
  int VirtualFree(void* lpAddress, unsigned long dwSize, unsigned long dwFreeType);
]]

-- -------------------------------------------------------------------------- --

--- Allocates the memory region with specified size.
---@param address integer
---@param size integer
---@return number?
function allocator.allocate(address, size)
  assert(type(address) == "number")
  assert(type(size) == "number")
  assert(address % 1 == 0)
  assert(size % 1 == 0)

  local function allocate(address, size)
    return tonumber(ffi.cast("unsigned int",
      ffi.C.VirtualAlloc(ffi.cast("void*", address), size, bit.bor(const.MEM_COMMIT, const.MEM_RESERVE),
        const.PAGE_EXECUTE_READWRITE)))
  end

  -- Get system information.
  local si = sysinfo.get_system_info()

  -- Get the ranges of the application.
  local minimal_address = tonumber(ffi.cast("unsigned __int64", si.lpMinimumApplicationAddress))
  local maximal_address = tonumber(ffi.cast("unsigned __int64", si.lpMaximumApplicationAddress))

  -- Bound ranges to the provided address.
  if (address > const.MAX_MEMORY_RANGE) and (minimal_address < (address - const.MAX_MEMORY_RANGE)) then
    minimal_address = address - const.MAX_MEMORY_RANGE
  end

  if (maximal_address > (address + const.MAX_MEMORY_RANGE)) then
    maximal_address = address + const.MAX_MEMORY_RANGE
  end

  -- Make room for one page.
  maximal_address = maximal_address - si.dwPageSize - 1

  -- Alloc a new block above.
  do
    local alloc = address
    while (alloc >= minimal_address) do
      alloc = memmap.find_prev_free_region(alloc, minimal_address, si.dwAllocationGranularity)
      if (alloc == 0) then
        break
      end

      local block = allocate(alloc, size)
      if not (block == 0) then
        return block
      end
    end
  end

  -- Alloc a new block below.
  do
    local alloc = address
    while (alloc <= maximal_address) do
      alloc = memmap.find_next_free_region(alloc, maximal_address, si.dwAllocationGranularity)
      if (alloc == 0) then
        break
      end

      local block = allocate(alloc, size)
      if not (block == 0) then
        return block
      end
    end
  end

  return nil
end

--- Frees up the memory region.
---@param address integer
function allocator.free(address)
  assert(type(address) == "number")
  assert(address % 1 == 0)

  ffi.C.VirtualFree(ffi.cast("void*", address), 0, const.MEM_RELEASE)
end

return allocator
