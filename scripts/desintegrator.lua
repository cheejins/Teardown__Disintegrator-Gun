#include "utility.lua"
#include "../main.lua"


function desintegrateShapes()

    -- Remove small (finished) desin objects.
    local removeIndexes = {}
    for i = 1, #desin.objects do
        if desin.objects[i].functions.isShapeTooSmall() then
            table.insert(removeIndexes, i)
            if db then DebugPrint('desin obj removed ' .. sfnTime()) end
        end
    end
    for i = 1, #removeIndexes do
        table.remove(desin.objects, removeIndexes[i]) -- Remove objects safely.
    end


    for i = 1, #desin.objects do
        desintegrateShape(desin.objects[i])
    end

    if db then DebugWatch('Desintegrating shapes', sfnTime()) end
    if db then DebugWatch('Desin shapes count', #desin.objects) end

end


function desintegrateShape(desinObject)

    if desinObject.start.done == false then
        desinObject.start.desintegrationStep()
        desinObject.start.done = true
        if db then DebugWatch('Desintegrating start done', sfnTime()) end
    else
        desinObject.spread.desintegrationStep()
    end

end


function buildDesinObject(shape)

    local desinObject = {}


    desinObject.shape = shape
    desinObject.body = GetShapeBody(shape)

    desinObject.modes = {specific = 'specific', general = 'general'}
    desinObject.mode = desinObject.modes[1]


    local sx,sy,sz = GetShapeSize(shape)

    desinObject.properties = {
        color = Vec(0,1,0.6),
        holeSize = 0.2,
        shapeSize = sx+sy+sz,
        tooSmall = false, -- Shape too small = remove shape.
    }

    desinObject.functions = {

        desintegratePoint = function(pos)
            local hs = desinObject.properties.holeSize
            MakeHole(pos, hs, hs, hs, hs)

            local c = desinObject.properties.color
            PointLight(pos, c[1], c[2], c[3], 0.15)
        end,

        setRandomDesintegrationPosition = function(table, index, bbMin, bbMax) -- Random pos inside aabb
            table[index] = Vec(
                math.random(bbMin[1], bbMax[1]) + math.random() - math.random(),
                math.random(bbMin[2], bbMax[2]) + math.random() - math.random(),
                math.random(bbMin[3], bbMax[3]) + math.random() - math.random())
        end,

        isShapeTooSmall = function()
            if desinObject.properties.shapeSize < 10 then return true end
            return false
        end,

        updateDesinObject = function()
            local sx,sy,sz = GetShapeSize(shape)
            desinObject.properties.shapeSize = sx+sy+sz
        end,
    }


    -- Sets the starting positions of the desintegrations.
    desinObject.start = {
        points = 10,
        done = false,
    }
    desinObject.spread = { -- Raycasting closest points after a desintegration step.
        positions = {}, -- A new position is set (closest raycasted point) after the old position has been processed.
        done = false,
    }
    desinObject.hit = {
        positions = {},
    }


    desinObject.spread.desintegrationStep = function()

        desinObject.functions.updateDesinObject()

        local sMin, sMax = GetShapeBounds(desinObject.shape)
        DrawShapeOutline(desinObject.shape, 0, 1, 0.5, 0.35)

        -- Set number of desintegration points.
        desinObject.spread.points = math.floor((sx+sy+sz)/10) + 1
        if db then DebugWatch('desinObject shapeSize', desinObject.spread.points) end


        desinObject.hit.positions = {} -- Reset each step.

        for i = 1, #desinObject.spread.positions do -- Process desintegration step.

            local pos = desinObject.spread.positions[i]

            -- Set source positions.
            local rcDist = desinObject.properties.holeSize * 4
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(desinObject.spread.positions[i], rcDist)
            if rcHit and rcShape == desinObject.shape then

                local isMaterialUnbreakable = IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos))
                if isMaterialUnbreakable then

                    desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax)

                else

                    local rdmVec = Vec(
                        math.random()/90 - math.random()/90,
                        math.random()/90 - math.random()/90,
                        math.random()/90 - math.random()/90)

                    desinObject.spread.positions[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(desinObject.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else
                desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax)
            end

            desinObject.functions.desintegratePoint(pos) -- Actual desintegration.

        end

    end


    desinObject.start.desintegrationStep = function() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- Set number of desintegration points.
        local sMin, sMax = GetShapeBounds(desinObject.shape)
        local sx,sy,sz = GetShapeSize(shape)
        desinObject.start.points = math.floor((sx+sy+sz)/10) + 1

        -- Limit number of points for performance.
        if desinObject.start.points > 40 then
            desinObject.start.points = 40
        end
        if db then DebugWatch('desinObject.start.points', desinObject.start.points) end

        for i = 1, desinObject.start.points do -- Set starting spread positions.
            local position = desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax)
            table.insert(desinObject.spread.positions, position)
        end

    end


    return desinObject
end