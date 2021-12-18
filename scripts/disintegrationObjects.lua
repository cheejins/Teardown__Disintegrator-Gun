function buildDisinObject(shape)

    local obj = {}


    obj.body = GetShapeBody(shape)
    obj.mass = GetBodyMass(obj.body)

    obj.shape = shape
    obj.shapeTr = GetShapeWorldTransform(shape) -- Real shape transform.
    obj.shapeTrOffset = GetShapeLocalTransform(shape).pos -- Compensates for the size change of the shape.

    local sx, sy, sz = GetShapeSize(shape)
    obj.size = Vec(sx, sy, sz)
    obj.shapeSize = sx + sy + sz


    obj.done = false
    obj.holeSize = 0.5
    obj.maxPoints = 30
    obj.sizeDiv = 10 -- Sets number of points (shapeSize/sizeDiv)
    obj.tooSmall = false -- Shape too small = remove shape.


    -- Query point tracking.
    obj.relPoints = {}
    obj.usedRelPoints = {}
    obj.relPointResolution = obj.holeSize/2
    for x = 0, obj.size[1]/10, obj.relPointResolution do
        for y = 0, obj.size[2]/10, obj.relPointResolution do
            for z = 0, obj.size[3]/10, obj.relPointResolution do
                table.insert(obj.relPoints, Vec(x,y,z)) -- Filled 3d grid of relative points.
            end
        end
    end

    obj.hit = {
        positions = {}, -- The current frame's hit positions.
        lastPos = {}
    }


    obj.tick = function()
        obj.updateDisinObject() -- Update for new frame
    end



    -- ! Raycasting closest points after a disintegration step.
    obj.spread = {}
    obj.spread.points = {} -- Current positions being disintegrated.
    obj.spread.done = false

    lastcall = GetTime()

    obj.spread.disintegrationStep = function()

        --[[
            -- obj.hit.positions = {} -- Reset current frame's hit positions.

            -- if GetTime() - lastcall > 0.1 then

            --     local randomRelPointsIndex = math.random(1, #obj.relPoints)
            --     local randomRelPoint = obj.relPoints[randomRelPointsIndex]
            --     local position = TransformToParentPoint(obj.shapeTr, randomRelPoint)

            --     table.insert(obj.spread.points, position) -- Use the random rel point as a spread point.
            --     table.insert(obj.usedRelPoints, randomRelPoint)

            --     table.remove(obj.relPoints, randomRelPointsIndex)

            --     lastcall = lastcall + 0.1
            -- end


            -- -- Check each disin point.
            -- for i = 1, #obj.spread.points do

            --     obj.query.rejectIrrelevantShapes()

            --     local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(obj.spread.points[i], obj.holeSize * 4)
            --     if rcHit and rcShape == obj.shape then

            --         if IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos)) then

            --             -- obj.setRandomDisintegrationPosition(obj.spread.points, i, sMin, sMax) -- Cannot break material.

            --         else

            --              -- Set new spread position at closest point.
            --             obj.spread.points[i] = VecAdd(
            --                 rcHitPos,
            --                 Vec(
            --                     math.random()-0.5,
            --                     math.random()-0.5,
            --                     math.random()-0.5)
            --             )

            --             table.insert(obj.hit.positions, rcHitPos) -- Draws dots only at hit points.

            --         end

            --     else

            --         -- table.insert(obj.usedPoints, TransformToLocalPoint(obj.shapeTr, obj.spread.points[i]))

            --         -- obj.setRandomDisintegrationPosition(obj.spread.points, i, sMin, sMax) -- no hit

            --         -- dbw('#obj.usedPoints', #obj.usedPoints)

            --     end

            --     -- local holeSizeMult = gtZero(math.random() - 0.8) + 1
            --     local holeSizeMult = 1
            --     obj.disintegratePos(obj.spread.points[i], holeSizeMult) -- Pos disintegration.

            -- end
        ]]





        if db then
            obj.drawRelPointDots()
            ObbDrawShape(obj.shape)
            dbw('obj.shapeTrOffset', obj.shapeTrOffset)
        end

    end




    -- ! Sets the starting positions of the disintegrations.
    obj.start = {}
    obj.start.numberOfPoints = 1
    obj.start.done = false
    obj.start.disintegrationStart = function() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- local sMin, sMax = GetShapeBounds(obj.shape)

        for i = 1, obj.start.numberOfPoints do -- Set starting spread positions.

            -- local position = obj.setRandomDisintegrationPosition(obj.spread.points, i, sMin, sMax)

            local randomRelPointsIndex = math.random(1, #obj.relPoints)
            local randomRelPoint = obj.relPoints[randomRelPointsIndex]
            local position = TransformToParentPoint(obj.shapeTr, randomRelPoint)

            table.insert(obj.spread.points, position) -- Use the random rel point as a spread point.
            table.insert(obj.usedRelPoints, randomRelPoint)

            table.remove(obj.relPoints, randomRelPointsIndex)

        end

    end



    -- Get a unique pos and remove it from the obj.relPoints table.
    obj.takeUniqueRelPos = function()

        -- local randomRelPointsIndex = math.random(1, #obj.relPoints)
        -- local randomRelPoint = obj.relPoints[randomRelPointsIndex]
        -- local position = TransformToParentPoint(obj.shapeTr, randomRelPoint)

        -- -- table.insert(obj.spread.points, position) -- Use the random rel point as a spread point.
        -- -- table.insert(obj.usedRelPoints, randomRelPoint)

        -- table.remove(obj.relPoints, randomRelPointsIndex)

        -- return position

    end


    obj.drawRelPointDots = function ()

        local bodyTr = GetBodyTransform(obj.body)


        local bodyTrAdjustedPos = TransformToParentPoint(bodyTr, obj.shapeTrOffset)
        local shapTrAdjusted = Transform(bodyTrAdjustedPos, obj.shapeTr.rot)


        for i = 1, #obj.relPoints do
            local pos = TransformToParentPoint(shapTrAdjusted, obj.relPoints[i])
            DebugCross(pos, 1,1,0, 1)
        end

        for i = 1, #obj.usedRelPoints do
            local pos = TransformToParentPoint(shapTrAdjusted, obj.usedRelPoints[i])
            DebugCross(pos, 1,0,0, 1)
        end


        dbl(obj.shapeTr.pos, shapTrAdjusted.pos)

        DrawDot(bodyTr.pos, 0.25,0.25, 0,1,0, 0.25, true)
        DrawDot(obj.shapeTr.pos, 0.2,0.2, 1,1,1, 0.5, true)
        DrawDot(shapTrAdjusted.pos, 0.2,0.2, 1,0,1, 0.5, true)

    end

    -- obj.drawRelPointDots = function ()

    --     -- local shapTrAdjusted = Transform(TransformToParentPoint(obj.shapeTr, obj.shapeTrOffset), obj.shapeTr.rot)
    --     -- DrawDot(obj.shapeTr.pos, 0.2,0.2, 1,1,1, 0.5, true)
    --     -- DrawDot(shapTrAdjusted.pos, 0.2,0.2, 1,0,1, 0.5, true)

    --     local bodyTr = GetBodyTransform(obj.body)
    --     DrawDot(bodyTr.pos, 0.25,0.25, 0,1,0, 0.25, true)

    --     local shapeBodyPosOffset = VecSub(bodyTr.pos, obj.shapeTr.pos)
    --     local shapTrAdjusted = Transform(shapeBodyPosOffset, obj.shapeTr.rot)

    --     dbp('')

    --     for i = 1, #obj.relPoints do
    --         local pos = TransformToParentPoint(obj.shapeTr, obj.relPoints[i])
    --         DebugCross(pos, 1,1,0, 1)
    --     end

    --     for i = 1, #obj.usedRelPoints do
    --         local pos = TransformToParentPoint(obj.shapeTr, obj.usedRelPoints[i])
    --         DebugCross(pos, 1,0,0, 1)
    --     end

    --     dbl(obj.shapeTr.pos, shapTrAdjusted.pos)

    -- end

    obj.disintegratePos = function(pos, mult)

        local hs = obj.holeSize * (mult or 1)
        local c = Tool.colors.disintegrating

        MakeHole(pos, hs, hs, hs, hs)
        PointLight(pos, c[1], c[2], c[3], 0.25)
    end

    obj.isShapeTooSmall = function()
        if obj.shapeSize < 10 then return true end
        return false
    end

    obj.updateDisinObject = function()

        obj.shapeTr = GetShapeWorldTransform(obj.shape)

        obj.mass = GetBodyMass(obj.body)

        local sx, sy, sz = GetShapeSize(shape)
        obj.shapeSize = (sx + sy + sz)
        obj.size.x = sx
        obj.size.y = sy
        obj.size.z = sz

    end

    obj.getShapeSize = function ()
        local sx, sy, sz = GetShapeSize(obj.shape)
        obj.shapeSize = (sx + sy + sz)
    end

    obj.query = {}
    obj.query.rejectIrrelevantShapes = function () -- Reject all shapes except the disin shape.

        local sMin, sMax = GetShapeBounds(obj.shape)
        local queriedShapes = QueryAabbShapes(sMin, sMax)

        for i = 1, #queriedShapes do

            local shape = queriedShapes[i]

            if shape ~= obj.shape then
                QueryRejectShape(queriedShapes[i])
            end

        end

    end


    return obj
end



--[[
        -- ! Raycasting closest points after a disintegration step.
    obj.spread = {}

    obj.spread.points = {} -- Current positions being disintegrated.
    obj.spread.done = false

    function obj.spread.disintegrationStep()

        obj.updateDisinObject()

        local sMin, sMax = GetShapeBounds(obj.shape)

        -- Set number of disintegration points.
        -- obj.spread.points = math.floor((sx + sy + sz) / obj.sizeDiv) + 3
        obj.spread.points = 2
        dbw('obj shapeSize', obj.spread.points)


        obj.hit.positions = {} -- Reset spread points each step to prevent disintegrating the same pos.

        for i = 1, #obj.spread.points do -- Each disin pos.

            -- Reject all other shapes.
            local queriedShapes = QueryAabbShapes(sMin, sMax)
            for i = 1, #queriedShapes do
                local shape = queriedShapes[i]
                if shape ~= obj.shape then
                    QueryRejectShape(queriedShapes[i])
                end
            end

            -- Set spread positions.
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(obj.spread.points[i], obj.holeSize * 4)

            if rcHit and rcShape == obj.shape then

                if IsMaterialUnbreakable(GetShapeMaterialAtPosition(rcShape, rcHitPos)) then

                    obj.setRandomDisintegrationPosition(obj.spread.points, i, sMin, sMax) -- Cannot break material.

                else

                    -- Minor direction change
                    local div = 80
                    local rdmVec = Vec(
                                    math.random() / div - math.random() / div,
                                    math.random() / div - math.random() / div,
                                    math.random() / div - math.random() / div)

                    obj.spread.points[i] = VecAdd(rcHitPos, rdmVec) -- Set new spread position at closest point.

                    table.insert(obj.hit.positions, rcHitPos) -- Draws dots only at hit points.

                end

            else

                -- table.insert(obj.usedPoints, TransformToLocalPoint(obj.shapeTr, obj.spread.points[i]))

                obj.setRandomDisintegrationPosition(obj.spread.points, i, sMin, sMax) -- no hit

                -- dbw('#obj.usedPoints', #obj.usedPoints)

            end

            -- local holeSizeMult = gtZero(math.random() - 0.8) + 1
            local holeSizeMult = 1
            obj.disintegratePos(obj.spread.points[i], holeSizeMult) -- Pos disintegration.

        end

    end
]]