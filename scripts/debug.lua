-- (Debug mode)
db = false
db = true

function db_func(func) if db then func() end end

function dbw(str, value) if db then DebugWatch(str, value) end end
function dbp(str, newLine) if db then DebugPrint(str .. ternary(newLine, '\n', '')) print(str .. ternary(newLine, '\n', '')) end end

function dbl(p1, p2, c1, c2, c3, a) if db then DebugLine(p1, p2, c1 or 1, c2 or 1, c3 or 1, a or 1) end end
function dbdd(pos,w,l,r,g,b,a,dt) DrawDot(pos,w,l,r,g,b,a,dt) end
function dbray(tr, dist, c1, c2, c3, a) dbl(tr.pos, TransformToParentPoint(tr, Vec(0,0,-dist or -10)), c1, c2, c3, a) end