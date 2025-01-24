-- File: codegenerator.lua
-- Description: Module that generates trampoline.
-- Author: themusaigen

local codegenerator = {}

-- -------------------------------------------------------------------------- --

local hde           = require("hde")

local Codecave      = require("hook.codecave")

local const         = require("hook.const")
local errors        = require("hook.errors")
local utility       = require("hook.utility")

-- -------------------------------------------------------------------------- --

--- Creates new trampoline
---@param address integer
---@param minimal_size integer
---@param target integer
---@return boolean # The status of code generation.
---@return Codecave? # The address of the trampoline.
---@return integer? # The error code.
function codegenerator.new(address, minimal_size, target)
  assert(type(address) == "number")
  assert(type(minimal_size) == "number")
  assert(address % 1 == 0)
  assert(minimal_size % 1 == 0)

  -- Save the starting address value for the end of the code generation.
  local start_address = address

  -- Allocating a new memory block.
  local codecave, err = Codecave.new(const.PAGE_SIZE)
  if not codecave then
    return false, nil, err
  end

  -- Label: jump to the usercode.
  codecave:push("uint8", const.X86_JMP_OPCODE)
  codecave:push("uint32", 0x00000000)

  -- The point from the beginning of the memory block.
  local size = 0

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

      codecave:push("uint8", const.X86_CALL_OPCODE)
      codecave:push("uint32", utility.get_relative_address(dest, codecave:now() - 1, hs.len))
    elseif (bit.band(hs.opcode, const.JMP_MASK) == const.X86_JMP_OPCODE) then
      local dest = address + hs.len

      if (hs.opcode == const.X86_SHORT_JMP_OPCODE) then
        dest = dest + hs.imm.imm8
      else
        dest = dest + hs.imm.imm32
      end

      codecave:push("uint8", const.X86_JMP_OPCODE)
      codecave:push("uint32", utility.get_relative_address(dest, codecave:now() - 1, const.X86_HOOK_SIZE))

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

      local cond = bit.band((hs.opcode ~= const.X86_2BYTE_INSN_PREF) and hs.opcode or hs.opcode2,
        const.X86_2BYTE_INSN_PREF)

      codecave:push("uint8", const.X86_2BYTE_INSN_PREF)
      codecave:push("uint8", bit.bor(const.X86_JO_2BYTE_OPCODE, cond))
      codecave:push("uint32", utility.get_relative_address(dest, codecave:now() - 2, const.X86_2BYTE_INSN_SIZE))

      instruction_size = const.X86_2BYTE_INSN_SIZE
    elseif (bit.band(hs.opcode, const.LOOPJE_MASK) == const.X86_LOOPN_OPCODE) then
      break
    else
      codecave:insert(address, hs.len)
    end

    address = address + hs.len
    size = size + instruction_size
  end

  -- Jump to the back.
  codecave:push("uint8", const.X86_JMP_OPCODE)
  codecave:push("uint32",
    utility.get_relative_address(start_address + const.X86_HOOK_SIZE, codecave:now() - 1, const.X86_HOOK_SIZE))

  -- Jump to the usercode.
  codecave:set("uint32", 1, utility.get_relative_address(codecave:now(), codecave:get_region(), const.X86_HOOK_SIZE))

  -- Call `target`
  codecave:push("uint8", const.X86_JMP_OPCODE)
  codecave:push("uint32", utility.get_relative_address(target, codecave:now() - 1, const.X86_HOOK_SIZE))

  -- Export trampoline.

  -- No errors acquired in process.
  if (size >= minimal_size) then
    return true, codecave
  else
    codecave:free()
    return false, nil, errors.ERROR_BAD_INSTRUCTIONS
  end
end

return codegenerator
