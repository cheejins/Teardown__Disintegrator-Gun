#include "scripts/disintegrator.lua"
#include "scripts/disintegrationObjects.lua"
#include "scripts/utility.lua"
#include "scripts/info.lua"
#include "umf/umf_full.lua"


-- (Debug mode)
db = false
-- db = true
function dbw(str, value) if db then DebugWatch(str, value) end end
function dbp(str) if db then DebugPrint(str) end end


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

        TOOL.manageSelectionMode()
        TOOL.manageAddModeToggle()
        TOOL.manageObjectRemoval()
        TOOL.manageIsDisintegrating()

        TOOL.manageColor()
        TOOL.manageOutline()
        TOOL.manageToolAnimation()
        -- TOOL.highlightUnselectedShapes() -- Laggy

        manageDisintegrator()
        disintegrateShapes()


        dbw('Disin mode', TOOL.mode)
        dbw('TOOL.isDisintegrating', TOOL.isDisintegrating)

    end

end


function initDisintegrator()

    disin = {}


    TOOL.objects = {}
    disinObjectMetatable = buildDisinObject(nil)


    TOOL.tool = {

        setup = {
            name = 'disintegrator',
            title = 'Disintegrator',
            voxPath = 'MOD/vox/disintegrator.vox',
        },

        active = function(includeVehicle) -- Player is wielding the disintegrator.
            return GetString('game.player.tool') == TOOL.tool.setup.name
                and (GetPlayerVehicle() == 0 and (includeVehicle or true))
        end,

        input = {

            didSelect = function() return InputPressed('lmb') and TOOL.tool.active() end,
            didToggleDisintegrate = function() return InputPressed('rmb') and TOOL.tool.active() end,
            didReset = function() return InputPressed('r') and TOOL.tool.active() end,
            didChangeMode = function() return InputPressed('c') and TOOL.tool.active() end,
            didUndo = function() return InputPressed('z') and TOOL.tool.active() end,

            didToggleAddMode = function() return InputPressed('alt') and TOOL.tool.active() end,

        },

        init = function(enabled)
            RegisterTool(TOOL.tool.setup.name, TOOL.tool.setup.title, TOOL.tool.setup.voxPath)
            SetBool('game.tool.'..TOOL.tool.setup.name..'.enabled', enabled or true)
        end,

    }

    -- Init
    TOOL.tool.init()



    TOOL.unselectedShapes = {}
    TOOL.properties = {
        shapeVoxelLimit = 1000*2000,

        objectsLimit = 300,

        objectsLimitReached = function ()
            return #TOOL.objects >= TOOL.properties.objectsLimit
        end,

        voxels = {

            limit = 1000*1000*10,

            getCount = function()

                local voxelCount = 0
                for i = 1, #TOOL.objects do
                    voxelCount = voxelCount + GetShapeVoxelCount(TOOL.objects[i].shape)
                end
                return voxelCount

            end,

            getLimitReached = function()

                return TOOL.properties.voxels.getCount() > TOOL.properties.voxels.limit

            end,

        },

        getShapesTotalVolume = function()

            local v = 0
            local x,y,z = nil,nil,nil

            for i = 1, #TOOL.objects do
                x,y,z = GetShapeSize(TOOL.objects[i].shape)
                v = v + x*y*z
            end

            return v

        end,
    }

    TOOL.isDisintegrating = false
    TOOL.manageIsDisintegrating = function()
        if TOOL.tool.input.didToggleDisintegrate() then
            TOOL.isDisintegrating = not TOOL.isDisintegrating

            if TOOL.isDisintegrating then
                sound.ui.activate()
            else
                sound.ui.deactivate()
            end

        end
    end


    TOOL.addModeEnabled = false
    TOOL.manageAddModeToggle = function ()
        if TOOL.tool.input.didToggleAddMode() then
            TOOL.addModeEnabled = not TOOL.addModeEnabled
        end
    end


    TOOL.visualEffects = {
    }
    TOOL.colors = {
        disintegrating = Vec(0,1,0.6),
        notDisintegrating = Vec(0.6,1,0)
    }
    TOOL.color = TOOL.colors.notDisintegrating
    TOOL.manageColor = function()
        if TOOL.isDisintegrating then
            TOOL.color = TOOL.colors.disintegrating
            return
        end
        TOOL.color = TOOL.colors.notDisintegrating
    end
    TOOL.manageOutline = function()

        local isDisin = TOOL.isDisintegrating

        local c = TOOL.color
        local a = 1
        if isDisin then a = 0.5 end

        for i = 1, #TOOL.objects do
            local shape = TOOL.objects[i].shape
            DrawShapeOutline(shape, c[1], c[2], c[3], a)
        end
    end



    TOOL.modes = {
        specific = 'specific', -- shapes
        general = 'general', -- bodies
    }
    TOOL.mode = TOOL.modes.general
    TOOL.manageSelectionMode = function()
        if TOOL.tool.input.didChangeMode() then

            sound.ui.switchMode()

            if TOOL.mode == TOOL.modes.specific then
                TOOL.mode = TOOL.modes.general
            else
                TOOL.mode = TOOL.modes.specific
            end
        end
    end



    TOOL.insert = {}
    TOOL.insert.shape = function(shape)
        local disinObject = buildDisinObject(shape) -- Insert valid disin object.
        setmetatable(disinObject, disinObjectMetatable)
        table.insert(TOOL.objects, disinObject)
        dbp('Shape added. Voxels: ' .. GetShapeVoxelCount(shape) .. ' ... ' .. sfnTime())
    end
    TOOL.insert.processShape = function(shape)

        local shapeBody = GetShapeBody(shape)

        local shapeWillInsert = true
        local isShapeOversized = GetShapeVoxelCount(shape) > TOOL.properties.shapeVoxelLimit
        local voxelLimitReached = TOOL.properties.voxels.getLimitReached()


        if not TOOL.addModeEnabled then -- Enable selection add mode.

            for i = 1, #TOOL.objects do

                if shape == TOOL.objects[i].shape then -- Check if shape is in TOOL.objects.

                    shapeWillInsert = false -- Remove shape that's already in TOOL.objects.

                    if TOOL.mode == TOOL.modes.general then -- Disin mode general. Remove all shapes in body.

                        if shapeBody == globalBody then -- Not global body.

                            TOOL.setObjectToBeRemoved(TOOL.objects[i])

                        else

                            local bodyShapes = GetBodyShapes(shapeBody)
                            dbp('#bodyShapes ' .. #bodyShapes)

                            for j = 1, #bodyShapes do
                                for k = 1, #TOOL.objects do -- Compare body shapes to TOOL.objects shapes.

                                    if bodyShapes[j] == TOOL.objects[k].shape then -- Body shape is in TOOL.objects.
                                        TOOL.setObjectToBeRemoved(TOOL.objects[k]) -- Mark shape for removal
                                        dbp('Man removed body shape ' .. sfnTime())
                                    end

                                end
                            end

                        end

                    elseif TOOL.mode == TOOL.modes.specific then -- Remove single shape.

                        TOOL.setObjectToBeRemoved(TOOL.objects[i])
                        dbp('Man removed shape ' .. sfnTime())

                    end

                end

            end

        end



        -- Warning messages.
        if TOOL.properties.voxels.getLimitReached() or TOOL.properties.objectsLimitReached() then

            local message = "Voxel/Object limit reached! \n > Object might be merged with the whole map. \n > Too many disintigrating voxels = game crash. \n > Try specific mode."
            TOOL.message.insert(message, colors.red)

            shapeWillInsert = false
            sound.ui.invalid()

            dbp("Voxel limit reached: " .. TOOL.properties.voxels.getCount() .. " ... " .. sfnTime())

        elseif isShapeOversized then

            -- Check shape not oversized.
            shapeWillInsert = false

            local message = "Object Too Large! \n > Object might be merged with the whole map. \n > Try specific mode."
            TOOL.message.insert(message, colors.red)

            sound.ui.invalid()
            dbp("Oversized shape rejected. Voxels: " .. GetShapeVoxelCount(shape) .. " ... " .. sfnTime())

        end


        -- Insert valid shape 
        if shapeWillInsert then

            TOOL.insert.shape(shape)
            sound.ui.insertShape()

        elseif not isShapeOversized then

            sound.ui.removeShape()
        end

    end


    TOOL.insert.body = function(shape)

        local body = GetShapeBody(shape)

        if body ~= globalBody then

            local bodyShapes = GetBodyShapes(body)
            for i = 1, #bodyShapes do

                TOOL.insert.processShape(bodyShapes[i])

            end

        else

            TOOL.insert.processShape(shape) -- Insert hit shape by default regardless of body shapes.

        end

    end


    TOOL.manageObjectRemoval = function()

        local removeIndexes = {} -- Remove specified disin objects.

        for i = 1, #TOOL.objects do

            local removeShape = false

            local smallShape = TOOL.objects[i].functions.isShapeTooSmall()
            local disintegrating = TOOL.isDisintegrating

            if smallShape and disintegrating then -- Small shape to remove.

                removeShape = true
                TOOL.objects[i].done = true
                MakeHole(AabbGetShapeCenterPos(TOOL.objects[i].shape), 0.2, 0.2 ,0.2 ,0.2)
                -- sound.disintegrate.done(AabbGetShapeCenterPos(TOOL.objects[i].shape))
                dbp('Small shape set for removal ' .. sfnTime())

            end

            if TOOL.objects[i].remove then -- Cancelled shape to remove.
                removeShape = true
            end

            if removeShape then
                table.insert(removeIndexes, i)
            end

        end

        for i = 1, #removeIndexes do

            local disinObjIndex = removeIndexes[i]
            table.remove(TOOL.objects, disinObjIndex)

        end

    end
    -- Mark object for removal. Removed in TOOL.manageObjectRemoval()
    TOOL.setObjectToBeRemoved = function(disinObject)
        disinObject.remove = true
    end



    TOOL.undo = function ()

        local lastIndex = #TOOL.objects
        -- local lastShape = TOOL.objects[lastIndex].shape

        -- if TOOL.mode == TOOL.modes.specific then

            TOOL.setObjectToBeRemoved(TOOL.objects[lastIndex]) -- Remove last object entry

        -- elseif TOOL.mode == TOOL.modes.general then

        --     local bodyShapes = GetBodyShapes(GetShapeBody(lastShape))

        --     for i = 1, #bodyShapes do -- All body shapes.
        --         for j = 1, #TOOL.objects do -- Check all body shapes with TOOL.objects shapes.

        --             if bodyShapes[i] == TOOL.objects[j].shape then -- Body shape is in TOOL.objects.
        --                 TOOL.setObjectToBeRemoved(TOOL.objects[j]) -- Mark shape for removal
        --             end

        --         end
        --     end

        -- end

        sound.ui.removeShape()
    end



    TOOL.manageToolAnimation = function()

        if TOOL.tool.active() then

            local toolShapes = GetBodyShapes(GetToolBody())
            local toolPos = Vec(0.6,-0.5,-0.4) -- Base tool pos

            dbw('#toolShapes', #toolShapes)


            local toolUsing = nil
            local toolNotUsing = nil

            if TOOL.isDisintegrating then 
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


    -- TOOL.highlightUnselectedShapes = function()

        -- TOOL.unselectedShapes = {}

        -- if not TOOL.isDisintegrating then

        --     for i = 1, #TOOL.objects do

        --         for j = 1, #TOOL.objects do
        --             QueryRejectShape(TOOL.objects[j].shape)
        --         end

        --         local sMin, sMax = GetShapeBounds(TOOL.objects[i].shape)
        --         sMin = VecAdd(sMin, Vec(-1, -1, -1))
        --         sMax = VecAdd(sMax, Vec(1, 1, 1))
        --         local queriedShapes = QueryAabbShapes(sMin, sMax)

        --         for j = 1, #queriedShapes do
        --             table.insert(TOOL.unselectedShapes, queriedShapes[j])
        --         end

        --     end


        --     -- Draw TOOL.unselectedShapes indicators.
        --     for i = 1, #TOOL.unselectedShapes do
        --         DrawDot(AabbGetShapeCenterPos(TOOL.unselectedShapes[i]), 0.2, 0.2, 1, 0, 0, 1)
        --     end

        -- end

    -- end


    TOOL.highlightUnselectedShapes = function()

        TOOL.unselectedShapes = {}

        if not TOOL.isDisintegrating then

            local sMin, sMax
            if #TOOL.objects >= 1 then
                sMin, sMax = GetShapeBounds(TOOL.objects[1].shape)
            end

            -- Choose min and max points.
            for i = 1, #TOOL.objects do

                local obj = TOOL.objects[i]
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
            for i = 1, #TOOL.objects do
                QueryRejectShape(TOOL.objects[i].shape)
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


    TOOL.message = {
        message = nil,
        color = colors.white,
        cancelCount = 0,

        timer = {
            time = 0,
            timeDefault = (60 * GetTimeStep()) * 3.5, -- * seconds
        },

        insert = function(message, color)
            TOOL.message.timer.time = (string.len(message) * 2) * GetTimeStep() + 2 -- Message time based on message length.
            TOOL.message.color = color
            TOOL.message.message = message
            TOOL.message.cancelCount = 0 -- Reset cancel flag.
        end,

        drawText = function ()
            UiPush()
                local c = TOOL.message.color
                UiColor(c[1], c[2], c[3], 0.8)

                UiTranslate(UiCenter(), UiMiddle()+200)
                UiFont('bold.ttf', 28)
                UiAlign('center middle')
                UiTextShadow(0,0,0,0.8,2,0.2)
                UiText(TOOL.message.message)
            UiPop()
        end,

        draw = function()

            if TOOL.tool.input.didSelect() then
                TOOL.message.cancelCount = TOOL.message.cancelCount + 1
            end

            if TOOL.message.timer.time >= 0 then
                TOOL.message.timer.time = TOOL.message.timer.time - GetTimeStep()

                if TOOL.message.cancelCount > 1 then -- Check if message has been cancelled.

                    TOOL.message.timer.time = 0 -- Remove message if player shoots again.

                else

                    TOOL.message.drawText()

                end
            end

            dbw('TOOL.message.timer.time', TOOL.message.timer.time)
        end

    }

end


function manageDisintegrator()

    -- Input.
    local didSelect = TOOL.tool.input.didSelect()
    local didReset = TOOL.tool.input.didReset()
    local didUndo = TOOL.tool.input.didUndo()


    if didSelect then -- Shoot disin

        -- Add mode: reject shapes already in TOOL.objects.
        if TOOL.addModeEnabled then
            for i = 1, #TOOL.objects do
                QueryRejectShape(TOOL.objects[i].shape)
            end
        end

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr)
        if hit and TOOL.mode == TOOL.modes.specific then

            TOOL.insert.processShape(hitShape)

        elseif hit and TOOL.mode == TOOL.modes.general then

            TOOL.insert.body(hitShape)

        end

    elseif didReset then -- Reset disin

        TOOL.objects = {}
        TOOL.isDisintegrating = false

        sound.ui.reset()

        dbw('Disin objects reset', sfnTime())

    elseif didUndo and #TOOL.objects >= 1 then -- Undo last object insertion (body or shapes)

        TOOL.undo()

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

    TOOL.message.draw()

    -- TOOL.highlightUnselectedShapes()

    -- Draw dots at hit positions.
    if TOOL.isDisintegrating then
        for i = 1, #TOOL.objects do
            for j = 1, #TOOL.objects[i].hit.positions do
                DrawDot(
                    TOOL.objects[i].hit.positions[j],
                    math.random()/5,
                    math.random()/5,
                    TOOL.colors.disintegrating[1],
                    TOOL.colors.disintegrating[2],
                    TOOL.colors.disintegrating[3],
                    math.random()/2 + 0.3
                )
            end
        end
    end

    -- Draw TOOL.mode text
    if TOOL.tool.active() then
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

                -- if not TOOL.isDisintegrating then

                    -- Selection mode.
                    UiColor(1,1,1,a)
                    local modeText = 'MODE: ' .. string.upper(TOOL.mode) .. ' (c) '
                    UiText(modeText)
                    UiTranslate(0, -vMargin)

                        UiPush()

                            -- Disintegration voxels count.
                            local voxelCount = TOOL.properties.voxels.getCount()
                            
                            local c = 1
                            if TOOL.properties.voxels.getLimitReached() then
                                c = 0
                            end
                            -- local c = (1000*500 / (voxelCount + 100*100)) ^ 2

                            UiColor(1, c, c, a)
                            UiTranslate(0, -vMargin)
                            local voxText = 'VOXELS: ' .. sfnCommas(voxelCount)
                            UiText(voxText)

                            -- Disintegration objects count.
                            local disinObjects = #TOOL.objects
                            -- local c = (30 / (disinObjects + 1)) ^ 2
                            -- UiColor(1, c, c, a)

                            local c = 1
                            if TOOL.properties.objectsLimitReached() then
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
    if TOOL.addModeEnabled then
        UiPush()

            UiColor(1,1,1,1)
            UiFont('bold.ttf', 12)

            UiAlign('center middle')
            UiTranslate(UiCenter(), UiMiddle() + 50)

            UiText('ADD MODE')

        UiPop()
    end


    -- -- Draw crosshairs
    -- if TOOL.tool.active() and not TOOL.isDisintegrating then
    --     UiPush()

    --         UiAlign('center middle')
    --         UiTranslate(UiCenter(), UiMiddle())

    --         local crosshairImage = 'img/crosshairs/crosshair_specific.png'
    --         if TOOL.mode == TOOL.modes.general then
    --             crosshairImage = 'img/crosshairs/crosshair_general.png'
    --         end

    --         UiImageBox(crosshairImage, 35, 35, 1, 1)

    --     UiPop()
    -- end


end


function updateGameTable()
    game = { ppos = GetPlayerTransform().pos }
end


UpdateQuickloadPatch()