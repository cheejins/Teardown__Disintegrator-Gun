#include "utility.lua"

-- db = false
db = true

function initDesintigrator()

    designObjectMetatable = buildDesinObject(nil)

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

    RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
    SetBool('game.tool.'..desin.setup.name..'.enabled', true)

end


function runDesintigrator()
    shootDesintigrator()
    desintigrateShapes()
end


function shootDesintigrator()

    if InputPressed('lmb') and desin.active() then

        local camTr = GetCameraTransform()
        local hit, hitPos, hitShape = RaycastFromTransform(camTr, 100)
        if hit then

            local shapeIsValid = true

            for i = 1, #desin.objects do
                -- Check if shape is already in desin.targetShapes.
                if hitShape == desin.objects[i].shape then
                    shapeIsValid = false
                    if db then DebugPrint('Shape invalid' .. sfnTime()) end
                    break -- Reject invalid desin object.
                end
            end

            if shapeIsValid then
                local designObject = buildDesinObject(hitShape)
                table.insert(desin.objects, designObject) -- Insert valid design object.
                if db then DebugPrint('Shape added' .. sfnTime()) end
            end

        end

        beep()

    end

end


function desintigrateShapes()

    -- Desintigrate each shape in desin.targetShapes.
    for i = 1, #desin.targetShapes do
        local shape = desin.targetShapes[i]
        desintigrateShape(shape)
    end

    if db then DebugWatch('Desintigrating shapes', sfnTime()) end
    if db then DebugWatch('Desin shapes count', #desin.targetShapes) end

end


function desintigrateShape(shape)

    local sMin, sMax = GetShapeBounds(shape)
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