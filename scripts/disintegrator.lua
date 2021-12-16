SelectedShapes = {} -- Keep track of shapes that have been added to the Tool.objects table.


function disintegrateShapes()

    -- Disintigrate shapes.
    if Tool.isDisintegrating then
        for i = 1, #Tool.objects do
            disintegrateShape(Tool.objects[i])
        end
    end

    dbw('Disintegrating shapes', sfnTime())
    dbw('Disin shapes count', #Tool.objects)

end


function disintegrateShape(disinObject)

    if not disinObject.start.done then

        disinObject.start.disintegrationStep()
        disinObject.start.done = true
        dbw('Disintegrating start done', sfnTime())

    else

        disinObject.spread.disintegrationStep()
        sound.disintegrate.loop(AabbGetShapeCenterPos(disinObject.shape))

    end

end
