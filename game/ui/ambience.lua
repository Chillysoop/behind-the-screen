-- The cozy feel (M7 polish): sound, the evening light and the snack table, following what
-- the game is doing. Everything here is a message to a game object in main.collection
-- (main/audio, render/cozy.render_script, main/props, main/lamp, main/snacks), so the
-- model and the views never reach into them directly. Safe to call from anywhere.

local M = {}

M.AUDIO = "/audio#audio"
M.RENDER = "@render:"
M.PROPS = "/props#props"
M.LAMP = "/lamp#lamp"
M.SNACKS = "/pizza#snacks"

-- The light through an evening: ambient, the lamp's colour, the window (the sky outside)
-- and the fairy lights. Prep happens at dusk; game night slides into late evening.
M.MOODS = {
    dusk = { ambient = { 0.125, 0.095, 0.1 }, lamp = { 1.0, 0.75, 0.5 }, window = 0.8, fairy = 1.05 },
    late = { ambient = { 0.08, 0.062, 0.075 }, lamp = { 1.0, 0.65, 0.37 }, window = 0.18, fairy = 1.6 },
}
M.NIGHT_SECONDS = 15 * 60     -- how long the light takes to go from dusk to late on game night

local function post(url, id, data)
    msg.post(url, id, data or {})
end

function M.sfx(id, gain, speed)
    post(M.AUDIO, "sfx", { id = id, gain = gain, speed = speed })
end

function M.music(track)
    post(M.AUDIO, "music", { track = track or false })
end

function M.toggle_music()
    post(M.AUDIO, "toggle_music")
end

function M.mood(name, seconds)
    local m = M.MOODS[name]
    if not m then
        return
    end
    local a, l = m.ambient, m.lamp
    post(M.RENDER, "mood", { ambient = vmath.vector4(a[1], a[2], a[3], 1), lamp_color = vmath.vector4(l[1], l[2], l[3], 0),
                             seconds = seconds })
    post(M.PROPS, "mood", { window = m.window, fairy = m.fairy, seconds = seconds })
end

-- A big moment: the lamp and the campfire swell for a beat.
function M.pulse(amount, seconds)
    post(M.LAMP, "pulse", { amount = amount or 0.3, seconds = seconds or 0.45 })
end

function M.snacks_eaten(amount)
    post(M.SNACKS, "eaten", { amount = amount })
end

function M.snacks_refill()
    post(M.SNACKS, "refill")
end

-- Called whenever the screen changes (game.gui_script, app.go).
function M.screen(app, screen)
    if screen == "intro" then
        M.mood("dusk", 0.1)
        M.music("prep")
    elseif screen == "session_zero" then
        M.mood("dusk", 2)
        M.music("prep")
        M.sfx("page")
    elseif screen == "prep" then
        M.mood("dusk", 3)
        M.music("prep")
        M.snacks_refill()
        M.sfx("page")
        local c = app.campaign
        if c and c.chat and #c.chat > 0 then
            M.sfx("ping", 0.9)
        end
    elseif screen == "lore" then
        -- (The table's still setting up: prep's dusk and music carry on.)
        M.sfx("page")
    elseif screen == "night" then
        M.mood("late", M.NIGHT_SECONDS)
        M.music("night")
        M.snacks_eaten(0)
    elseif screen == "report" then
        M.mood("late", 4)
        M.music("prep")
        M.snacks_eaten(0.95)  -- one slice always lingers
        M.sfx("page")
    elseif screen == "slice_end" then
        M.mood("late", 3)
        M.music("prep")
        M.sfx("chime", 0.8)
    end
end

-- Game night events (night_view.handle).
function M.night_event(app, ev)
    local k = ev.kind
    if k == "scene" then
        local total = math.max(ev.total or 3, 1)
        M.snacks_eaten(((ev.index or 1) - 1) / total)
    elseif k == "roll" then
        M.sfx("dice")
    elseif k == "check" then
        if ev.crit then
            M.sfx("chime", 0.8)
            M.pulse(0.45)
        elseif ev.fumble then
            M.sfx("tap", 0.8, 0.8)
        end
    elseif k == "narrate" then
        if ev.style == "seed" then
            M.sfx("chime")
            M.pulse(0.4, 0.6)
        elseif ev.style == "thread" then
            M.sfx("chime", 0.7)
            M.pulse(0.25)
        end
    elseif k == "decision" or k == "improv" or k == "ruling" or k == "roll_where" or k == "cook" then
        M.sfx("card")
    elseif k == "done" then
        M.snacks_eaten(0.9)
        M.sfx("chime", 0.7)
    end
end

-- The level-up moment (levelup_view).
function M.level_up()
    M.sfx("sparkle")
    M.pulse(0.6, 0.8)
end

return M
