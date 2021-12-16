--- Draw dots at hit positions.
function drawHitPositions()
    for i = 1, #Tool.objects do
        for j = 1, #Tool.objects[i].hit.positions do
            DrawDot(
                Tool.objects[i].hit.positions[j],
                math.random()/5,
                math.random()/5,
                Tool.colors.disintegrating[1],
                Tool.colors.disintegrating[2],
                Tool.colors.disintegrating[3],
                math.random()/2 + 0.3
            )
        end
    end
end

--- Draw Tool.mode text
function drawToolText_Mode()
    do UiPush()

        local fontSize = 26
        local vMargin = fontSize * 1.2
        local a = 0.35

        UiColor(1,1,1,a)
        UiFont('bold.ttf', fontSize)
        UiAlign('center middle')
        UiTextOutline(0,0,0,a,0.3)
        UiTranslate(UiCenter(), UiMiddle() + 460)

        do UiPush()

            -- if not Tool.isDisintegrating then

                -- Selection mode.
                UiColor(1,1,1,a)
                local modeText = 'MODE: ' .. string.upper(Tool.mode) .. ' (c) '
                UiText(modeText)
                UiTranslate(0, -vMargin)

                    do UiPush()

                        -- Disintegration voxels count.
                        local voxelCount = Tool.properties.voxels.getCount()

                        local c = 1
                        if Tool.properties.voxels.getLimitReached() then
                            c = 0
                        end
                        -- local c = (1000*500 / (voxelCount + 100*100)) ^ 2

                        UiColor(1, c, c, a)
                        UiTranslate(0, -vMargin)
                        local voxText = 'VOXELS: ' .. sfnCommas(voxelCount)
                        UiText(voxText)

                        -- Disintegration objects count.
                        local obj = #Tool.objects
                        -- local c = (30 / (obj + 1)) ^ 2
                        -- UiColor(1, c, c, a)

                        local c = 1
                        if Tool.properties.objectsLimitReached() then
                            c = 0
                        end
                        UiColor(1, c, c, a)

                        UiTranslate(0, -vMargin)
                        local objText = 'OBJECTS: ' .. sfnCommas(obj)
                        UiText(objText)

                    UiPop() end

                    -- end

            UiPop() end

    UiPop() end
end

--- Crosshair Add Mode Indicator
function drawToolText_AddMode()
    do UiPush()

        UiColor(1,1,1,1)
        UiFont('bold.ttf', 12)

        UiAlign('center middle')
        UiTranslate(UiCenter(), UiMiddle() + 50)

        UiText('ADD MODE')

    UiPop() end
end


function drawToolCrosshair()
    if Tool.tool.active() and not Tool.isDisintegrating then
        do UiPush()

            UiAlign('center middle')
            UiTranslate(UiCenter(), UiMiddle())

            local crosshairImage = 'img/crosshairs/crosshair_specific.png'
            if Tool.mode == Tool.modes.general then
                crosshairImage = 'img/crosshairs/crosshair_general.png'
            end

            UiImageBox(crosshairImage, 35, 35, 1, 1)

        UiPop() end
    end
end