-- File: codegenerator.lua
-- Description: Module that generates trampoline.
-- Author: themusaigen

local codegenerator = {}

-- -------------------------------------------------------------------------- --

local ffi           = require("ffi")
local memory        = require("memory")
local hde           = require("hde")

local const         = require("hook.const")
local utility       = require("hook.utility")
local errors        = require("hook.errors")

-- -------------------------------------------------------------------------- --

ffi.cdef [[
  void* VirtualAlloc(void* lpAddress, unsigned long dwSize, unsigned long  flAllocationType, unsigned long flProtect);
  int VirtualFree(void* lpAddress, unsigned long dwSize, unsigned long dwFreeType);
]]

--- Allocates the memory block via VirtualAlloc.
---@param size integer
---@return integer?
function codegenerator.allocate(size)
  assert(type(size) == "number")
  assert(size % 1 == 0)

  return tonumber(ffi.cast("unsigned int",
    ffi.C.VirtualAlloc(ffi.cast("void*", 0), size, bit.bor(const.MEM_COMMIT, const.MEM_RESERVE),
      const.PAGE_EXECUTE_READWRITE)))
end

--- Frees up memory.
---@param address integer
function codegenerator.free(address)
  assert(type(address) == "number")
  assert(address % 1 == 0)

  ffi.C.VirtualFree(ffi.cast("void*", address), 0, const.MEM_RELEASE)
end

--- Creates new trampoline
---@param address integer
---@param minimal_size integer
---@param target integer
---@return boolean # The status of code generation.
---@return integer? # The address of the trampoline.
---@return integer? # The error code.
function codegenerator.new(address, minimal_size, target)
  assert(type(address) == "number")
  assert(type(minimal_size) == "number")
  assert(address % 1 == 0)
  assert(minimal_size % 1 == 0)

  -- Save the starting address value for the end of the code generation.
  local start_address = address

  -- Allocating a new memory block.
  local block = codegenerator.allocate(const.PAGE_SIZE)
  if not block then
    return false, nil, errors.ERROR_BAD_ALLOCATION
  end

  -- Label: jump to the usercode.
  memory.setuint8(block, const.X86_JMP_OPCODE)
  memory.setuint32(block + 1, 0x00000000)

  -- The point from the beginning of the memory block.
  local size = 0
  local offset = 5

  -- Iterate by bytes until we save N instructions.
  while (size < minimal_size) do
    local hs = hde.disassemble(address)

    local instruction_size = hs.len

    -- Error acquired.
    if bit.band(hs.flags, hde.F_ERROR) > 0 then
      break
    end

    -- MinHook part.
    -- Get MinHook at https://github.com/TsudaKageyu/minhook/
    if (hs.opcode == const.X86_CALL_OPCODE) then
      local dest = utility.restore_absolute_address(hs.imm.imm32, address, hs.len)

      memory.setuint8(block + offset, const.X86_CALL_OPCODE)
      memory.setuint32(block + offset + 1, utility.get_relative_address(dest, block + offset, hs.len))
    elseif (bit.band(hs.opcode, const.JMP_MASK) == const.X86_JMP_OPCODE) then
      local dest = address + hs.len

      if (hs.opcode == const.X86_SHORT_JMP_OPCODE) then
        dest = dest + hs.imm.imm8
      else
        dest = dest + hs.imm.imm32
      end

      memory.setuint8(block + offset, const.X86_JMP_OPCODE)
      memory.setuint32(block + offset + 1, utility.get_relative_address(dest, block + offset, const.X86_HOOK_SIZE))

      -- We've transformed a short jump into a long jump, so we have to change the size.
      instruction_size = const.X86_HOOK_SIZE
    elseif (bit.band(hs.opcode, const.JCC_MASK) == const.X86_JO_OPCODE) or
        (bit.band(hs.opcode2, const.JCC_MASK) == const.X86_JO_2BYTE_OPCODE) then
      local dest = address + hs.len

      if (bit.band(hs.opcode, const.JCC_MASK) == const.X86_JO_OPCODE) then
        dest = dest + hs.imm.imm8
      else
        dest = dest + hs.imm.imm32
      end

      local cond = bit.band((hs.opcode ~= const.X86_64_2BYTE_INSN_PREF) and hs.opcode or hs.opcode2,
        const.X86_64_2BYTE_INSN_PREF)

      memory.setuint8(block + offset, const.X86_64_2BYTE_INSN_PREF)
      memory.setuint8(block + offset + 1, bit.bor(const.X86_JO_2BYTE_OPCODE, cond))
      memory.setuint32(block + offset + 2,
        utility.get_relative_address(dest, block + offset, const.X86_64_2BYTE_INSN_SIZE))

      instruction_size = const.X86_64_2BYTE_INSN_SIZE
    elseif (bit.band(hs.opcode, const.LOOPJE_MASK) == const.X86_LOOPN_OPCODE) then
      break
    else
      memory.copy(block + offset, address, hs.len)
    end

    address = address + hs.len
    size = size + instruction_size
    offset = offset + instruction_size
  end


  -- Jump to the back.
  memory.setuint8(block + offset, const.X86_JMP_OPCODE)
  memory.setuint32(block + offset + 1,
    utility.get_relative_address(start_address + const.X86_HOOK_SIZE, block + offset, const.X86_HOOK_SIZE))

  offset = offset + const.X86_HOOK_SIZE

  -- Jump to the usercode.
  memory.setuint32(block + 1, utility.get_relative_address(block + offset, block, const.X86_HOOK_SIZE))

  -- Call `target`.
  memory.setuint8(block + offset, const.X86_JMP_OPCODE)
  memory.setuint32(block + offset + 1, utility.get_relative_address(target, block + offset, const.X86_HOOK_SIZE))

  -- Export trampoline.

  -- No errors acquired in process.
  if (size >= minimal_size) then
    return true, block
  else
    codegenerator.free(block)
    return false, nil, errors.ERROR_BAD_INSTRUCTIONS
  end
end

return codegenerator
