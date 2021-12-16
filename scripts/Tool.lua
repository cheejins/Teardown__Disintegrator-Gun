

function initTool()

    Tool = {}

    Tool.objects = {}
    disinObjectMetatable = buildDisinObject(nil)


    Tool.tool = {

        setup = {
            name = 'disintegrator',
            title = 'Disintegrator',
            voxPath = 'MOD/vox/disintegrator.vox',
        },

        active = function(includeVehicle) -- Player is wielding the disintegrator.
            return GetString('game.player.tool') == Tool.tool.setup.name
                and (GetPlayerVehicle() == 0 and (includeVehicle or true))
        end,

        input = {

            didSelect = function() return InputPressed('lmb') and Tool.tool.active() end,
            didToggleDisintegrate = function() return InputPressed('rmb') and Tool.tool.active() end,
            didReset = function() return InputPressed('r') and Tool.tool.active() end,
            didChangeMode = function() return InputPressed('c') and Tool.tool.active() end,
            didUndo = function() return InputPressed('z') and Tool.tool.active() end,

            didToggleAddMode = function() return InputPressed('alt') and Tool.tool.active() end,

        },

        init = function(enabled)
            RegisterTool(Tool.tool.setup.name, Tool.tool.setup.title, Tool.tool.setup.voxPath)
            SetBool('game.tool.'..Tool.tool.setup.name..'.enabled', enabled or true)
        end,

    }

    -- Init
    Tool.tool.init()



    Tool.unselectedShapes = {}
    Tool.properties = {
        shapeVoxelLimit = 1000*2000,

        objectsLimit = 300,

        objectsLimitReached = function ()
            return #Tool.objects >= Tool.properties.objectsLimit
        end,

        voxels = {

            limit = 1000*1000*10,

            getCount = function()

                local voxelCount = 0
                for i = 1, #Tool.objects do
                    voxelCount = voxelCount + GetShapeVoxelCount(Tool.objects[i].shape)
                end
                return voxelCount

            end,

            getLimitReached = function()

                return Tool.properties.voxels.getCount() > Tool.properties.voxels.limit

            end,

        },

        getShapesTotalVolume = function()

            local v = 0
            local x,y,z = nil,nil,nil

            for i = 1, #Tool.objects do
                x,y,z = GetShapeSize(Tool.objects[i].shape)
                v = v + x*y*z
            end

            return v

        end,
    }

    Tool.isDisintegrating = false
    Tool.manageIsDisintegrating = function()
        if Tool.tool.input.didToggleDisintegrate() then
            Tool.isDisintegrating = not Tool.isDisintegrating

            if Tool.isDisintegrating then
                sound.ui.activate()
            else
                sound.ui.deactivate()
            end

        end
    end


    Tool.addModeEnabled = false
    Tool.manageAddModeToggle = function ()
        if Tool.tool.input.didToggleAddMode() then
            Tool.addModeEnabled = not Tool.addModeEnabled
        end
    end


    Tool.visualEffects = {
    }
    Tool.colors = {
        disintegrating = Vec(0,1,0.6),
        notDisintegrating = Vec(0.6,1,0)
    }
    Tool.color = Tool.colors.notDisintegrating
    Tool.manageColor = function()
        if Tool.isDisintegrating then
            Tool.color = Tool.colors.disintegrating
            return
        end
        Tool.color = Tool.colors.notDisintegrating
    end
    Tool.manageOutline = function()

        local c = Tool.color
        local a = 1

        if Tool.isDisintegrating then a = 0.5 end

        for i = 1, #Tool.objects do
            DrawShapeOutline(Tool.objects[i].shape, c[1], c[2], c[3], a)
        end

    end



    Tool.modes = {
        specific = 'specific', -- shapes
        general = 'general', -- bodies
    }
    Tool.mode = Tool.modes.general
    Tool.manageSelectionMode = function()
        if Tool.tool.input.didChangeMode() then

            sound.ui.switchMode()

            if Tool.mode == Tool.modes.specific then
                Tool.mode = Tool.modes.general
            else
                Tool.mode = Tool.modes.specific
            end
        end
    end



    Tool.insert = {}
    Tool.insert.shape = function(shape)
        local disinObject = buildDisinObject(shape) -- Insert valid disin object.
        setmetatable(disinObject, disinObjectMetatable)
        table.insert(Tool.objects, disinObject)
        dbp('Shape added. Voxels: ' .. GetShapeVoxelCount(shape) .. ' ... ' .. sfnTime())
    end
    Tool.insert.processShape = function(shape)

        local shapeBody = GetShapeBody(shape)

        local shapeWillInsert = true
        local isShapeOversized = GetShapeVoxelCount(shape) > Tool.properties.shapeVoxelLimit
        local voxelLimitReached = Tool.properties.voxels.getLimitReached()


        if not Tool.addModeEnabled then -- Enable selection add mode.

            for i = 1, #Tool.objects do

                if shape == Tool.objects[i].shape then -- Check if shape is in Tool.objects.

                    shapeWillInsert = false -- Remove shape that's already in Tool.objects.

                    if Tool.mode == Tool.modes.general then -- Disin mode general. Remove all shapes in body.

                        if shapeBody == globalBody then -- Not global body.

                            Tool.setObjectToBeRemoved(Tool.objects[i])

                        else

                            local bodyShapes = GetBodyShapes(shapeBody)
                            dbp('#bodyShapes ' .. #bodyShapes)

                            for j = 1, #bodyShapes do
                                for k = 1, #Tool.objects do -- Compare body shapes to Tool.objects shapes.

                                    if bodyShapes[j] == Tool.objects[k].shape then -- Body shape is in Tool.objects.
                                        Tool.setObjectToBeRemoved(Tool.objects[k]) -- Mark shape for removal
                                        dbp('Man removed body shape ' .. sfnTime())
                                    end

                                end
                            end

                        end

                    elseif Tool.mode == Tool.modes.specific then -- Remove single shape.

                        Tool.setObjectToBeRemoved(Tool.objects[i])
                        dbp('Man removed shape ' .. sfnTime())

                    end

                end

            end

        end



        -- Warning messages.
        if Tool.properties.voxels.getLimitReached() or Tool.properties.objectsLimitReached() then

            local message = "Voxel/Object limit reached! \n > Object might be merged with the whole map. \n > Too many disintigrating voxels = game crash. \n > Try specific mode."
            Tool.message.insert(message, colors.red)

            shapeWillInsert = false
            sound.ui.invalid()

            dbp("Voxel limit reached: " .. Tool.properties.voxels.getCount() .. " ... " .. sfnTime())

        elseif isShapeOversized then

            -- Check shape not oversized.
            shapeWillInsert = false

            local message = "Object Too Large! \n > Object might be merged with the whole map. \n > Try specific mode."
            Tool.message.insert(message, colors.red)

            sound.ui.invalid()
            dbp("Oversized shape rejected. Voxels: " .. GetShapeVoxelCount(shape) .. " ... " .. sfnTime())

        end


        -- Insert valid shape
        if shapeWillInsert then

            Tool.insert.shape(shape)
            sound.ui.insertShape()

        elseif not isShapeOversized then

            sound.ui.removeShape()
        end

    end


    Tool.insert.body = function(shape)

        local body = GetShapeBody(shape)

        if body ~= globalBody then

            local bodyShapes = GetBodyShapes(body)
            for i = 1, #bodyShapes do

                Tool.insert.processShape(bodyShapes[i])

            end

        else

            Tool.insert.processShape(shape) -- Insert hit shape by default regardless of body shapes.

        end

    end


    Tool.manageObjectRemoval = function()

        local removeIndexes = {} -- Remove specified disin objects.

        for i = 1, #Tool.objects do

            local removeShape = false

            local smallShape = Tool.objects[i].isShapeTooSmall()
            local disintegrating = Tool.isDisintegrating

            if smallShape and disintegrating then -- Small shape to remove.

                removeShape = true
                Tool.objects[i].done = true
                MakeHole(AabbGetShapeCenterPos(Tool.objects[i].shape), 0.2, 0.2 ,0.2 ,0.2)
                -- sound.disintegrate.done(AabbGetShapeCenterPos(Tool.objects[i].shape))
                dbp('Small shape set for removal ' .. sfnTime())

            end

            if Tool.objects[i].remove then -- Cancelled shape to remove.
                removeShape = true
            end

            if removeShape then
                table.insert(removeIndexes, i)
            end

        end

        for i = 1, #removeIndexes do

            local disinObjIndex = removeIndexes[i]
            table.remove(Tool.objects, disinObjIndex)

        end

    end
    -- Mark object for removal. Removed in Tool.manageObjectRemoval()
    Tool.setObjectToBeRemoved = function(disinObject)
        disinObject.remove = true
    end



    Tool.undo = function ()

        local lastIndex = #Tool.objects
        -- local lastShape = Tool.objects[lastIndex].shape

        -- if Tool.mode == Tool.modes.specific then

            Tool.setObjectToBeRemoved(Tool.objects[lastIndex]) -- Remove last object entry

        -- elseif Tool.mode == Tool.modes.general then

        --     local bodyShapes = GetBodyShapes(GetShapeBody(lastShape))

        --     for i = 1, #bodyShapes do -- All body shapes.
        --         for j = 1, #Tool.objects do -- Check all body shapes with Tool.objects shapes.

        --             if bodyShapes[i] == Tool.objects[j].shape then -- Body shape is in Tool.objects.
        --                 Tool.setObjectToBeRemoved(Tool.objects[j]) -- Mark shape for removal
        --             end

        --         end
        --     end

        -- end

        sound.ui.removeShape()
    end



    Tool.manageToolAnimation = function()

        if Tool.tool.active() then

            local toolShapes = GetBodyShapes(GetToolBody())
            local toolPos = Vec(0.6,-0.5,-0.4) -- Base tool pos

            dbw('#toolShapes', #toolShapes)


            local toolUsing = nil
            local toolNotUsing = nil

            if Tool.isDisintegrating then 
                toolUsing = toolShapes[1]
                toolNotUsing = toolShapes[2]
            else
                toolUsing = toolShapes[2]
                toolNotUsing = toolShapes[1]
            end

            -- Set tool transforms
            local toolRot = GetShapeLocalTransform(toolShapes[1]).rot

            local toolTr = Transform(toolPos, toolRot)
            SetShapeLocalTransform(toolUsing, toolTr)

            local toolTr = Transform(Vec(0,1000,0), toolRot)
            SetShapeLocalTransform(toolNotUsing, toolTr)

        end

    end


    -- Tool.highlightUnselectedShapes = function()

        -- Tool.unselectedShapes = {}

        -- if not Tool.isDisintegrating then

        --     for i = 1, #Tool.objects do

        --         for j = 1, #Tool.objects do
        --             QueryRejectShape(Tool.objects[j].shape)
        --         end

        --         local sMin, sMax = GetShapeBounds(Tool.objects[i].shape)
        --         sMin = VecAdd(sMin, Vec(-1, -1, -1))
        --         sMax = VecAdd(sMax, Vec(1, 1, 1))
        --         local queriedShapes = QueryAabbShapes(sMin, sMax)

        --         for j = 1, #queriedShapes do
        --             table.insert(Tool.unselectedShapes, queriedShapes[j])
        --         end

        --     end


        --     -- Draw Tool.unselectedShapes indicators.
        --     for i = 1, #Tool.unselectedShapes do
        --         DrawDot(AabbGetShapeCenterPos(Tool.unselectedShapes[i]), 0.2, 0.2, 1, 0, 0, 1)
        --     end

        -- end

    -- end


    Tool.highlightUnselectedShapes = function()

        Tool.unselectedShapes = {}

        if not Tool.isDisintegrating then

            local sMin, sMax
            if #Tool.objects >= 1 then
                sMin, sMax = GetShapeBounds(Tool.objects[1].shape)
            end

            -- Choose min and max points.
            for i = 1, #Tool.objects do

                local obj = Tool.objects[i]
                local mi, ma = GetShapeBounds(obj.shape)

                -- Min point
                for i = 1, 3 do
                    if mi[i] < sMin[i] then
                        sMin[i] = mi[i]
                    end
                end

                -- Max point
                for i = 1, 3 do
                    if ma[i] > sMax[i] then
                        sMax[i] = ma[i]
                    end
                end

            end

            -- Reject selected shapes.
            for i = 1, #Tool.objects do
                QueryRejectShape(Tool.objects[i].shape)
            end

            local b = 1 -- Buffer.
            sMin = VecAdd(sMin, Vec(-b, -b, -b))
            sMax = VecAdd(sMax, Vec(b, b, b))
            local queriedShapes = QueryAabbShapes(sMin, sMax)

            -- Number of dots based on number of queried shapes.
            local spriteMinSize = #queriedShapes/100

            for i = 1, #queriedShapes do
                if GetShapeVoxelCount(queriedShapes[i]) > spriteMinSize then
                    DrawDot(AabbGetShapeCenterPos(queriedShapes[i]), 0.2, 0.2, 1, 0, 0)
                end
            end

            dbw('#queriedShapes', #queriedShapes)
            dbw('spriteMinSize', spriteMinSize)

        end

    end


    Tool.message = {
        message = nil,
        color = colors.white,
        cancelCount = 0,

        timer = {
            time = 0,
            timeDefault = (60 * GetTimeStep()) * 3.5, -- * seconds
        },

        insert = function(message, color)
            Tool.message.timer.time = (string.len(message) * 2) * GetTimeStep() + 2 -- Message time based on message length.
            Tool.message.color = color
            Tool.message.message = message
            Tool.message.cancelCount = 0 -- Reset cancel flag.
        end,

        drawText = function ()
            UiPush()
                local c = Tool.message.color
                UiColor(c[1], c[2], c[3], 0.8)

                UiTranslate(UiCenter(), UiMiddle()+200)
                UiFont('bold.ttf', 28)
                UiAlign('center middle')
                UiTextShadow(0,0,0,0.8,2,0.2)
                UiText(Tool.message.message)
            UiPop()
        end,

        draw = function()

            if Tool.tool.input.didSelect() then
                Tool.message.cancelCount = Tool.message.cancelCount + 1
            end

            if Tool.message.timer.time >= 0 then
                Tool.message.timer.time = Tool.message.timer.time - GetTimeStep()

                if Tool.message.cancelCount > 1 then -- Check if message has been cancelled.

                    Tool.message.timer.time = 0 -- Remove message if player shoots again.

                else

                    Tool.message.drawText()

                end
            end

            dbw('Tool.message.timer.time', Tool.message.timer.time)
        end

    }

end


function manageDisintegrator()

    -- Input.
    local didSelect = Tool.tool.input.didSelect()
    local didReset = Tool.tool.input.didReset()
    local didUndo = Tool.tool.input.didUndo()

    if didSelect then -- Shoot disin

        -- Add mode: reject shapes already in Tool.objects.
        if Tool.addModeEnabled then
            for i = 1, #Tool.objects do
                QueryRejectShape(Tool.objects[i].shape)
            end
        end

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr)
        if hit and Tool.mode == Tool.modes.specific then

            Tool.insert.processShape(hitShape)

        elseif hit and Tool.mode == Tool.modes.general then

            Tool.insert.body(hitShape)

        end

    elseif didReset then -- Reset disin

        Tool.objects = {}
        Tool.isDisintegrating = false

        sound.ui.reset()

        dbw('Disin objects reset', sfnTime())

    elseif didUndo and #Tool.objects >= 1 then -- Undo last object insertion (body or shapes)

        Tool.undo()

    end

end
