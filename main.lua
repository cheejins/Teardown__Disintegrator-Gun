#include "scripts/desintegrator.lua"
#include "scripts/utility.lua"
#include "scripts/info.lua"


-- (Debug mode)
-- db = false
db = true
-- dbw = function(func)  end


function init()
    initDesintegrator()
    initSounds()
    initInfo()

    updateGameTable()
    globalBody = FindBodies('', true)[1]
end


function tick()

    if GetBool('savegame.mod.info.neverShow') or info.closed then -- info.lua

        updateGameTable()

        shootDesintegrator()
        desintegrateShapes()

        desin.manageMode()
        if db then DebugWatch('Desin mode', desin.mode) end

        desin.manageIsDesintegrating()
        if db then DebugWatch('desin.isDesintegrating', desin.isDesintegrating) end

        desin.manageColor()
        desin.manageOutline()
        desin.manageToolAnimation()

        desin.manageObjectRemoval()

    end

end


function initDesintegrator()

    desin = {}

    desin.setup = {
        name = 'desintegrator',
        title = 'Desintegrator',
        voxPath = 'MOD/vox/desintegrator.vox',
    }

    desin.active = function() -- Player is wielding the desintegrator.
        return GetString('game.player.tool') == desin.setup.name and GetPlayerVehicle() == 0
    end

    desin.input = {
        didSelect = function() return InputPressed('lmb') and desin.active() end,
        didToggleDesintegrate = function() return InputPressed('rmb') and desin.active() end,
        didReset = function() return InputPressed('r') and desin.active() end,
        didChangeMode = function() return InputPressed('c') and desin.active() end,
    }

    desin.initTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end

    -- Init
    desin.initTool()



    desin.objects = {}
    desinObjectMetatable = buildDesinObject(nil)



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
            beep()
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
        if db then DebugPrint('Shape added ' .. sfnTime()) end
    end

    desin.insert.processShape = function(shape)

        local shapeIsValid = true -- Choose whether to add shape to desin.objects.

        for i = 1, #desin.objects do -- Check if shape is in desin.objects.

            if shape == desin.objects[i].shape then -- Remove shape that's already in desin.objects.

                shapeIsValid = false

                if desin.mode == desin.modes.general then -- Desin mode general. Remove all shapes in body.

                    local shapeBody = GetShapeBody(shape)
                    if shapeBody ~= globalBody then -- Not global body.

                        local bodyShapes = GetBodyShapes(shapeBody)
                        if db then DebugPrint('#bodyShapes ' .. #bodyShapes) end

                        for j = 1, #bodyShapes do -- All body shapes.
                            for k = 1, #desin.objects do -- Check all body shapes with desin.objects shapes.

                                if bodyShapes[j] == desin.objects[k].shape then -- Body shape is in desin.objects.
                                    desin.setObjectToBeRemoved(desin.objects[k]) -- Mark shape for removal
                                    if db then DebugPrint('Man removed body shape ' .. sfnTime()) end
                                end

                            end
                        end

                    end

                elseif desin.mode == desin.modes.specific then -- Desin mode specific. Remove single shape.

                    desin.setObjectToBeRemoved(desin.objects[i])
                    if db then DebugPrint('Man removed shape ' .. sfnTime()) end

                end

            end

        end

        -- Insert valid shape 
        if shapeIsValid then
            desin.insert.shape(shape)
            sound.ui.insert()
        else
            sound.ui.removeShape()
        end


    end

    desin.insert.body = function(shape, body)

        local bodyIsValid = body ~= globalBody

        if bodyIsValid then

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
        local removeSound = false

        for i = 1, #desin.objects do

            local removeShape = false

            local smallShape = desin.objects[i].functions.isShapeTooSmall()
            local desintegrating = desin.isDesintegrating

            if smallShape and desintegrating then -- Small shape to remove.

                removeShape = true
                sound.desintegrate.done(AabbGetShapeCenterPos(desin.objects[i].shape))
                desin.objects[i].done = true
                if db then DebugPrint('Small shape set for removal ' .. sfnTime()) end

            end

            if desin.objects[i].remove then -- Cancelled shape to remove.
                removeShape = true
                removeSound = true
            end

            if removeShape then
                table.insert(removeIndexes, i)
            end

        end


        -- if removeSound then
        --     sound.ui.removeShape()
        -- end


        for i = 1, #removeIndexes do

            local desinObjIndex = removeIndexes[i]
            table.remove(desin.objects, desinObjIndex)

        end

    end

    -- Mark object for removal. Removed in desin.manageObjectRemoval()
    desin.setObjectToBeRemoved = function(desinObject)
        desinObject.remove = true
    end



    desin.manageToolAnimation = function()

        if desin.active() then

            local toolShapes = GetBodyShapes(GetToolBody())
            local toolPos = Vec(0.6,-0.5,-0.4) -- Base tool pos

            if db then DebugWatch('#toolShapes', #toolShapes) end


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



end


function shootDesintegrator()

    local camTr = GetCameraTransform()
    local hit, hitPos, hitShape, hitBody = RaycastFromTransform(camTr, 150)
    if hit then

        if desin.input.didSelect() then -- desin shoot

            if desin.mode == desin.modes.specific then

                desin.insert.processShape(hitShape)

            elseif desin.mode == desin.modes.general then

                desin.insert.body(hitShape, hitBody)

            -- elseif desin.mode == desin.modes.autoSpread then
            end


        elseif desin.input.didReset() then -- desin reset

            desin.objects = {}
            desin.isDesintegrating = false

            sound.ui.reset()

            if db then DebugWatch('Desin objects reset', sfnTime()) end

        end

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
    }

    loops = {
        desinLoop = LoadLoop("snd/desinLoop.ogg"),
    }

    sound = {

        desintegrate = {

            loop = function(pos)
                PlayLoop(loops.desinLoop, pos, 0.6) -- Desintigrate sound.
                PlayLoop(loops.desinLoop, game.ppos, 0.1)
            end,

            done = function(pos)
                PlaySound(sounds.desinEnd, pos, 0.5)
            end,

        },

        ui = {

            insert = function()
                PlaySound(sounds.insertShape, game.ppos, 0.8)
            end,

            removeShape = function()
                PlaySound(sounds.removeShape, game.ppos, 0.9)
            end,

            reset = function ()
                PlaySound(sounds.reset, game.ppos, 1)
            end,

            activate = function ()
                PlaySound(sounds.cancel, game.ppos, 0.25)
            end,

            deactivate = function ()
                PlaySound(sounds.start, game.ppos, 0.2)
            end,

        }

    }

end


function draw()

    manageInfoUi()

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
                    math.random()/2 + 0.4
                )
            end
        end
    end

    -- Draw desin.mode text
    if desin.active() then
        UiPush()
            UiTranslate(UiCenter(), UiMiddle() + 470)
            UiColor(1,1,1,1)
            UiFont('bold.ttf', 32)
            UiAlign('center middle')
            -- UiText('Mode: ' .. desin.mode)
            UiTextShadow(0,0,0,0.8,2,0.2)
            UiText('mode: ' .. desin.mode .. ' (c) ')
        UiPop()
    end

end


function updateGameTable()
    game = { ppos = GetPlayerTransform().pos }
end