-- The session report: how everyone felt, what changed, and the best moments.
-- Also settles the long-term bars. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local bars = require "game.model.bars"
local util = require "game.model.util"

local M = {}

-- Settle a finished night. Returns the report table the screen draws.
function M.build(campaign, night)
    local rep = {
        week = campaign.week,
        players = {},
        moments = {},
        canon = {},
        threads = {},
        hype = 0,
        rolls = night.rolls,
        callouts = night.callouts,
        checks = night.checks,
    }

    -- Cliffhanger in the last scene: everyone can't wait for next week.
    local last = night.scenes[#night.scenes]
    if last.comps.complication and last.comps.complication.cliffhanger then
        rep.hype = 5
    end

    for _, p in ipairs(campaign.players) do
        local before = night.before[p.key]
        local row = { key = p.key, name = p.name, char = p.char, present = p.present }
        if p.present then
            local fun = score.fun(p)
            row.fun = fun
            row.tier = score.tier(fun)
            row.meters = {}
            for _, k in ipairs(score.METERS) do
                row.meters[k] = p.m[k]
            end
            -- Long-term bars move with how the night went.
            bars.settle_played(p, fun, { hype = rep.hype })
            if p.thread_hits > 0 then
                p.thread_progress = p.thread_progress + p.thread_hits
                table.insert(rep.threads, p.char .. ": " .. p.thread .. " (" .. util.int(p.thread_progress) .. ")")
            end
            local moment = p.best and p.best.text or nil
            row.moment = moment
            -- What they say for the report card, in their own voice.
            local quote, line = night.talk:line("report_quote", p, { split = row.tier, moment = moment })
            row.quote = quote or content.chat.verdicts[row.tier]
            row.quote_line = line and line.id
            p.last_tier = row.tier
            p.last_moment = moment
        elseif p.on_break then
            row.on_break = true
            p.suspicion = math.max(0, p.suspicion - 2)
            p.last_tier = nil
        else
            bars.settle_absent(p)
            p.last_tier = nil
        end
        bars.record(p, before)
        row.long = {}
        for _, k in ipairs(score.LONG) do
            row.long[k] = { value = p[k], delta = p[k] - before[k] }
        end
        row.verdict = row.tier and content.chat.verdicts[row.tier] or (row.on_break and "On a break" or "Couldn't make it")
        table.insert(rep.players, row)
    end

    -- Best moments of the night, highest first, no repeats.
    table.sort(night.highlights, function(a, b)
        return a.score > b.score
    end)
    local seen = {}
    for _, h in ipairs(night.highlights) do
        if not seen[h.text] and #rep.moments < 3 then
            seen[h.text] = true
            table.insert(rep.moments, h.text)
        end
    end

    for _, c in ipairs(night.canon) do
        table.insert(rep.canon, c)
        table.insert(campaign.canon, c)
    end

    -- Average Fun, for the headline.
    local total, n = 0, 0
    for _, row in ipairs(rep.players) do
        if row.fun then
            total = total + row.fun
            n = n + 1
        end
    end
    rep.average = n > 0 and total / n or 0
    if rep.average >= 70 then
        rep.headline = "The group chat is going to be busy tonight."
    elseif rep.average >= 55 then
        rep.headline = "A good night at the table."
    elseif rep.average >= 40 then
        rep.headline = "A decent night. Not everyone was into it."
    else
        rep.headline = "A rough one. People will remember this week."
    end
    return rep
end

return M
