#include "../main.lua"

local neverShow = { -- Auto show on updates.
    'savegame.mod.info.neverShow',
    'savegame.mod.info.neverShow.2021.06.24',
    'savegame.mod.info.neverShow.2021.06.26',
    'savegame.mod.info.neverShow.2021.06.28',
}

function initInfo()

    info = {

        closed = GetBool(neverShow[#neverShow]),

        setNeverShow = function(enabled)
            SetBool(neverShow[#neverShow], enabled)
        end,

        getNeverShow = function ()
            return GetBool(neverShow[#neverShow])
        end,

        res = {
            w = 1300,
            h =  900,
            scale = 0.75,
        },

        inputsPressed = {
            count = 0,
        },

        checkInfoClosed = function ()

            if info.closed or info.getNeverShow() then
                info.inputsPressed.count = 1
            end

            if info.inputsPressed.count >= 1 then
                return true
            end
            return false

        end,

    }

end


function getInfo()
    return info
end

function getNeverShow()
    return neverShow
end


function drawInfoWindow()

    dbw('info.closed', info.closed)
    dbw('info.neverShow', info.getNeverShow())

    if TOOL.tool.active() then
        if not info.closed then


            if InputPressed('rmb') then

                info.closed = true
                info.inputsPressed.count = info.inputsPressed.count + 1

                info.setNeverShow(true)
                SetString('hud.notification','(Desintegrator info window will not show until the next major update)')

            elseif InputPressed('lmb') then

                info.closed = true
                info.inputsPressed.count = info.inputsPressed.count + 1

            end

            -- Display info UI
            UiPush()
            UiTranslate(UiCenter(), UiMiddle())
            UiAlign("center middle")
            UiImageBox('MOD/img/info.png', info.res.w * info.res.scale, info.res.h * info.res.scale, 1, 1)
            UiPop()

        end
    end

end