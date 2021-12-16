-- (Debug mode)
db = false
db = true

function dbw(str, value) if db then DebugWatch(str, value) end end
function dbp(str) if db then DebugPrint(str) end end