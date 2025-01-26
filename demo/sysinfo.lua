local sysinfo = require("hook.sys.sysinfo")
local ffi = require("ffi")

local si = sysinfo.get_system_info()

print(tonumber(ffi.cast("unsigned int", si.lpMinimumApplicationAddress)))
print(tonumber(ffi.cast("unsigned int", si.lpMaximumApplicationAddress)))
print(si.dwPageSize)
print(si.dwAllocationGranularity)

return {}
