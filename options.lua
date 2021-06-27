#include "main.lua"
#include "scripts/info.lua"


function init()
    initDesintegrator()
    initInfo()
end

local options = {

    manageRestoredInfoWindowSection = function()

        UiPush()

            UiTranslate(UiCenter(),UiMiddle())

            if info.getNeverShow() then

                -- Restore key neverShow.
                UiButtonImageBox("ui/common/box-outline-6.png", 6, 6)
                if UiTextButton("Restore Info Pup-up Window", 300, 40) then
                    info.setNeverShow(false)
                end

            else
                UiText('Info window restored...')
            end

        UiPop()

    end
}

function draw()

    UiColor(1,1,1,1)
    UiFont('regular.ttf', 24)
    UiAlign('center middle')

    UiPush()
        UiTranslate(UiCenter(), 100)
        UiText('Options coming soon.')
    UiPop()

    options.manageRestoredInfoWindowSection()

end
