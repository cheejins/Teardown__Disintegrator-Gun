#include "../main.lua"


function initInfo()
    info = {
        closed = GetBool('savegame.mod.info.neverShow'),
    }
end


function manageInfoUi()

    dbw('info.closed', info.closed)
    dbw('info.neverShow', GetBool('savegame.mod.info.neverShow'))


    if desin.active() then

        if not info.closed then

            if InputPressed('rmb') then

                info.closed = true

                SetBool('savegame.mod.info.neverShow', true)
                SetString('hud.notification','(Desintegrator info window will not show again)')

            elseif InputPressed('lmb') then

                info.closed = true

            end

        end


        -- Display info UI
        if not info.closed then

            UiPush()
                UiTranslate(UiCenter(), UiMiddle())
                UiAlign("center middle")
                UiImageBox('MOD/img/info.png', 500, 500, 1, 1)
            UiPop()

        end

    end

end