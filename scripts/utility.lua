--[[VECTORS]]
    -- Distance between two vectors.
    function VecDist(vec1, vec2) return VecLength(VecSub(vec1, vec2)) end
    -- Divide a vector by another vector.
    function VecDiv(v, n) n = n or 1 return Vec(v[1] / n, v[2] / n, v[3] / n) end
    -- Add all vectors in a table together.
    function VecAddAll(vectorsTable) local v = Vec(0,0,0) for i = 1, #vectorsTable do VecAdd(v, vectorsTable[i]) end return v end
    --- Returns a vector with random values.
    function rdmVec(min, max) return Vec(rdm(min, max),rdm(min, max),rdm(min, max)) end
    ---Print QuatEulers or vectors.
    function VecPrint(vec, decimals, label)
        DebugPrint((label or "") .. 
            "  " .. sfn(vec[1], decimals or 2) ..
            "  " .. sfn(vec[2], decimals or 2) ..
            "  " .. sfn(vec[3], decimals or 2))
    end



--[[QUAT]]
    function QuatLookDown(pos) return QuatLookAt(pos, VecAdd(pos, Vec(0, -1, 0))) end
    function QuatLookUp(pos) return QuatLookAt(pos, VecAdd(pos, Vec(0, 1, 0))) end



--[[AABB]]
    function AabbDraw(v1, v2, r, g, b, a)
        r = r or 1
        g = g or 1
        b = b or 1
        a = a or 1
        local x1 = v1[1]
        local y1 = v1[2]
        local z1 = v1[3]
        local x2 = v2[1]
        local y2 = v2[2]
        local z2 = v2[3]
        -- x lines top
        DebugLine(Vec(x1,y1,z1), Vec(x2,y1,z1), r, g, b, a)
        DebugLine(Vec(x1,y1,z2), Vec(x2,y1,z2), r, g, b, a)
        -- x lines bottom
        DebugLine(Vec(x1,y2,z1), Vec(x2,y2,z1), r, g, b, a)
        DebugLine(Vec(x1,y2,z2), Vec(x2,y2,z2), r, g, b, a)
        -- y lines
        DebugLine(Vec(x1,y1,z1), Vec(x1,y2,z1), r, g, b, a)
        DebugLine(Vec(x2,y1,z1), Vec(x2,y2,z1), r, g, b, a)
        DebugLine(Vec(x1,y1,z2), Vec(x1,y2,z2), r, g, b, a)
        DebugLine(Vec(x2,y1,z2), Vec(x2,y2,z2), r, g, b, a)
        -- z lines top
        DebugLine(Vec(x2,y1,z1), Vec(x2,y1,z2), r, g, b, a)
        DebugLine(Vec(x2,y2,z1), Vec(x2,y2,z2), r, g, b, a)
        -- z lines bottom
        DebugLine(Vec(x1,y1,z2), Vec(x1,y1,z1), r, g, b, a)
        DebugLine(Vec(x1,y2,z2), Vec(x1,y2,z1), r, g, b, a)
    end
    function AabbCheckOverlap(aMin, aMax, bMin, bMax)
        return 
        (aMin[1] <= bMax[1] and aMax[1] >= bMin[1]) and
        (aMin[2] <= bMax[2] and aMax[2] >= bMin[2]) and
        (aMin[3] <= bMax[3] and aMax[3] >= bMin[3])
    end
    function AabbCheckPointInside(aMin, aMax, p)
        return 
        (p[1] <= aMax[1] and p[1] >= aMin[1]) and
        (p[2] <= aMax[2] and p[2] >= aMin[2]) and
        (p[3] <= aMax[3] and p[3] >= aMin[3])
    end
    function AabbClosestEdge(pos, shape)

        local shapeAabbMin, shapeAabbMax = GetShapeBounds(shape)
        local bCenterY = VecLerp(shapeAabbMin, shapeAabbMax, 0.5)[2]
        local edges = {}
        edges[1] = Vec(shapeAabbMin[1], bCenterY, shapeAabbMin[3]) -- a
        edges[2] = Vec(shapeAabbMax[1], bCenterY, shapeAabbMin[3]) -- b
        edges[3] = Vec(shapeAabbMin[1], bCenterY, shapeAabbMax[3]) -- c
        edges[4] = Vec(shapeAabbMax[1], bCenterY, shapeAabbMax[3]) -- d

        local closestEdge = edges[1] -- find closest edge
        local index = 1
        for i = 1, #edges do
            local edge = edges[i]

            local edgeDist = VecDist(pos, edge)
            local closesEdgeDist = VecDist(pos, closestEdge)

            if edgeDist < closesEdgeDist then
                closestEdge = edge
                index = i
            end
        end
        return closestEdge, index
    end
    --- Sort edges by closest to startPos and closest to endPos. Return sorted table.
    function AabbSortEdges(startPos, endPos, edges)
        local s, startIndex = aabbClosestEdge(startPos, edges)
        local e, endIndex = aabbClosestEdge(endPos, edges)
        -- Swap first index with startPos and last index with endPos. Everything between stays same.
        edges = tableSwapIndex(edges, 1, startIndex)
        edges = tableSwapIndex(edges, #edges, endIndex)
        return edges
    end
    function AabbDimensions(min, max) return Vec(max[1] - min[1], max[2] - min[2], max[3] - min[3]) end
    function AabbGetShapeCenterPos(shape)
        local mi, ma = GetShapeBounds(shape)
        return VecLerp(mi,ma,0.5)
    end



--[[TABLES]]
    function tableSwapIndex(t, i1, i2)
        local temp = t[i1]
        t[i1] = t[i2]
        t[i2] = temp
        return t
    end



--[[RAYCASTING]]
---comment
---@param tr table
---@param distance number
---@param rad number
---@param rejectBodies table
---@param rejectShapes table
    function RaycastFromTransform(tr, distance, rad, rejectBodies, rejectShapes)

        if distance ~= nil then distance = -distance else distance = -300 end

        if rejectBodies ~= nil then for i = 1, #rejectBodies do QueryRejectBody(rejectBodies[i]) end end
        if rejectShapes ~= nil then for i = 1, #rejectShapes do QueryRejectShape(rejectShapes[i]) end end

        local plyTransform = tr
        local fwdPos = TransformToParentPoint(plyTransform, Vec(0, 0, distance))
        local direction = VecSub(fwdPos, plyTransform.pos)
        local dist = VecLength(direction)
        direction = VecNormalize(direction)
        QueryRejectBody(rejectBody)
        local h, d, n, s = QueryRaycast(tr.pos, direction, dist, rad)
        if h then
            local p = TransformToParentPoint(plyTransform, Vec(0, 0, d * -1))
            local b = GetShapeBody(s)
            return h, p, s, b
        else
            return nil
        end
    end



--[[PHYSICS]]
    function diminishBodyAngVel(body, rate)
        local angVel = GetBodyAngularVelocity(body)
        local dRate = rate or 0.99
        local diminishedAngVel = Vec(angVel[1]*dRate, angVel[2]*dRate, angVel[3]*dRate)
        SetBodyAngularVelocity(body, diminishedAngVel)
    end
    function IsMaterialUnbreakable(mat, shape)
        return mat == 'rock' or mat == 'heavymetal' or mat == 'unbreakable' or mat == 'hardmasonry' or
            HasTag(shape,'unbreakable') or HasTag(GetShapeBody(shape),'unbreakable')
    end



--[[VFX]]
    function getColors()
        local colors = {
            white = Vec(1,1,1),
            black = Vec(0,0,0),
            grey = Vec(0,0,0),
            red = Vec(1,0,0),
            blue = Vec(0,0,1),
            yellow = Vec(1,1,0),
            purple = Vec(1,0,1),
            green = Vec(0,1,0),
            orange = Vec(1,0.5,0),
        }
        return colors
    end
    function DrawDot(pos, l, w, r, g, b, a, dt)
        local dot = LoadSprite("ui/hud/dot-small.png")
        local spriteRot = QuatLookAt(pos, GetCameraTransform().pos)
        local spriteTr = Transform(pos, spriteRot)
        DrawSprite(dot, spriteTr, l or 0.2, w or 0.2, r or 1, g or 1, b or 1, a or 1, dt or true)
    end



--[[SOUND]]
    local debugSounds = {
        beep = LoadSound("warning-beep"),
        buzz = LoadSound("light/spark0"),
        chime = LoadSound("elevator-chime"),}
    function beep(pos, vol) PlaySound(debugSounds.beep, pos or GetPlayerPos(), vol or 0.3) end
    function buzz(pos, vol) PlaySound(debugSounds.buzz, pos or GetPlayerPos(), vol or 0.3) end
    function chime(pos, vol) PlaySound(debugSounds.chime, pos or GetPlayerPos(), vol or 0.3) end



--[[MATH]]
    function round(n, dec) local pow = 10^dec return math.floor(n * pow) / pow end
    --- return number if > 0, else return 0.00000001
    function gtZero(n) if n <= 0 then return 0.00000001 end return n end
    --- return number if not = 0, else return 0.00000001
    function nZero(n) if n == 0 then return 0.00000001 end return n end
    --- return number if not = 0, else return 0.00000001
    function rdm(min, max) return math.random(min or 0, max or 1) end



--[[FORMATTING]]
    --- string format. default 2 decimals.
    function sfn(numberToFormat, dec)
        local s = (tostring(dec or 2))
        return string.format("%."..s.."f", numberToFormat)
    end
    function sfnTime(dec) return sfn(' '..GetTime(), dec or 4) end
