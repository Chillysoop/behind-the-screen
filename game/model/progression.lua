-- rules: 5e   (5e's own, reached through the rule set: docs/design/rule-sets.md)
-- Level-ups (M6): when the party levels, and what each player picks. Pure Lua.
--
-- The DM decides when (the report and the prep board offer it once the party has
-- played READY_AFTER nights at a level, and flag it overdue after OVERDUE_AFTER).
-- The players decide what: at level 3 everyone picks a subclass on their own, from
-- who they are (archetypes) and what they've enjoyed (their meter history). You can't
-- pick for them.

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
local content = require "game.model.content"
local score = require "game.model.score"
local subclasses = ruleset.part("subclasses")
local util = require "game.model.util"

local M = {}

local function data()
    return content.progression
end

function M.init(campaign)
    -- (The adventure's own starting level when it has one: the Sheep Chase is for level 4.)
    local adv = util.lazy("game.model.adventure")
    campaign.level = (adv.data and adv.data.START_LEVEL) or data().START_LEVEL
    campaign.level_nights = 0
    campaign.subclasses = nil      -- class -> subclass id, from level 3
    campaign.picks = {}            -- player key -> the pick record
    campaign.levelups = {}         -- history: { week, level }
end

-- Where the party stands: { level, nights, ready, overdue, max }.
function M.status(campaign)
    local d = data()
    local s = { level = campaign.level, nights = campaign.level_nights, max = campaign.level >= d.MAX_LEVEL }
    -- v2: the book's milestones (game/model/museum_week.lua).
    s.ready = not s.max and util.lazy("game.model.museum_week").level_ready(campaign) == true
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

-- Score every subclass of this player's class. Returns a list of
-- { id, total, arch, hist } sorted best first (without noise).
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
        table.insert(out, { id = id, arch = arch, hist = hist, total = arch + hist })
    end
    table.sort(out, function(a, b)
        return a.total > b.total
    end)
    return out
end

-- The biggest reason behind a pick: "hist" or "arch".
local function reason_of(s)
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
    local text = util.fill(sd.why[why], { name = p.name, char = p.char })
    return {
        key = p.key, class = p.class, sub = best.id, sub_name = subclasses.list[best.id].name,
        reason = why, why = text, scores = list, odds = o.odds,
    }
end

-- Level the party up. Returns the moment for the screen:
-- { level, picks = { pick records }, asi = true at level 4 }.
function M.level_up(campaign, force)
    local d = data()
    local s = M.status(campaign)
    if not (s.ready or force) then
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
                score.add(p, "investment", d.PICK_INVESTMENT)
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
    -- A new level is a fresh start: everyone's back to full hit points, spell slots, Hit Dice and
    -- features at the next night (fight.load_state builds new sheets). Said on the level-up screen
    -- (the second playtest review, F23: a hard fight's damage vanished between screens, unsaid).
    -- Healing potions are things in their packs (items.lua): a drunk one stays drunk.
    local ps = campaign.party_state
    local was = {}
    for _, p in ipairs(campaign.players) do
        local s0 = ps and not ps.rested and ps.pcs and ps.pcs[p.key]
        if s0 and s0.hp and s0.hp_max and s0.hp < s0.hp_max then
            table.insert(was, { name = p.char or p.name, hp = s0.hp, hp_max = s0.hp_max })
        end
    end
    if ps then
        ps.rested = true          -- (the refill, said and done: next night starts fresh)
    end
    table.sort(was, function(a, b) return a.hp / a.hp_max < b.hp / b.hp_max end)
    local line = "Everyone's back to full: hit points, spell slots and Hit Dice, all of it, for next session."
    if #was > 0 then
        local w = was[1]
        line = line .. " " .. w.name .. " was down to " .. math.floor(w.hp) .. " of " .. math.floor(w.hp_max) .. " hit points."
    end
    moment.refill = line
    campaign.leveled_now = moment -- the moment the level-up screen shows
    return moment
end

-- The levels a new adventure needs, at its start (adventure.handoff's campaign.level_due): one level-up after another,
-- each the players' own picks. The last one is what the level-up screen shows.
function M.catch_up(campaign)
    local to = campaign.level_due
    campaign.level_due = nil
    local moment
    while to and (campaign.level or 1) < to do
        moment = M.level_up(campaign, true)
    end
    return moment
end

-- Something real behind a subclass: the player's archetypes, or the nights they've had.
function M.has_reason(s)
    local d = data()
    return s.arch >= d.FLOOR or s.hist >= d.HIST_FLOOR
end

return M
