function buildDisinObject(shape)

    local disinObject = {}


    -- ! Base properties.
    disinObject.shape = shape
    disinObject.body = GetShapeBody(shape)

    disinObject.shapeTr = GetShapeWorldTransform(shape)
    disinObject.shapeTrActual = GetShapeWorldTransform(shape) -- Places the shape
    disinObject.done = false

    local sx, sy, sz = GetShapeSize(shape)

    disinObject.holeSize = 0.2
    disinObject.shapeSize = sx + sy + sz
    disinObject.tooSmall = false -- Shape too small = remove shape.
    disinObject.maxPoints = 30
    disinObject.sizeDiv = 10 -- Sets number of points (shapeSize/sizeDiv)

    disinObject.usedPositions = {}

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
        -- disinObject.start.points = math.floor(sx + sy + sz) / disinObject.sizeDiv
        disinObject.start.points = 1

        for i = 1, disinObject.start.points do -- Set starting spread positions.
            local position = disinObject.setRandomDisintegrationPosition(disinObject.spread.positions, i, sMin, sMax)
            table.insert(disinObject.spread.positions, position)
        end

        dbw('disinObject.start.points', disinObject.start.points)

    end



    -- ! Raycasting closest points after a disintegration step.
    disinObject.spread = {}

    disinObject.spread.positions = {} -- Current positions being disintegrated.
    disinObject.spread.done = false

    disinObject.spread.disintegrationStep = function()

        disinObject.updateDisinObject()

        local sMin, sMax = GetShapeBounds(disinObject.shape)

        -- Set number of disintegration points.
        -- disinObject.spread.points = math.floor((sx + sy + sz) / disinObject.sizeDiv) + 3
        disinObject.spread.points = 2
        dbw('disinObject shapeSize', disinObject.spread.points)



        disinObject.hit.positions = {} -- Reset spread points each step to prevent disintegrating the same pos.

        for i = 1, #disinObject.spread.positions do -- Each disin pos.

            -- Reject all other shapes.
            local queriedShapes = QueryAabbShapes(sMin, sMax)
            for i = 1, #queriedShapes do
                local shape = queriedShapes[i]
                if shape ~= disinObject.shape then
                    QueryRejectShape(queriedShapes[i])
                end
            end

            -- Set spread positions.
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(disinObject.spread.positions[i], disinObject.holeSize * 4)

            if rcHit and rcShape == disinObject.shape then

                if IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos)) then

                    disinObject.setRandomDisintegrationPosition(disinObject.spread.positions, i, sMin, sMax) -- Cannot break material.

                else

                    -- Minor direction change
                    local div = 80
                    local rdmVec = Vec(
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div)

                    disinObject.spread.positions[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(disinObject.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else

                -- table.insert(disinObject.usedPositions, TransformToLocalPoint(disinObject.shapeTr, disinObject.spread.positions[i]))

                disinObject.setRandomDisintegrationPosition(disinObject.spread.positions, i, sMin, sMax) -- no hit

                -- dbw('#disinObject.usedPositions', #disinObject.usedPositions)

            end

            -- local holeSizeMult = gtZero(math.random() - 0.8) + 1
            local holeSizeMult = 1
            disinObject.disintegratePos(disinObject.spread.positions[i], holeSizeMult) -- Pos disintegration.

        end

    end






    disinObject.setRandomDisintegrationPosition = function(table, index, bbMin, bbMax) -- Random pos inside aabb

        local randomPos = Vec()

        for i = 1, 3 do
            randomPos[i] = math.random(
                math.floor(bbMin[i]),
                math.floor(bbMax[i]))

            -- VecPrint(randomPos)
        end

        table[index] = randomPos
    end

    disinObject.disintegratePos = function(pos, mult)
        local hs = disinObject.holeSize * (mult or 1)
        MakeHole(pos, hs, hs, hs, hs)

        local c = Tool.colors.disintegrating
        PointLight(pos, c[1], c[2], c[3], 0.25)
    end

    disinObject.isShapeTooSmall = function()
        if disinObject.shapeSize < 10 then return true end
        return false
    end

    disinObject.updateDisinObject = function()

        -- disinObject.shapeTr = GetShapeWorldTransform(disinObject.shape)

        local sx, sy, sz = GetShapeSize(shape)
        disinObject.shapeSize = (sx + sy + sz)

    end


    return disinObject
end
