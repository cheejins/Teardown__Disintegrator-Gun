function buildDisinObject(shape)

    local obj = {}


    obj.shape = shape
    obj.body = GetShapeBody(shape)

    obj.shapeTr = GetShapeWorldTransform(shape)
    obj.shapeTrActual = GetShapeWorldTransform(shape) -- Places the shape
    obj.done = false

    local sx, sy, sz = GetShapeSize(shape)

    obj.holeSize = 0.2
    obj.shapeSize = sx + sy + sz
    obj.tooSmall = false -- Shape too small = remove shape.
    obj.maxPoints = 30
    obj.sizeDiv = 10 -- Sets number of points (shapeSize/sizeDiv)

    obj.usedPositions = {}

    obj.hit = {
        positions = {},
        lastPos = {}
    }



    -- ! Sets the starting positions of the disintegrations.
    obj.start = {}

    obj.start.points = 10
    obj.start.done = false

    function obj.start.setDisinPoints() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- obj.start.points = math.floor(sx + sy + sz) / obj.sizeDiv
        obj.start.points = 1

        local sMin, sMax = GetShapeBounds(obj.shape)

        for i = 1, obj.start.points do -- Set starting spread positions.
            local position = obj.setRandomDisintegrationPosition(obj.spread.positions, i, sMin, sMax)
            table.insert(obj.spread.positions, position)
        end

        dbw('obj.start.points', obj.start.points)

    end



    -- ! Raycasting closest points after a disintegration step.
    obj.spread = {}

    obj.spread.positions = {} -- Current positions being disintegrated.
    obj.spread.done = false

    function obj.spread.disintegrationStep()

        obj.updateDisinObject()

        local sMin, sMax = GetShapeBounds(obj.shape)

        -- Set number of disintegration points.
        -- obj.spread.points = math.floor((sx + sy + sz) / obj.sizeDiv) + 3
        obj.spread.points = 2
        dbw('obj shapeSize', obj.spread.points)


        obj.hit.positions = {} -- Reset spread points each step to prevent disintegrating the same pos.

        for i = 1, #obj.spread.positions do -- Each disin pos.

            -- Reject all other shapes.
            local queriedShapes = QueryAabbShapes(sMin, sMax)
            for i = 1, #queriedShapes do
                local shape = queriedShapes[i]
                if shape ~= obj.shape then
                    QueryRejectShape(queriedShapes[i])
                end
            end

            -- Set spread positions.
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(obj.spread.positions[i], obj.holeSize * 4)

            if rcHit and rcShape == obj.shape then

                if IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos)) then

                    obj.setRandomDisintegrationPosition(obj.spread.positions, i, sMin, sMax) -- Cannot break material.

                else

                    -- Minor direction change
                    local div = 80
                    local rdmVec = Vec(
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div,
                                       math.random() / div - math.random() / div)

                    obj.spread.positions[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(obj.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else

                -- table.insert(obj.usedPositions, TransformToLocalPoint(obj.shapeTr, obj.spread.positions[i]))

                obj.setRandomDisintegrationPosition(obj.spread.positions, i, sMin, sMax) -- no hit

                -- dbw('#obj.usedPositions', #obj.usedPositions)

            end

            -- local holeSizeMult = gtZero(math.random() - 0.8) + 1
            local holeSizeMult = 1
            obj.disintegratePos(obj.spread.positions[i], holeSizeMult) -- Pos disintegration.

        end

    end


    obj.setRandomDisintegrationPosition = function(table, index, bbMin, bbMax) -- Random pos inside aabb

        local randomPos = Vec()

        for i = 1, 3 do
            randomPos[i] = math.random(
                math.floor(bbMin[i]),
                math.floor(bbMax[i]))

            -- VecPrint(randomPos)
        end

        table[index] = randomPos
    end

    obj.disintegratePos = function(pos, mult)
        local hs = obj.holeSize * (mult or 1)
        MakeHole(pos, hs, hs, hs, hs)

        local c = Tool.colors.disintegrating
        PointLight(pos, c[1], c[2], c[3], 0.25)
    end

    obj.isShapeTooSmall = function()
        if obj.shapeSize < 10 then return true end
        return false
    end

    obj.updateDisinObject = function()

        -- obj.shapeTr = GetShapeWorldTransform(obj.shape)

        local sx, sy, sz = GetShapeSize(shape)
        obj.shapeSize = (sx + sy + sz)

    end

    obj.getShapeSize = function ()
        local sx, sy, sz = GetShapeSize(obj.shape)
        obj.shapeSize = (sx + sy + sz)
    end


    return obj
end
