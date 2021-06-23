#include "scripts/desintegrator.lua"

function init()
    initDesintegrator()
end

function tick()
    shootDesintegrator()
    desintegrateShapes()
end


function initDesintegrator()

    desin = {
        objects = {}
    }

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
        didReset = function() return InputPressed('rmb') and desin.active() end,
        didConfirm = function() return InputPressed('r') and desin.active() end,
    }

    desin.initTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end


    -- Init
    desinObjectMetatable = buildDesinObject(nil)
    desin.initTool()

end


function shootDesintegrator()

    if desin.input.didShoot() then

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape = RaycastFromTransform(camTr, 100)
        if hit then

            local shapeIsValid = true -- Choose whether to add raycasted object to desin.objects.

            for i = 1, #desin.objects do

                if hitShape == desin.objects[i].shape then -- Check if shape is already in desin.objects.

                    shapeIsValid = false

                    if db then DebugPrint('Shape invalid' .. sfnTime()) end
                    break -- Reject invalid desin object.
                end

            end

            if shapeIsValid then -- Insert valid desin object.
                local desinObject = buildDesinObject(hitShape)
                setmetatable(desinObject, desinObjectMetatable)
                table.insert(desin.objects, desinObject)
                if db then DebugPrint('Shape added ' .. sfnTime()) end
            end

        end

    elseif desin.input.didReset() then
        desin.objects = {}
        if db then DebugWatch('Desin objects reset', sfnTime()) end
    end

end