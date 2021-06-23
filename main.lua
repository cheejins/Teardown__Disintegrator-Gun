#include "scripts/desintegrator.lua"
#include "scripts/utility.lua"


-- db = false
db = true


function init()
    initDesintegrator()
    initSounds()

    globalBody = FindBodies('', true)[1]
end


function tick()
    shootDesintegrator()
    desintegrateShapes()
end


function initDesintegrator()

    desin = {}

    desin.objects = {}
    desinObjectMetatable = buildDesinObject(nil)

    desin.setup = {
        name = 'desintegrator',
        title = 'Desintegrator',
        voxPath = 'MOD/vox/desintegrator.vox',
    }

    desin.active = function()
        return GetString('game.player.tool') == desin.setup.name and GetPlayerVehicle() == 0
    end

    desin.input = {
        didShoot = function() return InputPressed('lmb') and desin.active() end,
        didReset = function() return InputPressed('r') and desin.active() end,
        didRemove = function() return InputPressed('rmb') and desin.active() end,
    }

    desin.initTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end

    -- Init
    desin.initTool()


    desin.insert = {}
    desin.insert.shape = function(shape)
        local desinObject = buildDesinObject(shape) -- Insert valid desin object.
        setmetatable(desinObject, desinObjectMetatable)
        table.insert(desin.objects, desinObject)
        if db then DebugPrint('Shape added ' .. sfnTime()) end
    end


end


function shootDesintegrator()

    if desin.input.didShoot() then



        -- fine = shape
        -- general = body




        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape = RaycastFromTransform(camTr, 200)
        if hit then



            local shapeIsValid = true -- Choose whether to add raycasted object to desin.objects.


            -- Check if shape is already in desin.objects.
            for i = 1, #desin.objects do
                if hitShape == desin.objects[i].shape then
                    shapeIsValid = false
                    if db then DebugPrint('Shape invalid' .. sfnTime()) end
                    break -- Reject invalid desin object.
                end
            end

            if shapeIsValid then
                desin.insert.shape(hitShape)
            end

        end





    elseif desin.input.didReset() then

        desin.objects = {}
        if db then DebugWatch('Desin objects reset', sfnTime()) end

    end

end


function initSounds()
    sounds = {
        zaps = {
            LoadSound("snd/zap1.ogg"),
            LoadSound("snd/zap2.ogg"),
            LoadSound("snd/zap3.ogg"),
            LoadSound("snd/zap4.ogg"),
            LoadSound("snd/zap5.ogg"),
            LoadSound("snd/zap6.ogg"),
            LoadSound("snd/zap7.ogg"),
        },
    }

    sounds.play = {
        zap = function (pos, vol)
            sounds.playRandom(sounds.zaps, pos, vol or 1)
        end,
    }

    sounds.playRandom = function(soundsTable, pos, vol)
        local sound = math.floor(soundsTable[rdm(1, #soundsTable)])
        PlaySound(sound, pos, vol or 1)
    end
end


function draw()
    -- Draw dots at hit positions.
    for i = 1, #desin.objects do
        for j = 1, #desin.objects[i].hit.positions do
            DrawDot(
                desin.objects[i].hit.positions[j],
                math.random()/7.5,
                math.random()/7.5,
                desin.objects[i].properties.color[1],
                desin.objects[i].properties.color[2],
                desin.objects[i].properties.color[3],
                math.random()/2 + 0.25
            )
        end
    end
end