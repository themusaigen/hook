---@class Hook
---@field protected prototype string
---@field protected address integer
---@field protected callback function?
---@field protected size integer
---@field protected relay function
---@field protected original_bytes ffi.cdata*
---@field protected trampoline ffi.cdata*
---@field protected codecave Codecave
---@field protected usercode_jump_backup ffi.cdata*
---@field installed boolean
---@field install fun(self: Hook): boolean, integer?
---@field remove fun(self: Hook): boolean, integer?
---@field call fun(self: Hook, ...: any): any
---@field target fun(self: Hook, address: integer): boolean
---@field callback fun(self: Hook, callback: function)
local hook = {
  _NAME = "hook",
  _DESCRIPTION = "Hooking library for GTA:SA written in Lua",
  _VERSION = "1.5.0",
  _RELEASE = "release-candidate",
  _AUTHOR = "Musaigen"
}
hook.__index = hook

--- The pool of the hooks.
local pool = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

-- -------------------------------------------------------------------------- --

local memory = require("hook.memory")
local hde = require("hook.hde")
local codegenerator = require("hook.codegenerator")
local utility = require("hook.utility")
local const = require("hook.const")
local errors = require("hook.errors")

-- -------------------------------------------------------------------------- --

local cast = ffi.cast

-- -------------------------------------------------------------------------- --

