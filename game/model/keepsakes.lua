-- Keepsakes: gifts from the table (game/data/keepsakes.lua). A good night fills a player's Goodwill
-- (the heart on their card in prep); a full heart means they bring you something as they pack up,
-- picked for who they are. How you take it moves their Trust. Whatever they gave you stays on your
-- side of the real table from then on (main/keepsakes/keepsakes.script), and a giver who sees it
-- there each session enjoys the night a little more. Pure Lua.

local data = require "game.data.keepsakes"
local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local util = require "game.model.util"

local M = {}
M.data = data

function M.get(campaign)
    local k = campaign.keepsakes
    if not k then
        k = { goodwill = {}, given = {} }
        campaign.keepsakes = k
    end
    return k
end

function M.goodwill(campaign, key)
    return M.get(campaign).goodwill[key] or 0
end

-- The heart is never a number: how full it looks.
function M.heart_words(gw)
    local f = gw / data.FULL
    if f <= 0 then
        return "empty"
    elseif f < 0.3 then
        return "warming up"
    elseif f < 0.6 then
        return "about half full"
    elseif f < 0.9 then
        return "nearly full"
    elseif f < 1 then
        return "all but full"
    end
    return "full"
end

-- Their own stream, so a gift never shifts what happens at the table.
local function stream(campaign, salt)
    return rng_mod.new((campaign.seed or 1) * 37 + (campaign.week or 0) * 113 + salt)
end

function M.def(id)
    return data.GIFTS[id]
end

-- What this player brings: their kind of gift (primary archetype, then secondary), one you
-- haven't been given yet.
function M.choose(campaign, p)
    local had = {}
    for _, g in ipairs(M.get(campaign).given) do
        had[g.id] = true
    end
    local rng = stream(campaign, 5)
    for _, field in ipairs({ "primary", "secondary" }) do
        local pool = {}
        for _, id in ipairs(data.ORDER) do
            if not had[id] and data.GIFTS[id].from[p[field] or ""] then
                table.insert(pool, id)
            end
        end
        if #pool > 0 then
            return pool[rng:int(1, #pool)]
        end
    end
    for _, id in ipairs(data.ORDER) do
        if not had[id] then
            return id
        end
    end
    return nil
end

-- After the night (campaign:finish_night, once the report's built): every heart fills by how the
-- night went for them (and a moment like their stolen theory coming true fills it more), and the
-- fullest full heart, of someone who was there, brings a gift. Returns the gift, { id, from, week },
-- or nil.
function M.after_night(campaign, rep, night)
    local k = M.get(campaign)
    local moments = night and night.heart_moments or {}
    for _, row in ipairs(rep.players or {}) do
        if row.present and row.tier then
            local p = campaign:player(row.key)
            local add = data.GOODWILL[row.tier] or 0
            if p and (p.thread_hits or 0) > 0 then
                add = add + data.THREAD
            end
            if moments[row.key] then
                add = add + data.MOMENT
            end
            k.goodwill[row.key] = util.clamp((k.goodwill[row.key] or 0) + add, 0, data.FULL)
        end
    end
    local best, most = nil, data.FULL - 0.5
    for _, row in ipairs(rep.players or {}) do
        local gw = k.goodwill[row.key] or 0
        if row.present and gw > most then
            best, most = row.key, gw
        end
    end
    if not best then
        return nil
    end
    local id = M.choose(campaign, campaign:player(best))
    if not id then
        return nil
    end
    k.goodwill[best] = 0
    local g = { id = id, from = best, week = campaign.week }
    table.insert(k.given, g)
    return g
end

-- The DM gave them dice: that counts too.
function M.dice_given(campaign, key)
    local k = M.get(campaign)
    k.goodwill[key] = util.clamp((k.goodwill[key] or 0) + data.DICE, 0, data.FULL)
end

-- Tonight's gift, still waiting for you to react to it.
function M.waiting(campaign)
    local given = M.get(campaign).given
    local g = given[#given]
    if g and g.week == campaign.week and not g.how then
        return g
    end
    return nil
end

local function reaction(id)
    for _, r in ipairs(data.REACTIONS) do
        if r.id == id then
            return r
        end
    end
end

-- How you take it: "gush", "use" or "cool". It moves the giver's Trust by who they are (two
-- thirds their main style, a third their other one). Returns what you do, and how it landed.
function M.react(campaign, how)
    local g = M.waiting(campaign)
    local r = reaction(how)
    if not g or not r then
        return nil
    end
    local p = campaign:player(g.from)
    local like = 0
    if p then
        local a = r.like[p.primary or ""] or 1
        local b = r.like[p.secondary or ""] or a
        like = math.floor((2 * a + b) / 3 + 0.5)
        score.add(p, "trust", like)
        if r.investment then
            score.add(p, "investment", r.investment)
        end
    end
    g.how, g.landed = how, like
    local def = data.GIFTS[g.id]
    local said = util.fill(data.SAID[how], { use = def.use })
    local landed
    for _, l in ipairs(data.LANDED) do
        if like >= l.at then
            landed = util.fill(l.text, { name = p and p.name or "They" })
            break
        end
    end
    g.said, g.landed_text = said, landed
    return said, landed
end

-- What's on your side of the table, in the order you were given it.
function M.on_table(campaign)
    local out = {}
    for _, g in ipairs(M.get(campaign).given) do
        table.insert(out, g.id)
    end
    return out
end

-- Last session's gift, new on the table this week (it drops in when prep opens).
function M.new_this_week(campaign)
    local given = M.get(campaign).given
    local g = given[#given]
    return g and g.week == (campaign.week or 0) - 1 and g.id or nil
end

-- What this player has given you, oldest first.
function M.from(campaign, key)
    local out = {}
    for _, g in ipairs(M.get(campaign).given) do
        if g.from == key then
            table.insert(out, g)
        end
    end
    return out
end

M.NOTICE = { "You actually set it up!", "Oh, it looks good there.", "Okay, that's the perfect spot for it.",
             "Look at that. It's like it was always there." }

-- At the start of a session: every giver who's here sees their gift on your side of the table,
-- and whoever's gift you put to work last week says so.
function M.at_night(night)
    local camp = night.campaign
    local here = {}
    for _, p in ipairs(night.players) do
        here[p.key] = p
    end
    local noticed
    for _, g in ipairs(M.get(camp).given) do
        local p = here[g.from]
        if p then
            score.add(p, "fun", data.ON_TABLE_FUN)
            if g.week == camp.week - 1 and g.how == "use" and not noticed then
                noticed = g
            end
        end
    end
    if noticed then
        local p = here[noticed.from]
        local def = data.GIFTS[noticed.id]
        night:emit({ kind = "keepsake", who = p.key, id = noticed.id, short = def.short })
        night:emit({ kind = "say", who = p.key, text = M.NOTICE[(camp.week % #M.NOTICE) + 1], ic = false })
        score.add(p, "fun", data.USED_FUN)
    end
end

return M
