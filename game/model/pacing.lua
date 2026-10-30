-- How long each game night beat takes on screen at normal speed, in seconds.
-- The screen plays beats with these timings; the headless sims add them up to
-- check a night lands near 15 minutes. Pure Lua.

local M = {}

M.TARGET = 15 * 60          -- seconds of real time for a whole game night

-- Reading time for a caption or a speech bubble.
function M.read(text)
    return 1.4 + #(text or "") / 17
end

-- Animation time for each step of a combat turn.
M.STEP = {
    move = 0.0,          -- plus per square below
    attack = 1.1, damage = 0.45, down = 1.2, death = 0.8, up = 0.8, heal = 0.7,
    spell = 1.1, feature = 0.8, condition = 0.3, condition_end = 0.1, save = 0.4,
    death_save = 1.1, flee = 0.6, join = 0.9, fortitude = 0.7, stable = 0.7,
    initiative = 1.4, zone = 0.4, zone_end = 0.1,       -- everyone rolls; a spell's zone lands on the mat
}
M.PER_SQUARE = 0.16
M.BRISK = 0.5          -- step time once a fight has run a while without a call (the table speeds up)
M.BRISKER = 0.35       -- and once it has run a long while

-- How fast a turn plays: 1, or BRISK/BRISKER for a fight that has gone on without the DM.
function M.pace(ev)
    if ev.brisk == "very" then
        return M.BRISKER
    end
    return ev.brisk and M.BRISK or 1
end

function M.step(s)
    local t = M.STEP[s.kind] or 0.3
    if s.kind == "move" then
        t = 0.25 + M.PER_SQUARE * #(s.path or {})
    end
    return t
end

-- Time the DM spends on a decision: reading it, then choosing.
local function think(text, options)
    return 4 + M.read(text) * 0.8 + 1.8 * (options or 2)
end

function M.duration(ev)
    local k = ev.kind
    if k == "scene" then
        return 8
    elseif k == "stage" then
        return 4
    elseif k == "intro" then
        return 2.5
    elseif k == "dice" then
        return 2.5
    elseif k == "narrate" and (ev.style == "aside" or ev.style == "record") then
        return 0.3      -- the log's, not read out: nothing on screen to wait for
    elseif k == "narrate" or k == "npc" then
        return M.read(ev.text) + 0.4
    elseif k == "say" then
        return M.read(ev.text)
    elseif k == "thought" then
        return M.read(ev.text) + 1.2     -- a beat longer than a line said out loud: it's there to be read
    elseif k == "check" then
        return 2.0
    elseif k == "clue" then
        return 1.5
    elseif k == "turn" then
        local t = 0.7
        for _, s in ipairs(ev.steps or {}) do
            t = t + M.step(s) * M.pace(ev)
        end
        if ev.say then
            t = t + M.read(ev.say.text) * 0.6
        end
        return t
    elseif k == "battle" then
        return ev.phase == "start" and 3.5 or 2.5
    elseif k == "round" then
        return 1.0
    elseif k == "decision" then
        return think(ev.card.text, #ev.card.options)
    elseif k == "improv" then
        return 18
    elseif k == "roll_where" then
        return 3
    elseif k == "roll" then
        return 5.5
    elseif k == "cook" then
        return 4
    elseif k == "ruling" then
        return think(ev.prompt, #ev.options) - 2
    end
    return 0
end

-- Counted toward the gate's 8 to 15 decisions a night.
M.DECISION_KINDS = { decision = true, improv = true, ruling = true }

return M
