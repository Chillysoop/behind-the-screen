-- Level-ups (M6): when the party levels, and what each player picks. Pure Lua.
--
-- The DM decides when (the report and the prep board offer it once the party has
-- played READY_AFTER nights at a level, and flag it overdue after OVERDUE_AFTER).
-- The players decide what: at level 3 everyone picks a subclass on their own, from
-- who they are (archetypes), what they've enjoyed (their meter history) and the story
-- (seeds that nudge them). You can't pick for them; a seed can only make one tempting.

local content = require "game.model.content"
local score = require "game.model.score"
local subclasses = require "game.rules.subclasses"
local util = require "game.model.util"

local M = {}

local function data()
    return content.progression
end

function M.init(campaign)
    campaign.level = data().START_LEVEL
    campaign.level_nights = 0
    campaign.subclasses = nil      -- class -> subclass id, from level 3
    campaign.picks = {}            -- player key -> the pick record
    campaign.levelups = {}         -- history: { week, level }
end

-- Where the party stands: { level, nights, ready, overdue, max }.
function M.status(campaign)
    local d = data()
    local s = { level = campaign.level, nights = campaign.level_nights, max = campaign.level >= d.MAX_LEVEL }
    s.ready = not s.max and campaign.level_nights >= d.READY_AFTER
    if campaign.module then
        -- v2: the book's milestones (game/model/museum_week.lua).
        s.ready = not s.max and require("game.model.util").lazy("game.model.museum_week").level_ready(campaign) == true
    end
    s.overdue = s.ready and campaign.level_nights >= d.OVERDUE_AFTER
    return s
end

-- Each night played at this level, and what the players' nights have been like.
function M.after_night(campaign, night)
    campaign.level_nights = campaign.level_nights + 1
    for _, p in ipairs(night.players) do
        p.meter_avg = p.meter_avg or {}
        for _, k in ipairs(score.METERS) do
            local prev = p.meter_avg[k]
            p.meter_avg[k] = prev and (0.6 * prev + 0.4 * p.m[k]) or p.m[k]
        end
        p.spot_avg = p.meter_avg.spotlight
    end
end

-- Start of a week: an overdue level-up wears on the people who care about numbers.
function M.start_week(campaign)
    local s = M.status(campaign)
    if not s.overdue then
        return
    end
    for _, p in ipairs(campaign.players) do
        local care = score.arch(p, "power_gamer") + score.arch(p, "butt_kicker")
        if care > 0 and not p.on_break then
            score.add(p, "investment", -data().OVERDUE_INVESTMENT * care)
        end
    end
end

-- How much a seed nudges this subclass, and the strongest seed behind it.
local function seed_nudge(campaign, sub)
    local d = data()
    local total, best, best_v = 0, nil, 0
    for _, s in ipairs(campaign.seeds and campaign.seeds.planted or {}) do
        local def = content.seeds[s.id]
        local w = def.nudge and def.nudge[sub]
        if w then
            local v = (s.state == "paid" and d.SEED_PAID or d.SEED_PLANTED) + d.SEED_HYPED * (s.hype or 0)
            v = v * w
            total = total + v
            if v > best_v then
                best, best_v = def, v
            end
        end
    end
    return total, best
end

-- Score every subclass of this player's class. Returns a list of
-- { id, total, arch, hist, seed, seed_def } sorted best first (without noise).
function M.scores(campaign, p)
    local d = data()
    local out = {}
    for _, id in ipairs(subclasses.by_class[p.class]) do
        local sd = d.subclasses[id]
        local arch = (2 * (sd.arch[p.primary] or 0) + (sd.arch[p.secondary] or 0)) / 3
        local hist = 0
        if p.meter_avg then
            local n = 0
            for _, k in ipairs(sd.meters) do
                hist = hist + ((p.meter_avg[k] or 50) - 50) / 50
                n = n + 1
            end
            hist = n > 0 and d.HISTORY * hist / n or 0
        end
        local seed, seed_def = seed_nudge(campaign, id)
        table.insert(out, { id = id, arch = arch, hist = hist, seed = seed, seed_def = seed_def,
                            total = arch + hist + seed })
    end
    -- Nudge, never force: a seed can't lift a subclass more than SEED_EDGE past the best
    -- other option (as that option stands before this cap).
    local edge = d.SEED_EDGE or math.huge
    local raw = {}
    for i, s in ipairs(out) do
        raw[i] = s.total
    end
    for i, s in ipairs(out) do
        if s.seed > 0 then
            local other = -math.huge
            for j = 1, #out do
                if j ~= i and raw[j] > other then
                    other = raw[j]
                end
            end
            if other > -math.huge then
                -- Only the total is capped: the seed still gets the credit (reason_of,
                -- has_reason, the "why" line) when it's what the player cares about.
                local cap = math.max(0, other + edge - (s.arch + s.hist))
                s.total = s.arch + s.hist + math.min(s.seed, cap)
            end
        end
    end
    table.sort(out, function(a, b)
        return a.total > b.total
    end)
    return out
