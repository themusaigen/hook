-- File: memmap.lua
-- Description: A module that searches for the nearest free memory page to the specified address.
-- Author: themusaigen

local memmap = {}

-- -------------------------------------------------------------------------- --

local virtualquery = require("hook.sys.virtualquery")

local const = require("hook.const")

-- -------------------------------------------------------------------------- --

-- By MinHook.
-- Get MinHook at https://github.com/TsudaKageyu/minhook/

function memmap.find_prev_free_region(address, min_address, granularity)
  assert(type(address) == "number")
  assert(type(min_address) == "number")
  assert(type(granularity) == "number")
  assert(address % 1 == 0)
  assert(min_address % 1 == 0)
  assert(granularity % 1 == 0)

  local try_addr = address

  -- Round down to the allocation granularity.
  try_addr = try_addr - (try_addr % granularity)

  -- Start from the previous allocation granularity multiply.
  try_addr = try_addr - granularity

  while (try_addr >= min_address) do
    local mbi = virtualquery.query(try_addr)
    if not mbi then
      break
    end

    if mbi.State == const.MEM_FREE then
      return try_addr
    end

    if mbi.AllocationBase < granularity then
      break
    end

    try_addr = mbi.AllocationBase - granularity
  end

  return 0
end

function memmap.find_next_free_region(address, max_address, granularity)
  assert(type(address) == "number")
  assert(type(max_address) == "number")
  assert(type(granularity) == "number")
  assert(address % 1 == 0)
  assert(max_address % 1 == 0)
  assert(granularity % 1 == 0)

  local try_addr = address

  -- Round down to the allocation granularity.
  try_addr = try_addr - (try_addr % granularity)

  -- Start from the next allocation granularity multiply.
  try_addr = try_addr + granularity

  while (try_addr <= max_address) do
    local mbi = virtualquery.query(try_addr)
    if not mbi then
      break
    end

    if mbi.State == const.MEM_FREE then
      return try_addr
    end

    try_addr = mbi.BaseAddress + mbi.RegionSize

    -- Round up to the next allocation granularity.
    try_addr = try_addr + granularity - 1
    try_addr = try_addr - (try_addr % granularity)
  end

  return 0
end

return memmap
