-- The session report: how everyone felt, what changed, and the best moments.
-- Also settles the long-term bars. Pure Lua.

local content = require "game.model.content"
local score = require "game.model.score"
local bars = require "game.model.bars"
local util = require "game.model.util"

local M = {}

-- The words that stay capitalised mid-sentence: the heroes, the people, the places.
function M.names(campaign)
    local names = {}
    local function add(t)
        for w in string.gmatch(t or "", "%u[%a']*") do
            names[w] = true
            names[(string.gsub(w, "'s$", ""))] = true
        end
    end
    for _, p in ipairs(campaign.players or {}) do
        add(p.char)
        add(p.old_char)
    end
    for _, c in pairs(content.components) do
        if type(c) == "table" and (c.kind == "cast" or c.kind == "location") then
            add(c.short)
            add(string.match(c.name or "", "^([^,]+)"))
        end
    end
    for _, w in ipairs({ "The", "A", "An" }) do
        names[w] = nil
    end
    return names
end

-- One line of why (B7): the night's biggest thing for them, or what they got (or missed) of what
-- they care about most.
local GOT = { spotlight = "the time in the spotlight", challenge = "the real challenge", story = "the story",
              social = "the time with the others", reward = "the loot" }
local MORE = { spotlight = "time in the spotlight", challenge = "of a challenge", story = "story", social = "time with the others",
               reward = "loot" }
local SOME = { spotlight = "Some time in the spotlight", challenge = "Some challenge", story = "Some story",
               social = "Some time with the others", reward = "Some loot" }
function M.why(p, night)
    for _, e in ipairs(night.ledger or {}) do
        if e.ev and e.who == p.key then
            if e.ev == "death" then
                return "Lost " .. (p.old_char or p.char) .. " tonight."
            elseif e.ev == "theory" then
                return "Their theory came true."
            elseif e.ev == "killing_blow" then
                return "Landed the killing blow."
            end
        end
    end
    if p.boredom >= 30 then
        return "Bored for long stretches."
    end
    local best, bw
    for _, k in ipairs(score.METERS) do
        local w = score.weight(p, k)
        if not bw or w > bw then
            best, bw = k, w
        end
    end
    local v = p.m[best] or 0
    if v >= 60 then
        return "Got " .. GOT[best] .. " they came for."
    elseif v < 35 then
        return "Wanted more " .. MORE[best] .. "."
    end
    return SOME[best] .. ", not quite enough."
end

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
            -- What they say for the report card, in their own voice ("The bit where {moment}").
            local quote, line = night.talk:line("report_quote", p, { split = row.tier,
                moment = util.mid_sentence(moment, M.names(campaign)) })
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
        -- Suspicion names its source (A11).
        if row.long.suspicion.delta > 0.5 and night.suspicion_cause then
            row.suspicion_why = night:suspicion_cause(p)
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
    -- The verdict (B7): the Table Score, and the recap for the DM.
    local recap = require "game.model.recap"
    local funs = {}
    for _, row in ipairs(rep.players) do
        if row.fun then
            table.insert(funs, row.fun)
        end
    end
    rep.score, rep.verdict = recap.table_score(funs)
    -- Heroic Inspiration handed out (or spent) tonight, for "What it earned".
    rep.inspiration = {}
    for _, e in ipairs(night.ledger or {}) do
        if e.ev == "inspiration" then
            table.insert(rep.inspiration, { text = e.text, spent = e.spent })
        end
    end
    rep.recap = recap.build(campaign, night, night.rng)
    -- One line of why for each player, and the least happy first.
    for _, row in ipairs(rep.players) do
        local p = campaign:player(row.key)
        if row.fun and p then
            row.why = M.why(p, night)
        end
    end
    rep.order = {}
    for _, row in ipairs(rep.players) do
        table.insert(rep.order, row)
    end
    table.sort(rep.order, function(a, b)
        return (a.fun or 101) < (b.fun or 101)
    end)
    -- The headline agrees with the verdict: both read the Table Score.
    local HEAD = { ["One for the stories"] = "The group chat is going to be busy tonight.",
                   ["Great session"] = "A great night at the table.", ["Good session"] = "A good night at the table.",
                   Okay = "A decent night. Not everyone was into it.",
                   ["Rough night"] = "A rough one. Someone had a bad night, and the table felt it." }
    rep.headline = HEAD[rep.verdict] or HEAD.Okay
    return rep
end

return M
