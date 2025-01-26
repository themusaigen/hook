script_name("hook-demo")
script_version("1.0.0")
script_author("Musaigen")
-- -------------------------------------------------------------------------- --

require("sysinfo")
require("virtualquery")

local hook = require("hook")

local ffi = require("ffi")

-- -------------------------------------------------------------------------- --

---@type Hook[]
local hooks = {}

-- -------------------------------------------------------------------------- --

function main()
  if not isSampLoaded() then
    return
  end
  while not isSampAvailable() do
    wait(0)
  end

  sampRegisterChatCommand("hook.new", function()
    local hook_idx = #hooks + 1

    hooks[hook_idx] = hook.new("void(__thiscall*)(void*, int, const char*, const char*, unsigned long, unsigned long)",
      sampGetBase() + 0x64010, function(hook, chat, type, text, prefix, textColor, prefixColor)
        hook:call(chat, type, ("[%d]: %s"):format(hook_idx, ffi.string(text)), prefix, textColor, prefixColor)
      end, true)
  end)

  sampRegisterChatCommand("hook.disable", function(arg)
    arg = arg and (#arg > 0 and arg)

    if arg and tonumber(arg) then
      hooks[tonumber(arg)]:remove()
    end
  end)

  sampRegisterChatCommand("hook.enable", function(arg)
    arg = arg and (#arg > 0 and arg)

    if arg and tonumber(arg) then
      hooks[tonumber(arg)]:install()
    end
  end)

  wait(-1)
end
