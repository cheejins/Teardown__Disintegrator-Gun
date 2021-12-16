function buildDisinObject(shape)

    local disinObject = {}

    -- ! Base properties.
    disinObject.shape = shape
    disinObject.body = GetShapeBody(shape)
    disinObject.done = false

    local sx, sy, sz = GetShapeSize(shape)

    disinObject.holeSize = 0.2
    disinObject.shapeSize = (sx + sy + sz)
    disinObject.tooSmall = false -- Shape too small = remove shape.
    disinObject.maxPoints = 30
    disinObject.sizeDiv = 15 -- Sets number of points (shapeSize/sizeDiv)



    disinObject.disintegratePos = function(pos, mult)
        local hs = disinObject.holeSize * (mult or 1)
        MakeHole(pos, hs, hs, hs, hs)

        local c = TOOL.colors.disintegrating
        PointLight(pos, c[1], c[2], c[3], 0.25)
    end

    disinObject.setRandomDisintegrationPosition =
        function(table, index, bbMin, bbMax) -- Random pos inside aabb
            table[index] = Vec(
                math.random(bbMin[1], bbMax[1]) + math.random() - math.random(),
                math.random(bbMin[2], bbMax[2]) + math.random() - math.random(),
                math.random(bbMin[3], bbMax[3]) + math.random() - math.random())
        end

    disinObject.isShapeTooSmall = function()
        if disinObject.shapeSize < 10 then return true end
        return false
    end

    disinObject.updateDisinObject = function()

        local sx, sy, sz = GetShapeSize(shape)
        disinObject.shapeSize = (sx + sy + sz)

        ObbDrawShape(shape)

    end

    disinObject.hit = {
        positions = {},
        lastPos = {}
    }



    -- ! Sets the starting positions of the disintegrations.
    disinObject.start = {}

    disinObject.start.points = 10
    disinObject.start.done = false

    disinObject.start.disintegrationStep = function() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- Set number of disintegration points.
        local sMin, sMax = GetShapeBounds(disinObject.shape)
        local sx, sy, sz = GetShapeSize(shape)
        disinObject.start.points = math.floor((sx + sy + sz) /
                                                    disinObject.sizeDiv) + 3

        -- Limit number of points for performance.
        if disinObject.start.points > disinObject.maxPoints then
            disinObject.start.points = disinObject.maxPoints
        end

        -- Set starting spread positions.
        for i = 1, disinObject.start.points do
            local position = disinObject.setRandomDisintegrationPosition(
                                    disinObject.spread.positions, i, sMin, sMax)
            table.insert(disinObject.spread.positions, position)
        end
        dbw('disinObject.start.points', disinObject.start.points)

        -- Initial spread step.
        disinObject.spread.disintegrationStep()

        -- Set starting hit positions.
        for i = 1, disinObject.start.points do
            table.insert(disinObject.hit.positions,
                            disinObject.spread.positions[i])
        end

    end



    -- ! Raycasting closest points after a disintegration step.
    disinObject.spread = {}

    disinObject.spread.positions = {} -- A new position is set (closest raycasted point) after the old position has been processed.
    disinObject.spread.done = false

    disinObject.spread.disintegrationStep = function()

        disinObject.updateDisinObject()

        local sMin, sMax = GetShapeBounds(disinObject.shape)

        -- Set number of disintegration points.
        disinObject.spread.points = math.floor((sx + sy + sz) /
                                                   disinObject.sizeDiv) + 3
        dbw('disinObject shapeSize', disinObject.spread.points)

        disinObject.hit.positions = {} -- Reset each step.

        for i = 1, #disinObject.spread.positions do -- Process disintegration step.

            -- -- Reject all other shapes.
            -- local queriedShapes = QueryAabbShapes(sMin, sMax)
            -- for i = 1, #queriedShapes do
            --     local shape = queriedShapes[i]
            --     if shape ~= disinObject.shape then
            --         QueryRejectShape(queriedShapes[i])
            --     end
            -- end

            -- Set spread positions.
            local rcDist = disinObject.holeSize * 4
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(
                                                    disinObject.spread.positions[i],
                                                    rcDist)
            if rcHit and rcShape == disinObject.shape then

                local isMaterialUnbreakable =
                    IsMaterialUnbreakable(
                        GetShapeMaterialAtPosition(rcShape, rcHitPos))
                if isMaterialUnbreakable then

                    disinObject.setRandomDisintegrationPosition(
                        disinObject.spread.positions, i, sMin, sMax) -- Cannot break material.

                else

                    local div = 80
                    local rdmVec = Vec(
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div)

                    disinObject.spread.positions[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(disinObject.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else
                disinObject.setRandomDisintegrationPosition(disinObject.spread
                                                                .positions, i,
                                                            sMin, sMax) -- no hit
            end

            local holeSizeMult = gtZero(math.random() - 0.8) + 1
            disinObject.disintegratePos(disinObject.spread.positions[i],
                                        holeSizeMult) -- Pos disintegration.
        end
    end

    return disinObject
end
