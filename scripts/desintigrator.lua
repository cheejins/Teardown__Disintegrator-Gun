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

    desin.input = {
        didShoot = function() 
            return InputPressed('lmb') and desin.active()
        end,
        didReset = function() 
            return InputPressed('rmb') and desin.active()
        end
    }

    desin.initTool = function(enabled)
        RegisterTool(desin.setup.name, desin.setup.title, desin.setup.voxPath)
        SetBool('game.tool.'..desin.setup.name..'.enabled', enabled or true)
    end

    desin.timer = {
        time = 0,
        rpm = 600
    }

    -- Init
    desinObjectMetatable = buildDesinObject(nil)
    desin.initTool()

end


function runDesintigrator()
    shootDesintigrator()
    desintigrateShapes()
end


function shootDesintigrator()

    if desin.input.didShoot() then

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
                if db then DebugPrint('Shape added ' .. sfnTime()) end
            end

        end

        beep()

    elseif desin.input.didReset() then
        desin.objects = {}
        if db then DebugWatch('Desin objects reset', sfnTime()) end
    end

end


function desintigrateShapes()
    -- Desintigrate each shape in desin.objects.
    for i = 1, #desin.objects do desintigrateShape(desin.objects[i]) end

    if db then DebugWatch('Desintigrating shapes', sfnTime()) end
    if db then DebugWatch('Desin shapes count', #desin.objects) end
end


function desintigrateShape(desinObject)

    -- fine = shape
    -- general = body

    if desinObject.start.done == false then
        desinObject.start.desintigrationStep()
        desinObject.start.done = true
        if db then DebugWatch('Desintigrating start done', sfnTime()) end
    elseif
        desinObject.spread.desintigrationStep()
    end

end


function buildDesinObject(shape)

    local desinObject = {}

    desinObject.shape = shape
    desinObject.body = GetShapeBody(shape)

    desinObject.properties = {
        holeSize = 1,
    }


    -- Sets the starting positions of the desintigrations.
    desinObject.start = {
        points = 10,
        done = false,
    }

    -- Raycasting closest points after a desintigration step.
    desinObject.spread = {
        positions = {}, -- A new position is set (closest raycasted point) after the old position has been processed.
        done = false,
    }


    desinObject.spread.desintigrationStep = function()

        -- shape bounds.
        local sMin, sMax = GetShapeBounds(desinObject.shape)
        if db then AabbDraw(sMin, sMax, 0, 1, 0) end -- Draw aabb

        -- Center aabb.
        local aabbCenter = VecLerp(sMin, sMax, 0.5)

        -- Set number of desintigration points.
        local sx,sy,sz = GetShapeSize(shape)
        desinObject.spread.points = math.floor((sx+sy+sz)/10) + 1
        if db then DebugWatch('desinObject shapeSize', desinObject.spread.points) end

        for i = 1, #desinObject.spread.positions do

            local pos = desinObject.spread.positions[i]
            -- DebugLine(pos, aabbCenter)

            local hs = desinObject.properties.holeSize
            MakeHole(pos, hs, hs, hs, hs)
            PointLight(pos, 1, 0, 0, 0.25)

            -- Source positions.
            local len = 2
            local rcHit, rcHitPos, n, rcShape = QueryClosestPoint(pos, len)
            if rcHit then

                local mat = GetShapeMaterialAtPosition(rcShape, rcHitPos)
                local matIsUnbreakable = mat == 'rock' or mat == 'heavymetal' or mat == 'unbreakable' or mat == 'hardmasonry'
                -- local matIsUnbreakable = mat == 'rock'

                if matIsUnbreakable then
                    desinObject.spread.positions[i] = Vec(rdm(sMin[1], sMax[1]), rdm(sMin[2], sMax[2]), rdm(sMin[3], sMax[3])) -- Random pos inside aabb
                    beep()
                else
                    desinObject.spread.positions[i] = rcHitPos -- Set new spread position as closest point
                end

            end

        end

    end



    desinObject.start.desintigrationStep = function() -- Set the initial raycast hit positions from the perimeter of the shape aabb.

        -- shape bounds.
        local sMin, sMax = GetShapeBounds(desinObject.shape)

        if db then AabbDraw(sMin, sMax, 0, 1, 0) end -- Draw aabb

        -- Set number of desintigration points.
        local sx,sy,sz = GetShapeSize(shape)
        desinObject.start.points = math.floor((sx+sy+sz)/10) + 1

        if db then DebugWatch('desinObject shapeSize', desinObject.start.points) end

        -- Set start positions.
        for i = 1, desinObject.start.points do

            local position = Vec(
                rdm(sMin[1], sMax[1]),
                rdm(sMin[2], sMax[2]),
                rdm(sMin[3], sMax[3]))

            table.insert(desinObject.spread.positions, position)
        end

    end



    return desinObject
end
