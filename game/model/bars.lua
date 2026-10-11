-- Long-term bars: how a game night settles into Investment, Trust, Suspicion
-- and Commitment, and how Commitment decides who keeps coming. Pure Lua.
--
-- Nobody leaves without warning. When Commitment drops below WAVER_AT the
-- player says so in the group chat. Only after WAVER_WEEKS weeks of that, and
-- still below LEAVE_AT, do they take a break. A break lasts a few weeks; then
-- they come back with a fresh start, because there's no hard fail.

local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

M.WAVER_AT = 25
M.LEAVE_AT = 20
M.WAVER_WEEKS = 2
M.RETURN_COMMITMENT = 40
M.BREAK_WEEKS = { 3, 5 }
M.SIDELINED_AT = 32 -- Spotlight below this for a night counts as sidelined
M.FUN_PAR = 52      -- a night at this Fun neither builds nor drains Commitment

-- Fields every player carries for the long-term model.
function M.init(p)
    p.recent_fun = nil   -- running average of their Fun over the last few nights
    p.sidelined = 0      -- nights in a row with almost no spotlight
    p.wavering = 0       -- weeks in a row with Commitment below WAVER_AT
    p.on_break = false
    p.break_left = 0
    p.breaks = 0
    p.just_left = false
    p.back = false
    p.lag = {}           -- each bar as it was a week ago
    p.delta = {}         -- this week's change
    p.delta_prev = {}    -- last week's change
    for _, k in ipairs(score.LONG) do
        p.lag[k] = p[k]
        p.delta[k] = 0
        p.delta_prev[k] = 0
    end
end

-- A night they played. info = { hype }
function M.settle_played(p, fun, info)
    p.recent_fun = p.recent_fun and (0.6 * p.recent_fun + 0.4 * fun) or fun
    -- Investment: their backstory on the table, spotlight and story; it fades slowly without
    -- them, faster on the sidelines, and gets harder to raise the higher it is.
    local inv = 4 * math.min(p.thread_hits, 2) + (p.m.spotlight - 55) * 0.05 + (p.m.story - 55) * 0.04 - 1
    if inv > 0 then
        inv = inv * (110 - p.investment) / 60
    end
    if p.m.spotlight < M.SIDELINED_AT then
        p.sidelined = p.sidelined + 1
        inv = inv - 2 * p.sidelined
    else
        p.sidelined = 0
    end
    score.add(p, "investment", inv)
    -- Trust drifts slowly back to the middle; open rolls and callouts during the night do the rest.
    score.add(p, "trust", (55 - p.trust) * 0.03)
    p.suspicion = math.max(0, p.suspicion - 2)
    -- Commitment: recent Fun matters most, then tonight, Investment and Trust; life pulls the
    -- other way. It's slower to build than to lose, and slower still near the top.
    local mood = score.mood(p)
    local c = (p.recent_fun - M.FUN_PAR) * 0.12 + (fun - M.FUN_PAR) * 0.06 + (p.investment - 50) * 0.04
        + (p.trust - 50) * 0.04 + (info.hype or 0) - (mood.pressure or 0)
    if c > 0 then
        c = c * 0.45 * util.clamp((105 - p.commitment) / 45, 0, 1)
    end
    score.add(p, "commitment", c)
    p.absent_streak = 0
end

-- A week they missed. One missed week makes people miss the group; more starts a drift.
function M.settle_absent(p)
    p.absent_streak = p.absent_streak + 1
    score.add(p, "commitment", p.absent_streak == 1 and 1 or -2)
    p.suspicion = math.max(0, p.suspicion - 2)
end

-- Record what moved this week, for trend arrows and the one-week-late read.
function M.record(p, before)
    for _, k in ipairs(score.LONG) do
        p.delta_prev[k] = p.delta[k]
        p.delta[k] = p[k] - before[k]
        p.lag[k] = before[k]
    end
end

-- After the report: are they drifting away, or leaving? Returns "wavering", "left" or nil.
function M.standing(p, rng)
    if p.on_break then
        return nil
    end
    if p.commitment < M.WAVER_AT then
        p.wavering = p.wavering + 1
        if p.wavering > M.WAVER_WEEKS and p.commitment < M.LEAVE_AT then
            p.on_break = true
            p.just_left = true
            p.break_left = rng:int(M.BREAK_WEEKS[1], M.BREAK_WEEKS[2])
            p.breaks = p.breaks + 1
            p.wavering = 0
            return "left"
        end
        return "wavering"
    end
    p.wavering = 0
    return nil
end

-- Start of a week for someone on a break: count down, maybe come back.
function M.tick_break(p)
    p.back = false
    if not p.on_break then
        return
    end
    if p.just_left then
        -- The week they leave, they say so; the countdown starts next week.
        return
    end
    p.break_left = p.break_left - 1
    if p.break_left <= 0 then
        p.on_break = false
        p.back = true
        p.wavering = 0
        p.sidelined = 0
        p.recent_fun = nil
        p.commitment = math.max(p.commitment, M.RETURN_COMMITMENT)
    end
end

-- A one-on-one check-in with someone on a break: they feel missed.
function M.check_in(p)
    p.break_left = math.max(1, p.break_left - 2)
    score.add(p, "commitment", 6)
end

return M
