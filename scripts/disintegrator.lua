#include "utility.lua"
#include "../main.lua"


function desintegrateShapes()

    -- Desintigrate shapes.
    if desin.isDesintegrating then
        for i = 1, #desin.objects do

            desintegrateShape(desin.objects[i])

        end
    end

    dbw('Desintegrating shapes', sfnTime())
    dbw('Desin shapes count', #desin.objects)

end


function desintegrateShape(desinObject)

    if desinObject.start.done == false then

        desinObject.start.desintegrationStep()
        desinObject.start.done = true
        dbw('Desintegrating start done', sfnTime())

    else

        desinObject.spread.desintegrationStep()
        sound.desintegrate.loop(AabbGetShapeCenterPos(desinObject.shape))

    end

end


function buildDesinObject(shape)

    local desinObject = {}


    desinObject.shape = shape
    desinObject.body = GetShapeBody(shape)
    desinObject.done = false

    local sx,sy,sz = GetShapeSize(shape)

    desinObject.properties = {
        holeSize = 0.2,
        shapeSize = (sx+sy+sz),
        tooSmall = false, -- Shape too small = remove shape.
        maxPoints = 30,
        sizeDiv = 15, -- Sets number of points (shapeSize/sizeDiv)
    }

    desinObject.functions = {

        desintegratePos = function(pos, mult)
            local hs = desinObject.properties.holeSize * (mult or 1)
            MakeHole(pos, hs, hs, hs, hs)

            local c = desin.colors.desintegrating
            PointLight(pos, c[1], c[2], c[3], 0.25)
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
            desinObject.properties.shapeSize = (sx+sy+sz)
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

        -- Set number of desintegration points.
        desinObject.spread.points = math.floor((sx+sy+sz)/desinObject.properties.sizeDiv) + 3
        dbw('desinObject shapeSize', desinObject.spread.points)

        desinObject.hit.positions = {} -- Reset each step.

        for i = 1, #desinObject.spread.positions do -- Process desintegration step.

            -- -- Reject all other shapes.
            -- local queriedShapes = QueryAabbShapes(sMin, sMax)
            -- for i = 1, #queriedShapes do
            --     local shape = queriedShapes[i]
            --     if shape ~= desinObject.shape then
            --         QueryRejectShape(queriedShapes[i])
            --     end
            -- end

            -- Set spread positions.
            local rcDist = desinObject.properties.holeSize * 4
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(desinObject.spread.positions[i], rcDist)
            if rcHit and rcShape == desinObject.shape then

                local isMaterialUnbreakable = IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos))
                if isMaterialUnbreakable then

                    desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax)

                else

                    local div = 80
                    local rdmVec = Vec(
                        math.random()/div - math.random()/div,
                        math.random()/div - math.random()/div,
                        math.random()/div - math.random()/div)

                    desinObject.spread.positions[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(desinObject.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else
                desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax) -- no hit
            end

            local holeSizeMult = gtZero(math.random() - 0.8) + 1
            desinObject.functions.desintegratePos(desinObject.spread.positions[i], holeSizeMult) -- Pos desintegration.
        end
    end


    desinObject.start.desintegrationStep = function() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- Set number of desintegration points.
        local sMin, sMax = GetShapeBounds(desinObject.shape)
        local sx,sy,sz = GetShapeSize(shape)
        desinObject.start.points = math.floor((sx+sy+sz)/desinObject.properties.sizeDiv) + 3

        -- Limit number of points for performance.
        if desinObject.start.points > desinObject.properties.maxPoints then
            desinObject.start.points = desinObject.properties.maxPoints
        end

        -- Set starting spread positions.
        for i = 1, desinObject.start.points do
            local position = desinObject.functions.setRandomDesintegrationPosition(desinObject.spread.positions, i, sMin, sMax)
            table.insert(desinObject.spread.positions, position)
        end
        dbw('desinObject.start.points', desinObject.start.points)

        -- Initial spread step.
        desinObject.spread.desintegrationStep()

        -- Set starting hit positions.
        for i = 1, desinObject.start.points do 
            table.insert(desinObject.hit.positions, desinObject.spread.positions[i])
        end

    end


    return desinObject
end