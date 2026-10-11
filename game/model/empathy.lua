-- Empathy: how well the DM reads the table. Every bar on screen goes through
-- here. Low Empathy shows rough fills that update a week late; high Empathy
-- shows precise fills, trend arrows and early warnings. Suspicion is always a
-- blurred band: Empathy narrows it but never closes it. Pure Lua.
--
-- Empathy grows by use: every game night you run, and every one-on-one talk.

local util = require "game.model.util"

local M = {}

M.MAX = 5
M.XP = { 0, 4, 10, 18, 28 }        -- xp needed for levels 1..5
M.STEPS = { 4, 5, 8, 10, 20 }      -- fill steps a bar snaps to
M.BAND = { 44, 36, 28, 22, 16 }    -- width of the Suspicion band
M.GAIN = { night = 1, talk = 2, check_in = 2, session_zero = 3 }
M.NAMES = { "Clueless", "Getting a feel", "Attentive", "Perceptive", "Reads minds" }

function M.level(xp)
    local level = 1
    for l = 1, M.MAX do
        if xp >= M.XP[l] then
            level = l
        end
    end
    return level
end

-- Progress to the next level, 0..1 (1 at max).
function M.progress(xp)
    local l = M.level(xp)
    if l >= M.MAX then
        return 1
    end
    return (xp - M.XP[l]) / (M.XP[l + 1] - M.XP[l])
end

-- What each level adds, for the UI.
function M.perks(level)
    return {
        late = level <= 1,         -- long-term bars show last week's values
        live = level >= 3,         -- game night bars move every beat, not once per scene
        arrows = level >= 3,       -- trend arrows on long-term bars
        marks = level >= 2,        -- report shows which way bars moved
        sizes = level >= 4,        -- report shows by how much (++ / --)
        early = level >= 4,        -- warns before a player starts drifting away
    }
end

-- Snap a 0..100 value to the fill steps this level can see.
function M.fill(level, v)
    local steps = M.STEPS[util.clamp(level, 1, M.MAX)]
    local f = util.clamp(v, 0, 100) / 100
    -- Never show completely empty for something above zero; a sliver reads better.
    local snapped = math.floor(f * steps + 0.5) / steps
    if snapped == 0 and v > 3 then
        snapped = 0.5 / steps
    end
    return snapped * 100
end

-- A repeatable pseudo-random number in [-1, 1] for one player in one week.
local function wobble(week, idx)
    local x = (week * 7919 + idx * 104729 + 12345) % 2147483647
    for _ = 1, 3 do
        x = (x * 16807) % 2147483647
    end
    return (x / 2147483647) * 2 - 1
end

-- The Suspicion band: always contains the true value, never centred on it.
function M.band(level, v, week, idx)
    local w = M.BAND[util.clamp(level, 1, M.MAX)]
    local off = wobble(week, idx) * w * 0.35
    local lo = v - w / 2 + off
    local hi = v + w / 2 + off
    if lo < 0 then
        hi = hi - lo
        lo = 0
    elseif hi > 100 then
        lo = lo - (hi - 100)
        hi = 100
    end
    return lo, hi
end

-- How the DM sees one long-term bar of one player right now.
-- Returns { fill, lo, hi, arrow = "up" | "down" | nil }
function M.long(level, p, key, week, idx)
    local perks = M.perks(level)
    local v = perks.late and (p.lag and p.lag[key] or p[key]) or p[key]
    local out = {}
    if key == "suspicion" then
        out.lo, out.hi = M.band(level, v, week, idx)
    else
        out.fill = M.fill(level, v)
    end
    if perks.arrows and p.delta then
        local d = p.delta[key] or 0
        local need = level >= 4 and 1.5 or 3
        if d >= need then
            out.arrow = "up"
        elseif d <= -need then
            out.arrow = "down"
        end
    end
    return out
end

-- Is this player drifting away, as far as the DM can tell?
-- "break": on a break.  "wavering": they've said so in the chat (always visible).
-- "drifting": early warning, Perceptive DMs only.
function M.warning(level, p)
    if p.on_break then
        return "break"
    end
    if (p.wavering or 0) > 0 then
        return "wavering"
    end
    if M.perks(level).early and p.commitment < 38 and (p.delta and (p.delta.commitment or 0) < 0) then
        return "drifting"
    end
    return nil
end

-- Marks for a change on the report: "+", "-" or "=", doubled for big moves at high Empathy.
function M.mark(level, d)
    local perks = M.perks(level)
    if not perks.marks then
        return nil
    end
    if d >= 1.5 then
        return (perks.sizes and d >= 6) and "++" or "+"
    elseif d <= -1.5 then
        return (perks.sizes and d <= -6) and "--" or "-"
    end
    return "="
end

return M
