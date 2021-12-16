SelectedShapes = {} -- Keep track of shapes that have been added to the TOOL.objects table.


function disintegrateShapes()

    -- Disintigrate shapes.
    if TOOL.isDisintegrating then
        for i = 1, #TOOL.objects do

            disintegrateShape(TOOL.objects[i])

        end
    end

    dbw('Disintegrating shapes', sfnTime())
    dbw('Disin shapes count', #TOOL.objects)

end


function disintegrateShape(disinObject)

    if disinObject.start.done == false then

        disinObject.start.disintegrationStep()
        disinObject.start.done = true
        dbw('Disintegrating start done', sfnTime())

    else

        disinObject.spread.disintegrationStep()
        sound.disintegrate.loop(AabbGetShapeCenterPos(disinObject.shape))

    end

end



function createShape3DArray(shape)

    local x,y,z = GetShapeSize(shape)

end






-- check starting dimensions and tr

    -- create 3d array of bools, 1 for each voxel
        -- grid relative to tr

    -- transform


-- initial hit index transformed to
