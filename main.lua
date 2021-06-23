#include "scripts/desintegrator.lua"

function init()
    initDesintegrator()
end

function tick()
    shootDesintegrator()
    desintegrateShapes()
end
