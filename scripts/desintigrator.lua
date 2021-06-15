#include "utility.lua"

-- db = false
db = true

function initDesintigrator()

    desin = {
        objects = {}
    }

    desin.setup = {
        name = 'desintigrator',
        title = 'Desintigrator',
        voxPath = 'MOD/vox/desintigrator.vox',
    }

    desin.active = function()
        return GetString('game.player.tool') == desin.setup.name and GetPlayerVehicle() == 0
    end
    desin.didShoot = function() 
        return InputPressed('lmb') and desin.active()
    end

    desin.setTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end

    -- Init
    desinObjectMetatable = buildDesinObject(nil) -- Desin objects metatable.
    desin.setTool()

end


function runDesintigrator()
    shootDesintigrator()
    desintigrateShapes()
end


function shootDesintigrator()

    if desin.didShoot() then

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape = RaycastFromTransform(camTr, 100)
        if hit then

            -- Choose whether to add raycasted object to desin.objects.
            local shapeIsValid = true
            for i = 1, #desin.objects do
                -- Check if shape is already in desin.objects.
                if hitShape == desin.objects[i].shape then
                    shapeIsValid = false
                    if db then DebugPrint('Shape invalid' .. sfnTime()) end
                    break -- Reject invalid desin object.
                end
            end
            if shapeIsValid then
                local desinObject = buildDesinObject(hitShape)
                setmetatable(desinObject, desinObjectMetatable)
                table.insert(desin.objects, desinObject) -- Insert valid desin object.
                if db then DebugPrint('Shape added' .. sfnTime()) end
            end

        end

        beep()

    end

end


function desintigrateShapes()

    -- Desintigrate each shape in desin.objects.
    for i = 1, #desin.objects do
        desintigrateShape(desin.objects[i])
    end

    if db then DebugWatch('Desintigrating shapes', sfnTime()) end
    if db then DebugWatch('Desin shapes count', #desin.objects) end

end


function desintigrateShape(desinObject)

    local sMin, sMax = GetShapeBounds(desinObject.shape)
    if db then AabbDraw(sMin, sMax, 0, 1, 0) end -- Draw aabb

end


function buildDesinObject(shape)
    t = {}

    t.shape = shape
    t.body = GetShapeBody(shape)
    t.points = GetShapeSize(shape)

    -- Raycasting closest points after a desintigration step.
    t.spread = {
        positions = {}, -- A new position is set (closest raycasted point) after the old position has been processed.
        done = false,
    }

    -- Sets the starting positions of the desintigrations.
    t.start = {
        positions = {},
        done = false,
    }

    return t
end