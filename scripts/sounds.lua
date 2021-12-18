function initSounds()
    sounds = {
        insertShape = LoadSound("snd/insertShape.ogg"),
        removeShape = LoadSound("snd/removeShape.ogg"),

        start = LoadSound("snd/start.ogg"),
        cancel = LoadSound("snd/cancel.ogg"),
        reset = LoadSound("snd/reset.ogg"),

        disinEnd = LoadSound("snd/disinEnd.ogg"),

        invalid = LoadSound("snd/invalid.ogg"),
        switchMode = LoadSound("snd/switchMode.ogg"),
    }

    loops = {
        disinLoop = LoadLoop("snd/disinLoop.ogg"),
    }

    local sm = 0.9 -- Sound multiplier.

    sound = {

        disintegrate = {

            loop = function(pos)
                -- PlayLoop(loops.disinLoop, pos, 0.6 * sm) -- Disintigrate sound.
                -- PlayLoop(loops.disinLoop, game.ppos, 0.1 * sm)
            end,

            done = function(pos)
                PlaySound(sounds.disinEnd, pos, 0.5 * sm)
            end,

        },

        ui = {

            insertShape = function()
                PlaySound(sounds.insertShape, game.ppos, 0.5 * sm)
            end,

            removeShape = function()
                PlaySound(sounds.removeShape, game.ppos, 0.25 * sm)
            end,

            reset = function ()
                PlaySound(sounds.reset, game.ppos, 1 * sm)
            end,

            activate = function ()
                PlaySound(sounds.cancel, game.ppos, 0.5 * sm)
            end,

            deactivate = function ()
                PlaySound(sounds.start, game.ppos, 0.35 * sm)
            end,

            invalid = function ()
                PlaySound(sounds.invalid, game.ppos, 0.45 * sm)
            end,

            switchMode = function ()
                PlaySound(sounds.switchMode, game.ppos, 1 * sm)
            end,

        }

    }

end