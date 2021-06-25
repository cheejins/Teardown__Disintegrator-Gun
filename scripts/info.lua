#include "../main.lua"

local neverShow = { -- Auto show on updates.
    'savegame.mod.info.neverShow',
    'savegame.mod.info.neverShow.2021.06.24'
}

function initInfo()

    info = {
        closed = GetBool(neverShow[#neverShow]),
    }

end


function manageInfoUi()

    dbw('info.closed', info.closed)
    dbw('info.neverShow', GetBool(neverShow[#neverShow]))

    if desin.active() then

        if not info.closed then

            if InputPressed('rmb') then

                info.closed = true

                SetBool(neverShow[#neverShow], true)
                SetString('hud.notification','(Desintegrator info window will not show until the next major update)')

            elseif InputPressed('lmb') then

                info.closed = true

            end

        end


        -- Display info UI
        if not info.closed then

            UiPush()
                UiTranslate(UiCenter(), UiMiddle())
                UiAlign("center middle")
                UiImageBox('MOD/img/info.png', 940*0.8, 836*0.8, 1, 1)
            UiPop()

        end

    end

end