#include "scripts/disintegrator.lua"
#include "scripts/utility.lua"
#include "scripts/info.lua"


-- (Debug mode)
db = false
-- db = true
dbw = function(name, value) if db then DebugWatch(name, value) end end
dbp = function(str) if db then DebugPrint(str) end end


function init()
    initDesintegrator()
    initSounds()
    initInfo()

    updateGameTable()
    globalBody = FindBodies('', true)[1]
end


function tick()

    -- manageInfoUi()

    if info.checkInfoClosed() then -- info.lua

        updateGameTable()

        desin.manageMode()
        dbw('Desin mode', desin.mode)

        desin.manageIsDesintegrating()
        dbw('desin.isDesintegrating', desin.isDesintegrating)

        desin.manageObjectRemoval()

        desin.manageColor()
        desin.manageOutline()
        desin.manageToolAnimation()

        shootDesintegrator()
        desintegrateShapes()

    end

end


function initDesintegrator()

    desin = {}

    desin.setup = {
        name = 'disintegrator',
        title = 'Disintegrator',
        voxPath = 'MOD/vox/disintegrator.vox',
    }

    desin.active = function(includeVehicle) -- Player is wielding the desintegrator.
        return GetString('game.player.tool') == desin.setup.name 
            and (GetPlayerVehicle() == 0 and (includeVehicle or true))
    end

    desin.input = {
        didSelect = function() return InputPressed('lmb') and desin.active() end,
        didToggleDesintegrate = function() return InputPressed('rmb') and desin.active() end,
        didReset = function() return InputPressed('r') and desin.active() end,
        didChangeMode = function() return InputPressed('c') and desin.active() end,
        didUndo = function() return InputPressed('z') and desin.active() end,
    }

    desin.initTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end

    -- Init
    desin.initTool()



    desin.objects = {}
    desinObjectMetatable = buildDesinObject(nil)


    desin.properties = {
        shapeVoxelLimit = 1000*2000,

        voxels = {

            limit = 1000*1000*10,

            getCount = function()

                local voxelCount = 0
                for i = 1, #desin.objects do
                    voxelCount = voxelCount + GetShapeVoxelCount(desin.objects[i].shape)
                end
                return voxelCount

            end,

            getLimitReached = function()

                return desin.properties.voxels.getCount() > desin.properties.voxels.limit

            end,

        },

        getShapesTotalVolume = function()

            local v = 0
            local x,y,z = nil,nil,nil

            for i = 1, #desin.objects do
                x,y,z = GetShapeSize(desin.objects[i].shape)
                v = v + x*y*z
            end

            return v

        end,
    }


    desin.isDesintegrating = false
    desin.manageIsDesintegrating = function()
        if desin.input.didToggleDesintegrate() then
            desin.isDesintegrating = not desin.isDesintegrating

            if desin.isDesintegrating then
                sound.ui.activate()
            else
                sound.ui.deactivate()
            end

        end
    end



    desin.colors = {
        desintegrating = Vec(0,1,0.6),
        notDesintegrating = Vec(0.6,1,0)
    }
    desin.color = desin.colors.notDesintegrating
    desin.manageColor = function()
        if desin.isDesintegrating then
            desin.color = desin.colors.desintegrating
            return
        end
        desin.color = desin.colors.notDesintegrating
    end


    desin.manageOutline = function()

        local isDesin = desin.isDesintegrating

        local c = desin.color
        local a = 1
        if isDesin then a = 0.5 end

        for i = 1, #desin.objects do
            local shape = desin.objects[i].shape
            DrawShapeOutline(shape, c[1], c[2], c[3], a)
        end
    end



    desin.modes = {
        specific = 'specific', -- shapes
        general = 'general', -- bodies
        -- autoSpread = 'autoSpread', -- bodies
    }
    desin.mode = desin.modes.general
    desin.manageMode = function()
        if desin.input.didChangeMode() then
            
            sound.ui.switchMode()

            if desin.mode == desin.modes.specific then
                desin.mode = desin.modes.general
            else
                desin.mode = desin.modes.specific
            end
        end
    end



    desin.insert = {}
    desin.insert.shape = function(shape)
        local desinObject = buildDesinObject(shape) -- Insert valid desin object.
        setmetatable(desinObject, desinObjectMetatable)
        table.insert(desin.objects, desinObject)
        dbp('Shape added. Voxels: ' .. GetShapeVoxelCount(shape) .. ' ... ' .. sfnTime())
    end


    desin.insert.processShape = function(shape)

        local shapeBody = GetShapeBody(shape)

        local shapeWillInsert = true
        local isShapeOversized = GetShapeVoxelCount(shape) > desin.properties.shapeVoxelLimit
        local voxelLimitReached = desin.properties.voxels.getLimitReached()


        for i = 1, #desin.objects do

            if shape == desin.objects[i].shape then -- Check if shape is in desin.objects.

                shapeWillInsert = false -- Remove shape that's already in desin.objects.

                if desin.mode == desin.modes.general then -- Desin mode general. Remove all shapes in body.

                    if shapeBody == globalBody then -- Not global body.

                        desin.setObjectToBeRemoved(desin.objects[i])

                    else

                        local bodyShapes = GetBodyShapes(shapeBody)
                        dbp('#bodyShapes ' .. #bodyShapes)

                        for j = 1, #bodyShapes do
                            for k = 1, #desin.objects do -- Compare body shapes to desin.objects shapes.

                                if bodyShapes[j] == desin.objects[k].shape then -- Body shape is in desin.objects.
                                    desin.setObjectToBeRemoved(desin.objects[k]) -- Mark shape for removal
                                    dbp('Man removed body shape ' .. sfnTime())
                                end

                            end
                        end

                    end

                elseif desin.mode == desin.modes.specific then -- Remove single shape.

                    desin.setObjectToBeRemoved(desin.objects[i])
                    dbp('Man removed shape ' .. sfnTime())

                end

            end

        end


        if desin.properties.voxels.getLimitReached() then

            local message = "Voxel limit reached! \n > Object might be merged with the whole map. \n > Too many disintigrating voxels = game crash. \n > Try specific mode."
            desin.message.insert(message, colors.red)

            shapeWillInsert = false
            sound.ui.invalid()

            dbp("Voxel limit reached: " .. desin.properties.voxels.getCount() .. " ... " .. sfnTime())

        elseif isShapeOversized then

            -- Check shape not oversized.
            shapeWillInsert = false

            local message = "Object Too Large! \n > Object might be merged with the whole map. \n > Try specific mode."
            desin.message.insert(message, colors.red)

            sound.ui.invalid()
            dbp("Oversized shape rejected. Voxels: " .. GetShapeVoxelCount(shape) .. " ... " .. sfnTime())

        end


        -- Insert valid shape 
        if shapeWillInsert then

            desin.insert.shape(shape)
            sound.ui.insertShape()

        elseif not isShapeOversized then

            sound.ui.removeShape()
        end

    end


    desin.insert.body = function(shape)

        local body = GetShapeBody(shape)

        if body ~= globalBody then

            local bodyShapes = GetBodyShapes(body)
            for i = 1, #bodyShapes do

                desin.insert.processShape(bodyShapes[i])

            end

        else

            desin.insert.processShape(shape) -- Insert hit shape by default regardless of body shapes.

        end

    end


    desin.manageObjectRemoval = function()

        local removeIndexes = {} -- Remove specified desin objects.

        for i = 1, #desin.objects do

            local removeShape = false

            local smallShape = desin.objects[i].functions.isShapeTooSmall()
            local desintegrating = desin.isDesintegrating

            if smallShape and desintegrating then -- Small shape to remove.

                removeShape = true
                desin.objects[i].done = true
                MakeHole(AabbGetShapeCenterPos(desin.objects[i].shape), 0.2, 0.2 ,0.2 ,0.2)
                -- sound.desintegrate.done(AabbGetShapeCenterPos(desin.objects[i].shape))
                dbp('Small shape set for removal ' .. sfnTime())

            end

            if desin.objects[i].remove then -- Cancelled shape to remove.
                removeShape = true
            end

            if removeShape then
                table.insert(removeIndexes, i)
            end

        end

        for i = 1, #removeIndexes do

            local desinObjIndex = removeIndexes[i]
            table.remove(desin.objects, desinObjIndex)

        end

    end
    -- Mark object for removal. Removed in desin.manageObjectRemoval()
    desin.setObjectToBeRemoved = function(desinObject)
        desinObject.remove = true
    end



    desin.undo = function ()

        local lastIndex = #desin.objects
        -- local lastShape = desin.objects[lastIndex].shape

        -- if desin.mode == desin.modes.specific then

            desin.setObjectToBeRemoved(desin.objects[lastIndex]) -- Remove last object entry

        -- elseif desin.mode == desin.modes.general then

        --     local bodyShapes = GetBodyShapes(GetShapeBody(lastShape))

        --     for i = 1, #bodyShapes do -- All body shapes.
        --         for j = 1, #desin.objects do -- Check all body shapes with desin.objects shapes.

        --             if bodyShapes[i] == desin.objects[j].shape then -- Body shape is in desin.objects.
        --                 desin.setObjectToBeRemoved(desin.objects[j]) -- Mark shape for removal
        --             end

        --         end
        --     end

        -- end

        sound.ui.removeShape()
    end



    desin.manageToolAnimation = function()

        if desin.active() then

            local toolShapes = GetBodyShapes(GetToolBody())
            local toolPos = Vec(0.6,-0.5,-0.4) -- Base tool pos

            dbw('#toolShapes', #toolShapes)


            local toolUsing = nil
            local toolNotUsing = nil

            if desin.isDesintegrating then 
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



    desin.message = {
        message = nil,
        color = colors.white,
        cancelCount = 0,

        timer = {
            time = 0,
            timeDefault = (60 * GetTimeStep()) * 3.5, -- * seconds
        },

        insert = function(message, color)
            desin.message.timer.time = (string.len(message) * 2) * GetTimeStep() + 2 -- Message time based on message length.
            desin.message.color = color
            desin.message.message = message
            desin.message.cancelCount = 0 -- Reset cancel flag.
        end,

        drawText = function ()
            UiPush()
                local c = desin.message.color
                UiColor(c[1], c[2], c[3], 0.8)

                UiTranslate(UiCenter(), UiMiddle()+200)
                UiFont('bold.ttf', 28)
                UiAlign('center middle')
                UiTextShadow(0,0,0,0.8,2,0.2)
                UiText(desin.message.message)
            UiPop()
        end,

        draw = function()

            if desin.input.didSelect() then
                desin.message.cancelCount = desin.message.cancelCount + 1
            end

            if desin.message.timer.time >= 0 then
                desin.message.timer.time = desin.message.timer.time - GetTimeStep()

                if desin.message.cancelCount > 1 then -- Check if message has been cancelled.

                    desin.message.timer.time = 0 -- Remove message if player shoots again.

                else

                    desin.message.drawText()

                end
            end

            dbw('desin.message.timer.time', desin.message.timer.time)
        end

    }

end


function shootDesintegrator()


    -- local camTr = GetCameraTransform()
    -- local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr)

    -- Input.
    local didSelect = desin.input.didSelect()
    local didReset = desin.input.didReset()
    local didUndo = desin.input.didUndo()


    -- if hit and not didSelect and desin.active() and not desin.isDesintegrating then -- Highlight shape (addable/removable)

    --     -- Check if shape in objects table.
    --     local isShapeInDesinObjects = false
    --     for i = 1, #desin.objects do
    --         if hitShape == desin.objects[i].shape then
    --             isShapeInDesinObjects = true
    --             break
    --         end
    --     end

    --     if isShapeInDesinObjects then
    --         -- DrawShapeOutline(hitShape, 1, 0, 0, 0.5) -- Red outline (shape is removable)
    --         -- PointLight(hitPos, 1,0,0,0.5)
    --     else
    --         -- PointLight(hitPos, 1,1,1,0.5)
    --         DrawShapeOutline(hitShape, 1, 1, 1, 1) -- White outline (shape is addable)
    --     end

    -- else


    if didSelect then -- Shoot desin

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr)

        if hit and desin.mode == desin.modes.specific then

            desin.insert.processShape(hitShape)

        elseif hit and desin.mode == desin.modes.general then

            desin.insert.body(hitShape)

        end

    elseif didReset then -- Reset desin

        desin.objects = {}
        desin.isDesintegrating = false

        sound.ui.reset()

        dbw('Desin objects reset', sfnTime())

    elseif didUndo and #desin.objects >= 1 then -- Undo last object insertion (body or shapes)

        desin.undo()

    end

