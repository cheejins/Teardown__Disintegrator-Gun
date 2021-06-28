#include "scripts/disintegrator.lua"
#include "scripts/utility.lua"
#include "scripts/info.lua"


-- (Debug mode)
db = false
-- db = true
dbw = function(name, value) if db then DebugWatch(name, value) end end
dbp = function(str) if db then DebugPrint(str) end end


function init()

    updateGameTable()
    globalBody = FindBodies('', true)[1]

    initDisintegrator()
    initInfo()

    initSounds()

end


function tick()

    if info.checkInfoClosed() then -- info.lua

        updateGameTable()

        disin.manageSelectionMode()
        disin.manageAddModeToggle()
        dbw('Disin mode', disin.mode)

        disin.manageIsDisintegrating()
        dbw('disin.isDisintegrating', disin.isDisintegrating)

        disin.manageObjectRemoval()

        disin.manageColor()
        disin.manageOutline()
        disin.manageToolAnimation()

        manageDisintegrator()
        disintegrateShapes()

    end

end


function initDisintegrator()

    disin = {}


    disin.objects = {}
    disinObjectMetatable = buildDisinObject(nil)


    disin.tool = {

        setup = {
            name = 'disintegrator',
            title = 'Disintegrator',
            voxPath = 'MOD/vox/disintegrator.vox',
        },

        active = function(includeVehicle) -- Player is wielding the disintegrator.
            return GetString('game.player.tool') == disin.tool.setup.name 
                and (GetPlayerVehicle() == 0 and (includeVehicle or true))
        end,

        input = {

            didSelect = function() return InputPressed('lmb') and disin.tool.active() end,
            didToggleDisintegrate = function() return InputPressed('rmb') and disin.tool.active() end,
            didReset = function() return InputPressed('r') and disin.tool.active() end,
            didChangeMode = function() return InputPressed('c') and disin.tool.active() end,
            didUndo = function() return InputPressed('z') and disin.tool.active() end,

            didToggleAddMode = function() return InputPressed('alt') and disin.tool.active() end,

        },

        init = function(enabled)
            RegisterTool(disin.tool.setup.name, disin.tool.setup.title, disin.tool.setup.voxPath)
            SetBool('game.tool.'..disin.tool.setup.name..'.enabled', enabled or true)
        end,

    }

    -- Init
    disin.tool.init()



    disin.unselectedShapes = {}
    disin.properties = {
        shapeVoxelLimit = 1000*2000,

        objectsLimit = 300,

        objectsLimitReached = function ()
            return #disin.objects >= disin.properties.objectsLimit
        end,

        voxels = {

            limit = 1000*1000*10,

            getCount = function()

                local voxelCount = 0
                for i = 1, #disin.objects do
                    voxelCount = voxelCount + GetShapeVoxelCount(disin.objects[i].shape)
                end
                return voxelCount

            end,

            getLimitReached = function()

                return disin.properties.voxels.getCount() > disin.properties.voxels.limit

            end,

        },

        getShapesTotalVolume = function()

            local v = 0
            local x,y,z = nil,nil,nil

            for i = 1, #disin.objects do
                x,y,z = GetShapeSize(disin.objects[i].shape)
                v = v + x*y*z
            end

            return v

        end,
    }

    disin.isDisintegrating = false
    disin.manageIsDisintegrating = function()
        if disin.tool.input.didToggleDisintegrate() then
            disin.isDisintegrating = not disin.isDisintegrating

            if disin.isDisintegrating then
                sound.ui.activate()
            else
                sound.ui.deactivate()
            end

        end
    end


    disin.addModeEnabled = false
    disin.manageAddModeToggle = function ()
        if disin.tool.input.didToggleAddMode() then
            disin.addModeEnabled = not disin.addModeEnabled
        end
    end


    disin.visualEffects = {
    }
    disin.colors = {
        disintegrating = Vec(0,1,0.6),
        notDisintegrating = Vec(0.6,1,0)
    }
    disin.color = disin.colors.notDisintegrating
    disin.manageColor = function()
        if disin.isDisintegrating then
            disin.color = disin.colors.disintegrating
            return
        end
        disin.color = disin.colors.notDisintegrating
    end
    disin.manageOutline = function()

        local isDisin = disin.isDisintegrating

        local c = disin.color
        local a = 1
        if isDisin then a = 0.5 end

        for i = 1, #disin.objects do
            local shape = disin.objects[i].shape
            DrawShapeOutline(shape, c[1], c[2], c[3], a)
        end
    end



    disin.modes = {
        specific = 'specific', -- shapes
        general = 'general', -- bodies
    }
    disin.mode = disin.modes.general
    disin.manageSelectionMode = function()
        if disin.tool.input.didChangeMode() then

            sound.ui.switchMode()

            if disin.mode == disin.modes.specific then
                disin.mode = disin.modes.general
            else
                disin.mode = disin.modes.specific
            end
        end
    end



    disin.insert = {}
    disin.insert.shape = function(shape)
        local disinObject = buildDisinObject(shape) -- Insert valid disin object.
        setmetatable(disinObject, disinObjectMetatable)
        table.insert(disin.objects, disinObject)
        dbp('Shape added. Voxels: ' .. GetShapeVoxelCount(shape) .. ' ... ' .. sfnTime())
    end
    disin.insert.processShape = function(shape)

        local shapeBody = GetShapeBody(shape)

        local shapeWillInsert = true
        local isShapeOversized = GetShapeVoxelCount(shape) > disin.properties.shapeVoxelLimit
        local voxelLimitReached = disin.properties.voxels.getLimitReached()


        if not disin.addModeEnabled then -- Enable selection add mode.

            for i = 1, #disin.objects do

                if shape == disin.objects[i].shape then -- Check if shape is in disin.objects.

                    shapeWillInsert = false -- Remove shape that's already in disin.objects.

                    if disin.mode == disin.modes.general then -- Disin mode general. Remove all shapes in body.

                        if shapeBody == globalBody then -- Not global body.

                            disin.setObjectToBeRemoved(disin.objects[i])

                        else

                            local bodyShapes = GetBodyShapes(shapeBody)
                            dbp('#bodyShapes ' .. #bodyShapes)

                            for j = 1, #bodyShapes do
                                for k = 1, #disin.objects do -- Compare body shapes to disin.objects shapes.

                                    if bodyShapes[j] == disin.objects[k].shape then -- Body shape is in disin.objects.
                                        disin.setObjectToBeRemoved(disin.objects[k]) -- Mark shape for removal
                                        dbp('Man removed body shape ' .. sfnTime())
                                    end

                                end
                            end

                        end

                    elseif disin.mode == disin.modes.specific then -- Remove single shape.

                        disin.setObjectToBeRemoved(disin.objects[i])
                        dbp('Man removed shape ' .. sfnTime())

                    end

                end

            end

        end



        -- Warning messages.
        if disin.properties.voxels.getLimitReached() or disin.properties.objectsLimitReached() then

            local message = "Voxel/Object limit reached! \n > Object might be merged with the whole map. \n > Too many disintigrating voxels = game crash. \n > Try specific mode."
            disin.message.insert(message, colors.red)

            shapeWillInsert = false
            sound.ui.invalid()

            dbp("Voxel limit reached: " .. disin.properties.voxels.getCount() .. " ... " .. sfnTime())

        elseif isShapeOversized then

            -- Check shape not oversized.
            shapeWillInsert = false

            local message = "Object Too Large! \n > Object might be merged with the whole map. \n > Try specific mode."
            disin.message.insert(message, colors.red)

            sound.ui.invalid()
            dbp("Oversized shape rejected. Voxels: " .. GetShapeVoxelCount(shape) .. " ... " .. sfnTime())

        end


        -- Insert valid shape 
        if shapeWillInsert then

            disin.insert.shape(shape)
            sound.ui.insertShape()

        elseif not isShapeOversized then

            sound.ui.removeShape()
        end

    end


    disin.insert.body = function(shape)

        local body = GetShapeBody(shape)

        if body ~= globalBody then

            local bodyShapes = GetBodyShapes(body)
            for i = 1, #bodyShapes do

                disin.insert.processShape(bodyShapes[i])

            end

        else

            disin.insert.processShape(shape) -- Insert hit shape by default regardless of body shapes.

        end

    end


    disin.manageObjectRemoval = function()

        local removeIndexes = {} -- Remove specified disin objects.

        for i = 1, #disin.objects do

            local removeShape = false

            local smallShape = disin.objects[i].functions.isShapeTooSmall()
            local disintegrating = disin.isDisintegrating

            if smallShape and disintegrating then -- Small shape to remove.

                removeShape = true
                disin.objects[i].done = true
                MakeHole(AabbGetShapeCenterPos(disin.objects[i].shape), 0.2, 0.2 ,0.2 ,0.2)
                -- sound.disintegrate.done(AabbGetShapeCenterPos(disin.objects[i].shape))
                dbp('Small shape set for removal ' .. sfnTime())

            end

            if disin.objects[i].remove then -- Cancelled shape to remove.
                removeShape = true
            end

            if removeShape then
                table.insert(removeIndexes, i)
            end

        end

        for i = 1, #removeIndexes do

            local disinObjIndex = removeIndexes[i]
            table.remove(disin.objects, disinObjIndex)

        end

    end
    -- Mark object for removal. Removed in disin.manageObjectRemoval()
    disin.setObjectToBeRemoved = function(disinObject)
        disinObject.remove = true
    end



    disin.undo = function ()

        local lastIndex = #disin.objects
        -- local lastShape = disin.objects[lastIndex].shape

        -- if disin.mode == disin.modes.specific then

            disin.setObjectToBeRemoved(disin.objects[lastIndex]) -- Remove last object entry

        -- elseif disin.mode == disin.modes.general then

        --     local bodyShapes = GetBodyShapes(GetShapeBody(lastShape))

        --     for i = 1, #bodyShapes do -- All body shapes.
        --         for j = 1, #disin.objects do -- Check all body shapes with disin.objects shapes.

        --             if bodyShapes[i] == disin.objects[j].shape then -- Body shape is in disin.objects.
        --                 disin.setObjectToBeRemoved(disin.objects[j]) -- Mark shape for removal
        --             end

        --         end
        --     end

        -- end

        sound.ui.removeShape()
    end



    disin.manageToolAnimation = function()

        if disin.tool.active() then

            local toolShapes = GetBodyShapes(GetToolBody())
            local toolPos = Vec(0.6,-0.5,-0.4) -- Base tool pos

            dbw('#toolShapes', #toolShapes)


            local toolUsing = nil
            local toolNotUsing = nil

            if disin.isDisintegrating then 
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


    disin.highlightUnselectedShapes = function()

        if not disin.isDisintegrating then

            for i = 1, #disin.objects do

                -- Reject shapes already in highlightedShapes table.
                for i = 1, #disin.objects do
                    QueryRejectShape(disin.objects[i].shape)
                end

                local sMin, sMax = GetShapeBounds(disin.objects[i].shape)
                sMin = VecAdd(sMin, Vec(-1, -1, -1))
                sMax = VecAdd(sMax, Vec(1, 1, 1))
                local queriedShapes = QueryAabbShapes(sMin, sMax)

                for j = 1, #queriedShapes do
                    DrawDot(AabbGetShapeCenterPos(queriedShapes[j]), 0.2, 0.2, 1, 0, 0, 1)
                end

            end

        end

    end


    disin.message = {
        message = nil,
        color = colors.white,
        cancelCount = 0,

        timer = {
            time = 0,
            timeDefault = (60 * GetTimeStep()) * 3.5, -- * seconds
        },

        insert = function(message, color)
            disin.message.timer.time = (string.len(message) * 2) * GetTimeStep() + 2 -- Message time based on message length.
            disin.message.color = color
            disin.message.message = message
            disin.message.cancelCount = 0 -- Reset cancel flag.
        end,

        drawText = function ()
            UiPush()
                local c = disin.message.color
                UiColor(c[1], c[2], c[3], 0.8)

                UiTranslate(UiCenter(), UiMiddle()+200)
                UiFont('bold.ttf', 28)
                UiAlign('center middle')
                UiTextShadow(0,0,0,0.8,2,0.2)
                UiText(disin.message.message)
            UiPop()
        end,

        draw = function()

            if disin.tool.input.didSelect() then
                disin.message.cancelCount = disin.message.cancelCount + 1
            end

            if disin.message.timer.time >= 0 then
                disin.message.timer.time = disin.message.timer.time - GetTimeStep()

                if disin.message.cancelCount > 1 then -- Check if message has been cancelled.

                    disin.message.timer.time = 0 -- Remove message if player shoots again.

                else

                    disin.message.drawText()

                end
            end

            dbw('disin.message.timer.time', disin.message.timer.time)
        end

    }

end


function manageDisintegrator()

    -- Input.
    local didSelect = disin.tool.input.didSelect()
    local didReset = disin.tool.input.didReset()
    local didUndo = disin.tool.input.didUndo()


    if didSelect then -- Shoot disin

        -- Add mode: reject shapes already in disin.objects.
        if disin.addModeEnabled then
            for i = 1, #disin.objects do
                QueryRejectShape(disin.objects[i].shape)
            end
        end

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr)
        if hit and disin.mode == disin.modes.specific then

            disin.insert.processShape(hitShape)

        elseif hit and disin.mode == disin.modes.general then

            disin.insert.body(hitShape)

        end

    elseif didReset then -- Reset disin

        disin.objects = {}
        disin.isDisintegrating = false

        sound.ui.reset()

        dbw('Disin objects reset', sfnTime())

    elseif didUndo and #disin.objects >= 1 then -- Undo last object insertion (body or shapes)

        disin.undo()

    end

end


function initSounds()
    sounds = {
        insertShape = LoadSound("snd/insertShape.ogg"),
        removeShape = LoadSound("snd/removeShape.ogg"),

        start = LoadSound("snd/start.ogg"),
        cancel = LoadSound("snd/cancel.ogg"),
        reset = LoadSound("snd/reset.ogg"),

        disinEnd = LoadSound("snd/disinEnd.ogg"),

        invalid = LoadSound("snd/invalid.ogg"),
        switchMode = LoadSound("snd/switchMode.ogg"),
    }

    loops = {
        disinLoop = LoadLoop("snd/disinLoop.ogg"),
    }

    local sm = 0.9 -- Sound multiplier.

    sound = {

        disintegrate = {

            loop = function(pos)
                PlayLoop(loops.disinLoop, pos, 0.6 * sm) -- Disintigrate sound.
                PlayLoop(loops.disinLoop, game.ppos, 0.1 * sm)
            end,

            done = function(pos)
                PlaySound(sounds.disinEnd, pos, 0.5 * sm)
            end,

        },

        ui = {

            insertShape = function()
                PlaySound(sounds.insertShape, game.ppos, 0.5 * sm)
            end,

            removeShape = function()
                PlaySound(sounds.removeShape, game.ppos, 0.25 * sm)
            end,

            reset = function ()
                PlaySound(sounds.reset, game.ppos, 1 * sm)
            end,

            activate = function ()
                PlaySound(sounds.cancel, game.ppos, 0.5 * sm)
            end,

            deactivate = function ()
                PlaySound(sounds.start, game.ppos, 0.35 * sm)
            end,

            invalid = function ()
                PlaySound(sounds.invalid, game.ppos, 0.45 * sm)
            end,

            switchMode = function ()
                PlaySound(sounds.switchMode, game.ppos, 1 * sm)
            end,

        }

    }

end


function draw()

    drawInfoWindow()

    disin.message.draw()

    disin.highlightUnselectedShapes()

    -- Draw dots at hit positions.
    if disin.isDisintegrating then
        for i = 1, #disin.objects do
            for j = 1, #disin.objects[i].hit.positions do
                DrawDot(
                    disin.objects[i].hit.positions[j],
                    math.random()/5,
                    math.random()/5,
                    disin.colors.disintegrating[1],
                    disin.colors.disintegrating[2],
                    disin.colors.disintegrating[3],
                    math.random()/2 + 0.3
                )
            end
        end
    end

    -- Draw disin.mode text
    if disin.tool.active() then
        UiPush()

            local fontSize = 26
            local vMargin = fontSize * 1.2
            local a = 0.35

            UiColor(1,1,1,a)
            UiFont('bold.ttf', fontSize)
            UiAlign('center middle')
            UiTextOutline(0,0,0,a,0.3)
            UiTranslate(UiCenter(), UiMiddle() + 460)

            UiPush()

                -- if not disin.isDisintegrating then

                    -- Selection mode.
                    UiColor(1,1,1,a)
                    local modeText = 'MODE: ' .. string.upper(disin.mode) .. ' (c) '
                    UiText(modeText)
                    UiTranslate(0, -vMargin)

                        UiPush()

                            -- Disintegration voxels count.
                            local voxelCount = disin.properties.voxels.getCount()
                            
                            local c = 1
                            if disin.properties.voxels.getLimitReached() then
                                c = 0
                            end
                            -- local c = (1000*500 / (voxelCount + 100*100)) ^ 2

                            UiColor(1, c, c, a)
                            UiTranslate(0, -vMargin)
                            local voxText = 'VOXELS: ' .. sfnCommas(voxelCount)
                            UiText(voxText)

                            -- Disintegration objects count.
                            local disinObjects = #disin.objects
                            -- local c = (30 / (disinObjects + 1)) ^ 2
                            -- UiColor(1, c, c, a)

                            local c = 1
                            if disin.properties.objectsLimitReached() then
                                c = 0
                            end
                            UiColor(1, c, c, a)

                            UiTranslate(0, -vMargin)
                            local objText = 'OBJECTS: ' .. sfnCommas(disinObjects)
                            UiText(objText)

                        UiPop()

                        -- end

                UiPop()

        UiPop()
    end


    -- Crosshair Add Mode Indicator
    if disin.addModeEnabled then
        UiPush()

            UiColor(1,1,1,1)
            UiFont('bold.ttf', 12)

            UiAlign('center middle')
            UiTranslate(UiCenter(), UiMiddle() + 50)

            UiText('ADD MODE')

        UiPop()
    end


    -- -- Draw crosshairs
    -- if disin.tool.active() and not disin.isDisintegrating then
    --     UiPush()

    --         UiAlign('center middle')
    --         UiTranslate(UiCenter(), UiMiddle())

    --         local crosshairImage = 'img/crosshairs/crosshair_specific.png'
    --         if disin.mode == disin.modes.general then
    --             crosshairImage = 'img/crosshairs/crosshair_general.png'
    --         end

    --         UiImageBox(crosshairImage, 35, 35, 1, 1)

    --     UiPop()
    -- end


end


function updateGameTable()
    game = { ppos = GetPlayerTransform().pos }
end