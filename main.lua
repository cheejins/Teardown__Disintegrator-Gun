#include "scripts/debug.lua"
#include "scripts/draw.lua"
#include "scripts/disintegrationObjects.lua"
#include "scripts/disintegrator.lua"
#include "scripts/info.lua"
#include "scripts/sounds.lua"
#include "scripts/Tool.lua"
#include "scripts/utility.lua"
#include "umf/umf_full.lua"

--[[

    Select obj

        > create new disin obj
        , check shape's used points
        > set # of disin points
        > used positions = {}

    De-select obj

        > Save shape's used points in worldShapes table

    World shape tracking

        > Reset/removed objs
            > keep track of shapes and used points (points either disintegrated or no QCP hits).
            > check world shape for usedPos table when adding it to disin objs.

    Disintegrate

        > start

            > set random points (do not need to be valid)
            > do not disintegrate yet
            > used points = start points.
            > start points are already set but did not disitegrate yet.
                > usedPoints and hit points are still {}

        > spread

            > random rel points will round to scale
                > lwh / scale
                > random will produce points at that scale aligned with the obb

            > each spread point will check the shape's used rel points
                > while point is the same, set a new random one.
                > if point is unique, QCP and disin
                    > if hit, add the spread point to used rel points
                    > if no hit, do nothing. new point check next disin step


    RandomPos

        > resolution = 0.1
        > ttpp relativity generation
        > random hit = ttlp, save in used points.

]]

function init()

    game = {ppos = GetPlayerTransform().pos}
    globalBody = FindBodies('', true)[1]

    initInfo()
    initSounds()

    initTool()

end


function tick()

    game = {ppos = GetPlayerTransform().pos}

    for index, obj in ipairs(Tool.objects) do
        obj.tick()
    end

    if info.checkInfoClosed() then -- info.lua

        Tool.manageSelectionMode()
        Tool.manageAddModeToggle()
        Tool.manageObjectRemoval()
        Tool.manageIsDisintegrating()

        Tool.manageColor()
        Tool.manageOutline()
        Tool.manageToolAnimation()
        -- Tool.highlightUnselectedShapes() -- Laggy

        manageDisintegrator()
        disintegrateShapes()

        dbw('Disin mode', Tool.mode)
        dbw('Tool.isDisintegrating', Tool.isDisintegrating)

    end



end


function draw()

    drawInfoWindow()

    Tool.message.draw()

    -- Tool.highlightUnselectedShapes()

    if Tool.isDisintegrating then
        drawHitPositions()
    end

    if Tool.tool.active() then
        drawToolText_Mode()
    end

    if Tool.addModeEnabled then
        drawToolText_AddMode()
    end

end

UpdateQuickloadPatch()