end


function initSounds()
    sounds = {
        insertShape = LoadSound("snd/insertShape.ogg"),
        removeShape = LoadSound("snd/removeShape.ogg"),

        start = LoadSound("snd/start.ogg"),
        cancel = LoadSound("snd/cancel.ogg"),
        reset = LoadSound("snd/reset.ogg"),

        desinEnd = LoadSound("snd/desinEnd.ogg"),

        invalid = LoadSound("snd/invalid.ogg"),
        switchMode = LoadSound("snd/switchMode.ogg"),
    }

    loops = {
        desinLoop = LoadLoop("snd/desinLoop.ogg"),
    }

    local sm = 0.9 -- Sound multiplier.

    sound = {

        desintegrate = {

            loop = function(pos)
                PlayLoop(loops.desinLoop, pos, 0.6 * sm) -- Desintigrate sound.
                PlayLoop(loops.desinLoop, game.ppos, 0.1 * sm)
            end,

            done = function(pos)
                PlaySound(sounds.desinEnd, pos, 0.5 * sm)
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

    manageInfoUi()

    desin.message.draw()

    -- Draw dots at hit positions.
    if desin.isDesintegrating then
        for i = 1, #desin.objects do
            for j = 1, #desin.objects[i].hit.positions do
                DrawDot(
                    desin.objects[i].hit.positions[j],
                    math.random()/5,
                    math.random()/5,
                    desin.colors.desintegrating[1],
                    desin.colors.desintegrating[2],
                    desin.colors.desintegrating[3],
                    math.random()/2 + 0.3
                )
            end
        end
    end

    -- Draw desin.mode text
    if desin.active() then
        UiPush()

            local fontSize = 26
            local vMargin = fontSize * 1.2

            local rectH = fontSize
            local rectW = 0

            -- local addRectH = function(h)
            --     rectH = rectH + h
            -- end

            -- local setRectW = function(str)

            --     local len = string.len(str)
            --     local w = len * fontSize

            --     if w > rectW then
            --         rectW = w
            --     end
            -- end

            local a = 0.35

            UiColor(1,1,1,1)
            UiFont('bold.ttf', fontSize)
            UiAlign('center middle')
            UiTextOutline(0,0,0,a,0.3)
            UiTranslate(UiCenter(), UiMiddle() + 460)

            UiPush()

                -- if not desin.isDesintegrating then

                    -- Selection mode.
                    UiColor(1,1,1,a)
                    local modeText = 'MODE: ' .. string.upper(desin.mode) .. ' (c) '
                    UiText(modeText)
                    UiTranslate(0, -vMargin)
                    -- addRectH(fontSize)
                    -- setRectW(modeText)


                        UiPush()

                        -- addRectH(vMargin)


                            -- -- Desintegration objects combined 3D volume.
                            -- local volume = desin.properties.getShapesTotalVolume()
                            -- local c = (1000*400 / (volume + 100)) ^ 1.5
                            -- UiColor(1, c, c, a)

                            -- UiTranslate(0, -vMargin)
                            -- local volText = 'VOLUME: ' .. sfnCommas(volume)
                            -- UiText(volText)
                            -- addRectH(vMargin)
                            -- setRectW(volText)



                            -- Desintegration voxels count.
                            local voxelCount = desin.properties.voxels.getCount()

                            -- local c = (1000*500 / (voxelCount + 100*100)) ^ 2
                            -- UiColor(1, c, c, a)
                            UiTranslate(0, -vMargin)
                            local voxText = 'VOXELS: ' .. sfnCommas(voxelCount)
                            UiText(voxText)
                            -- addRectH(vMargin)
                            -- setRectW(voxText)



                            -- -- Desintegration vol/vox ratio count.
                            -- local desinObjects = #desin.objects
                            -- local volume = desin.properties.getShapesTotalVolume()
                            -- local voxelCount = desin.properties.voxels.getCount()

                            -- local volume = (1000*100 / (volume + 1000*10)) ^ 2
                            -- local voxels = (1000*100 / (voxelCount + 1000*10)) ^ 2

                            -- local c = (volume + voxels) / 2
                            -- UiColor(1, c, c, a)

                            -- UiTranslate(0, -vMargin)
                            -- local voxText = 'VOX/VOL: ' .. sfnCommas(voxelCount)
                            -- UiText(voxText)
                            -- addRectH(vMargin)
                            -- setRectW(voxText)


                            -- Desintegration objects count.
                            local desinObjects = #desin.objects

                            local c = (50 / (desinObjects + 10)) ^ 2
                            UiColor(1, c, c, a)

                            UiTranslate(0, -vMargin)
                            local objText = 'OBJECTS: ' .. sfnCommas(desinObjects)
                            UiText(objText)
                            -- addRectH(vMargin)
                            -- setRectW(objText)



                        UiPop()

                    -- end

                    
                    -- UiPush()
                    -- UiColor(0,0,0,0.25)
                    -- UiTranslate(0, -rectH/2 + (vMargin + fontSize))
                    -- UiRect(300, rectH)
                    -- UiPop()

                UiPop()

        UiPop()
    end

end

function updateGameTable()
    game = { ppos = GetPlayerTransform().pos }
end