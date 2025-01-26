local virtualquery = require("hook.sys.virtualquery")

local mbi = virtualquery.query(0x53BEE0)

print(mbi.State, mbi.Protect, mbi.Type)

return {}