--- Creates new jump hook.
---@param prototype string
---@param address integer?
---@param callback function?
---@param autoinstall boolean?
---@return Hook
function hook.new(prototype, address, callback, autoinstall)
  -- Validate the incoming data.
  assert(type(prototype) == "string")

  if address then
    assert(type(address) == "number")
    assert(address % 1 == 0)
  end

  -- If a callback is passed, we check that this is a function.
  if callback then
    assert(type(callback) == "function")
  end

  -- Validate autoinstall boolean if passed.
  if autoinstall then
    assert(type(autoinstall) == "boolean")

    -- We can't autoinstall if don't have address.
    if not address then
      autoinstall = false
    end
  end

  ---@type Hook
  local self = setmetatable({
    prototype            = prototype,
    address              = address,
    callback             = callback,
    size                 = utility.get_at_least_n_bytes(address, const.X86_HOOK_SIZE),
    relay                = nil,
    original_bytes       = nil,
    trampoline           = nil, -- The function that we use to call the original.
    codecave             = nil, -- A block of memory allocated via VirtualAlloc.
    usercode_jump_backup = nil,
    installed            = false,
  }, hook)

  -- Create relay. (Killer-feature of dynamic typing)
  self.relay = function(...)
    ---@diagnostic disable-next-line: invisible
    if self.callback then
      ---@diagnostic disable-next-line: invisible
      return self.callback(self, ...)
    else
      ---@diagnostic disable-next-line: invisible
      return self.trampoline(...)
    end
  end

  -- Add new hook to the pool.
  pool[#pool + 1] = self

  -- Disable JIT compilation for callback.
  jit.off(self.relay, true)

  -- Auto install if needed.
  if autoinstall then
    self:install()
  end

  -- Export hook instance to user.
  return self
end

--- Installs the hook.
---@param self Hook
---@return boolean # The status of the hook installation.
---@return integer? # The error code.
function hook:install()
  if self.installed then
    return false, errors.ERROR_ALREADY_INSTALLED
  end

  -- Ñheck that we have enough bytes for the hook.
  if (self.size < const.X86_HOOK_SIZE) then
    return false, errors.ERROR_NOT_ENOUGH_BYTES
  end

  -- If we got the usercode backup.
  if self.usercode_jump_backup then
    -- Then just restore him.
    utility.copy(self.codecave:get_region(), self.usercode_jump_backup, const.X86_HOOK_SIZE)

    -- Mark as installed.
    self.installed = true

    -- Succesfull reinstalling.
    return true
  end

  -- Generate trampoline.
  if not self.codecave then
    -- Get the address of the relay.
    local relay_address = tonumber(cast("unsigned int", cast("void*", cast(self.prototype, self.relay))))

    -- Generate codecave.
    local status, codecave, err = codegenerator.new(self.address, const.X86_HOOK_SIZE,
      ---@diagnostic disable-next-line: param-type-mismatch
      relay_address)

    -- If anything succesfull, assign new codecave.
    -- Otherwise return error.
    if status and codecave then
      self.codecave = codecave
    else
      return false, err
    end
  end

  -- If we have not created storage for bytes before, we will create it and save the bytes.
  if not self.original_bytes then
    self.original_bytes = ffi.new("uint8_t[?]", self.size)

    -- Copy bytes to the storage.
    utility.copy(self.original_bytes, self.address, self.size)
  end

  -- Unprotect memory.
  local old_protection = memory.unprotect(self.address, self.size)

  -- Set jump opcode.
  if not (memory.getuint8(self.address) == const.X86_CALL_OPCODE) then
    memory.setuint8(self.address, const.X86_JMP_OPCODE)

    -- Set new trampoline after the usercode jump instruction.
    self.trampoline = ffi.cast(self.prototype, self.codecave:get_region() + const.X86_HOOK_SIZE)
  else
    -- Call opcode, use call destination for trampoline.
    local branch_destination = utility.restore_absolute_address(memory.getuint32(self.address + 1), self.address,
      const.X86_HOOK_SIZE)

    -- Set new trampoline.
    self.trampoline = ffi.cast(self.prototype, branch_destination)
  end

  -- Set jump to relay.
  memory.setuint32(self.address + 1,
    utility.get_relative_address(self.codecave:get_region(), self.address, const.X86_HOOK_SIZE))

  -- Nop exceed bytes.
  if (self.size > const.X86_HOOK_SIZE) then
    memory.fill(self.address + const.X86_HOOK_SIZE, const.X86_NOP_OPCODE, self.size - const.X86_HOOK_SIZE)
  end

  -- Restore protect.
  memory.protect(self.address, self.size, old_protection)

  -- Mark as installed.
  self.installed = true

  -- Succesfull installation.
  return true
end

--- Removes the hook.
---@return boolean # The status of the hook removing.
---@return integer? # The error code.
function hook:remove()
  if not (self.installed) then
    return false, errors.ERROR_ALREADY_UNINSTALLED
  end

  --- Fully unloads the hook. Garbage collects and frees all allocated memory.
  ---@return boolean
  local function full_unload()
    -- Make sure this memory region is unprotected.
    local protect = memory.unprotect(self.address, self.size)

    -- Restore original bytes.
    utility.copy(self.address, self.original_bytes, self.size)

    -- Restore original protection.
    memory.protect(self.address, self.size, protect)

    -- Free trampoline.
    self.codecave:free()

    -- Garbage collect.
    self.codecave = nil
    self.original_bytes = nil
    self.usercode_jump_backup = nil

    -- Mark as uninstalled.
    self.installed = false

    -- Succesfull removing.
    return true
  end

  --- Patches the hook and makes backup for usercode jumps.
  ---@return boolean
  local function patch_hook()
    -- Create storage for usercode jump backup.
    self.usercode_jump_backup = ffi.new("uint8_t[5]")

    -- Copy jump to the usercode.
    self.codecave:extract(self.usercode_jump_backup, 0, const.X86_HOOK_SIZE)

    -- Nop jump to usercode.
    self.codecave:fill(0, const.X86_NOP_OPCODE, const.X86_HOOK_SIZE)

    -- Mark as uninstalled.
    self.installed = false

    -- We removed, but not fully.
    return true
  end

  -- Disassemble the target address.
  local hs = hde.disassemble(self.address)

  -- If we got any errors, unload fully.
  if bit.band(hs.flags, hde.F_ERROR) > 0 then
    return full_unload()
  end

  -- If got relative imm32 instruction.
  if (bit.band(hs.flags, hde.F_RELATIVE) > 0) and (bit.band(hs.flags, hde.F_IMM32) > 0) then
    -- Get the destination and check is branch pointing at our trampoline.
    -- If yes, fully unload, otherwise patch the hook.
    local destination = utility.restore_absolute_address(hs.imm.imm32, self.address, hs.len)
    if (destination == self.codecave:get_region()) then
      return full_unload()
    else
      return patch_hook()
    end
  else
    -- Fully unload if no any relative instructions here.
    return full_unload()
  end
end

--- Calls the original function.
---@param ... any
---@return any
function hook:call(...)
  return self.trampoline(...)
end

--- Sets the new hook address.
---@param address integer
---@return boolean
function hook:target(address)
  -- Can't update the address when hook installed.
  if self.installed then
    return false
  end

  -- Verify address type and value.
  assert(type(address) == "number")
  assert(address % 1 == 0)

  -- Update address.
  self.address = address

  -- Update size.
  self.size = utility.get_at_least_n_bytes(self.address, const.X86_HOOK_SIZE)

  return true
end

--- Sets the new function callback
---@param callback function
function hook:redirect(callback)
  assert(type(callback) == "function")

  -- Assign new callback.
  self.callback = callback
end

-- Auto unloading of all hooks.
addEventHandler("onScriptTerminate", function(scr)
  if scr == script.this then
    for _, hk in ipairs(pool) do
      hk:remove()
    end
  end
end)

return hook
