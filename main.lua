#include "scripts/desintegrator.lua"
#include "scripts/utility.lua"


-- db = false
db = true


function init()
    initDesintegrator()
    initSounds()

    updateGameTable()
    globalBody = FindBodies('', true)[1]
end




function tick()

    updateGameTable()

    shootDesintegrator()
    desintegrateShapes()

    desin.manageMode()
    if db then DebugWatch('Desin mode', desin.mode) end

    desin.manageIsDesintegrating()
    if db then DebugWatch('desin.isDesintegrating', desin.isDesintegrating) end

    desin.manageColor()
    desin.manageOutline()

end


function initDesintegrator()

    desin = {}

    desin.setup = {
        name = 'desintegrator',
        title = 'Desintegrator',
        voxPath = 'MOD/vox/desintegrator.vox',
    }

    desin.active = function()
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
                PlaySound(sounds.cancel, game.ppos, 0.4)
            else
                PlaySound(sounds.start, game.ppos, 0.2)
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

            -- if not isDesin then
            --     local mi, ma = GetShapeBounds(shape)
            --     local qShapes = QueryAabbShapes(mi, ma)
            --     AabbDraw(mi, ma, c[1], c[2], c[3], a)
            -- end

        end
    end



    desin.modes = {
        specific = 'specific', -- shapes
        general = 'general', -- bodies
        -- autoSpread = 'autoSpread', -- bodies
    }

    desin.mode = desin.modes.specific

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

        local shapeIsValid = true -- Choose whether to add raycasted object to desin.objects.

        for i = 1, #desin.objects do -- Check if shape is already in desin.objects.

            if shape == desin.objects[i].shape then

                shapeIsValid = false
                desin.remove.shape(desin.objects[i].shape) -- Remove shape.

                PlaySound(sounds.removeShape, game.ppos)

                if db then DebugPrint('Shape invalid' .. sfnTime()) end
                break -- Reject invalid desin object.
            end

        end

        if shapeIsValid then
            desin.insert.shape(shape)
            PlaySound(sounds.insertShape, game.ppos)
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


    desin.remove = {}
    desin.remove.shape = function(shape)
        local indexesToRemove = {}
        for i = 1, #desin.objects do
            if desin.objects[i].shape == shape then
                table.insert(indexesToRemove, i)
            end
        end

        for i = 1, #indexesToRemove do
            table.remove(desin.objects, indexesToRemove[i])
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
            PlaySound(sounds.reset, game.ppos, 1)
            if db then DebugWatch('Desin objects reset', sfnTime()) end

        end

    end


end


function initSounds()
    sounds = {

        insertShape = LoadSound("snd/insertShape.ogg"),
        reset = LoadSound("snd/reset.ogg"),
        removeShape = LoadSound("snd/removeShape.ogg"),

        start = LoadSound("snd/start.ogg"),
        cancel = LoadSound("snd/cancel.ogg"),

        desinEnd = LoadSound("snd/desinEnd.ogg"),
    }

    loops = {
        desinLoop = LoadLoop("snd/desinLoop.ogg"),
    }
end


function draw()

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
            UiText('mode: ' .. desin.mode)
        UiPop()
    end

end


function updateGameTable()
    game = { ppos = GetPlayerTransform().pos }
end