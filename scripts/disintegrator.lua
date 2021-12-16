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


function disintegrateShape(obj)

    if not obj.start.done then

        obj.start.disintegrationStart()
        obj.start.done = true

    else

        obj.spread.disintegrationStep()
        sound.disintegrate.loop(AabbGetShapeCenterPos(obj.shape))

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
