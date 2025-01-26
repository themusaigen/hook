-- File: virtualquery.lua
-- Description: `VirtualQuery` implementation
-- Author: themusaigen

local virtualquery = {}

-- -------------------------------------------------------------------------- --

local ffi = require("ffi")

-- -------------------------------------------------------------------------- --

ffi.cdef [[
  typedef const void* LPCVOID;
  typedef void* PVOID;
  typedef unsigned int SIZE_T;
]]

if jit.arch == "x86" then
  ffi.cdef [[
    typedef struct _MEMORY_BASIC_INFORMATION {
      DWORD BaseAddress;
      DWORD AllocationBase;
      DWORD AllocationProtect;
      DWORD RegionSize;
      DWORD State;
      DWORD Protect;
      DWORD Type;
  } MEMORY_BASIC_INFORMATION, *PMEMORY_BASIC_INFORMATION;
  ]]
elseif jit.arch == "x64" then
  ffi.cdef [[
    typedef unsigned __int64 ULONGLONG;

    typedef struct __declspec(align(16)) _MEMORY_BASIC_INFORMATION {
        ULONGLONG BaseAddress;
        ULONGLONG AllocationBase;
        DWORD     AllocationProtect;
        DWORD     __alignment1;
        ULONGLONG RegionSize;
        DWORD     State;
        DWORD     Protect;
        DWORD     Type;
        DWORD     __alignment2;
    } MEMORY_BASIC_INFORMATION, *PMEMORY_BASIC_INFORMATION;
  ]]
end

ffi.cdef [[
  SIZE_T VirtualQuery(
    LPCVOID                   lpAddress,
    PMEMORY_BASIC_INFORMATION lpBuffer,
    SIZE_T                    dwLength
  );
]]

-- -------------------------------------------------------------------------- --

function virtualquery.query(address)
  local mbi = ffi.new("MEMORY_BASIC_INFORMATION[1]")
  local result = ffi.C.VirtualQuery(ffi.cast("const void*", address), mbi, ffi.sizeof("MEMORY_BASIC_INFORMATION"))
  if (result == 0) then
    return false
  else
    return mbi[0]
  end
end

return virtualquery
