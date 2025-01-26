-- File: sysinfo.lua
-- Description: GetSystemInfo implementation.
-- Author: themusaigen

local sysinfo = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

-- -------------------------------------------------------------------------- --

if jit.arch == "x86" then
  ffi.cdef [[
    typedef unsigned __int32 DWORD_PTR;
  ]]
elseif jit.arch == "x64" then
  ffi.cdef [[
    typedef unsigned __int64 DWORD_PTR;
  ]]
end

ffi.cdef([[
  typedef void* LPVOID;
  typedef unsigned short WORD;
  typedef unsigned long DWORD;

  typedef struct _SYSTEM_INFO {
    union {
      DWORD dwOemId;
      struct {
        WORD wProcessorArchitecture;
        WORD wReserved;
      } DUMMYSTRUCTNAME;
    } DUMMYUNIONNAME;
    DWORD     dwPageSize;
    LPVOID    lpMinimumApplicationAddress;
    LPVOID    lpMaximumApplicationAddress;
    DWORD_PTR dwActiveProcessorMask;
    DWORD     dwNumberOfProcessors;
    DWORD     dwProcessorType;
    DWORD     dwAllocationGranularity;
    WORD      wProcessorLevel;
    WORD      wProcessorRevision;
  } SYSTEM_INFO, *LPSYSTEM_INFO;

  void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
]])

-- -------------------------------------------------------------------------- --

function sysinfo.get_system_info()
  local si = ffi.new("SYSTEM_INFO[1]")
  ffi.C.GetSystemInfo(si)
  return si[0]
end

return sysinfo