end

-- The biggest reason behind a pick: "seed", "hist" or "arch".
local function reason_of(s)
    if s.seed >= 0.3 and s.seed >= s.arch * 0.5 then
        return "seed"
    end
    if s.hist > 0.12 and s.hist > s.arch * 0.5 then
        return "hist"
    end
    return "arch"
end

-- A player picks their own subclass: likelier the more is behind it, never one with
-- nothing behind it (below FLOOR), and never certain while two options are close.
-- The candidates a player is weighing and how likely each is: { cands = { { s, w } },
-- total, list, odds = { [subclass] = probability } }.
function M.odds(campaign, p)
    local d = data()
    local list = M.scores(campaign, p)
    local cands, total = {}, 0
    for _, s in ipairs(list) do
        if M.has_reason(s) then
            local w = math.exp((s.total - list[1].total) / d.TEMPERATURE)
            table.insert(cands, { s = s, w = w })
            total = total + w
        end
    end
    if #cands == 0 then
        cands[1] = { s = list[1], w = 1 }
        total = 1
    end
    local odds = {}
    for _, c in ipairs(cands) do
        odds[c.s.id] = c.w / total
    end
    return { cands = cands, total = total, list = list, odds = odds }
end

function M.pick(campaign, p, rng)
    local d = data()
    local o = M.odds(campaign, p)
    local list, cands, total = o.list, o.cands, o.total
    local roll = rng:next() * total
    local best = cands[#cands].s
    for _, c in ipairs(cands) do
        roll = roll - c.w
        if roll <= 0 then
            best = c.s
            break
        end
    end
    local why = reason_of(best)
    local sd = d.subclasses[best.id]
    local text = util.fill(sd.why[why], { name = p.name, char = p.char,
                                          seed = best.seed_def and best.seed_def.name or "the story" })
    return {
        key = p.key, class = p.class, sub = best.id, sub_name = subclasses.list[best.id].name,
        reason = why, why = text, scores = list, odds = o.odds, nudged = why == "seed",
    }
end

-- Level the party up. Returns the moment for the screen:
-- { level, picks = { pick records }, asi = true at level 4 }.
function M.level_up(campaign)
    local d = data()
    local s = M.status(campaign)
    if not s.ready then
        return nil
    end
    campaign.level = campaign.level + 1
    campaign.level_nights = 0
    table.insert(campaign.levelups, { week = campaign.week, level = campaign.level })
    local moment = { level = campaign.level, picks = {} }
    if campaign.level == 3 then
        campaign.subclasses = {}
        for _, p in ipairs(campaign.players) do
            local pick = M.pick(campaign, p, campaign.rng)
            campaign.subclasses[p.class] = pick.sub
            campaign.picks[p.key] = pick
            table.insert(moment.picks, pick)
            if not p.on_break then
                score.add(p, "investment", d.PICK_INVESTMENT + (pick.nudged and d.NUDGED_INVESTMENT or 0))
                score.add(p, "commitment", 2)
            end
        end
    else
        moment.asi = true
        for _, p in ipairs(campaign.players) do
            if not p.on_break then
                score.add(p, "investment", d.ASI_INVESTMENT)
            end
        end
    end
    campaign.leveled_now = moment -- the moment the level-up screen shows
    return moment
end

-- Something real behind a subclass: the player's archetypes, the nights they've had, or a
-- seed they cared about.
function M.has_reason(s)
    local d = data()
    return s.arch >= d.FLOOR or s.seed >= d.FLOOR or s.hist >= d.HIST_FLOOR
end

-- A pick feels true to its player when something real is behind it. Used by the M6 gate.
function M.true_to_player(pick)
    for _, e in ipairs(pick.scores) do
        if e.id == pick.sub then
            return M.has_reason(e)
        end
    end
    return false
end

return M
