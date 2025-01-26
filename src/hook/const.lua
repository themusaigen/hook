-- File: const.lua
-- Description: Module with constants
-- Author: themusaigen

return {
  X86_HOOK_SIZE          = 5,
  X86_CALL_OPCODE        = 0xE8,
  X86_JMP_OPCODE         = 0xE9,
  X86_SHORT_JMP_OPCODE   = 0xEB,
  X86_JO_OPCODE          = 0x70,
  X86_LOOPN_OPCODE       = 0xE0,
  X86_JO_2BYTE_OPCODE    = 0x80,
  X86_NOP_OPCODE         = 0x90,

  X86_2BYTE_INSN_PREF    = 0x0F,
  X86_2BYTE_INSN_SIZE    = 6,

  JMP_MASK               = 0xFD,
  JCC_MASK               = 0xF0,
  LOOPJE_MASK            = 0xFC,

  MEM_COMMIT             = 0x00001000,
  MEM_FREE               = 0x10000,
  MEM_RESERVE            = 0x00002000,
  MEM_RELEASE            = 0x00008000,

  MAX_MEMORY_RANGE       = 0x40000000,

  PAGE_EXECUTE_READWRITE = 0x40,
  PAGE_SIZE              = 4096
}
