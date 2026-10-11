-- Dice sets: whose dice look like what (game/data/dice.lua). The DM picks one of three sets at
-- the start of a campaign; the players start on plain grey dice. Sets get better as the campaign
-- goes: a gift from the DM after a session, or a player who's loving it turns up with a new set
-- and shows it off before the session starts. The table's trays roll each player's set
-- (main/dice/dice.script). Pure Lua.

local score = require "game.model.score"
local rng_mod = require "game.model.rng"
local data = require "game.data.dice"

local M = {}
M.data = data

function M.get(campaign)
    local d = campaign.dice
    if not d then
        d = { players = {}, gifts = {}, shown = {} }
        campaign.dice = d
    end
    return d
end

-- The dice draw from their own stream, so a new set never shifts what happens at the table.
local function stream(campaign, salt)
    return rng_mod.new((campaign.seed or 1) * 31 + (campaign.week or 0) * 101 + salt)
end

-- Three sets for the DM to choose from (fixed per campaign, so going back shows the same three).
function M.offer(campaign, rng)
    local d = M.get(campaign)
    if not d.offer then
        local pool = {}
        for _, id in ipairs(data.ORDER) do
            if data.SETS[id].tier >= 2 then
                table.insert(pool, id)
            end
        end
        rng = rng or stream(campaign, 7)
        rng:shuffle(pool)
        d.offer = { pool[1], pool[2], pool[3] }
    end
    return d.offer
end

function M.pick_dm(campaign, id)
    if data.SETS[id] then
        M.get(campaign).dm = id
    end
end

function M.dm(campaign)
    local d = M.get(campaign)
    return d.dm or (d.offer and d.offer[1]) or "amethyst"
end

function M.of(campaign, key)
    return M.get(campaign).players[key] or "grey"
end

function M.name(id)
    return (data.SETS[id] or data.SETS.grey).name
end

-- Whose set rolls in which tray.
function M.by_tray(campaign)
    local out = { dm_open = M.dm(campaign), dm_hidden = M.dm(campaign) }
    for _, p in ipairs(campaign.players or {}) do
        out[p.key] = M.of(campaign, p.key)
    end
    return out
end

-- A better set than the one they have: grey gets a nice one, a nice one a fancy one, and a fancy
-- one another fancy one. Never the DM's own.
function M.upgrade_for(campaign, key, rng)
    local cur = data.SETS[M.of(campaign, key)] or data.SETS.grey
    local want = cur.tier < 2 and 2 or 3
    local pool = {}
    for _, id in ipairs(data.ORDER) do
        local s = data.SETS[id]
        if s.tier == want and id ~= M.of(campaign, key) and id ~= M.dm(campaign) then
            table.insert(pool, id)
        end
    end
    if #pool == 0 then
        return nil
    end
    return pool[(rng or stream(campaign, 11)):int(1, #pool)]
end

-- Can the DM give this player a set now? Once a week in all, and not to the same player again
-- for a few weeks.
function M.can_gift(campaign, key)
    local d = M.get(campaign)
    if d.gift_week == campaign.week then
        return false
    end
    local last = d.gifts[key]
    return not last or campaign.week - last >= data.GIFT.again_weeks
end

-- The DM's gift, after the session: a new set, and the table's warm reaction.
function M.gift(campaign, key, rng)
    rng = rng or stream(campaign, 13)
    if not M.can_gift(campaign, key) then
        return nil
    end
    local id = M.upgrade_for(campaign, key, rng)
    if not id then
        return nil
    end
    local d = M.get(campaign)
    d.players[key] = id
    d.gifts[key] = campaign.week
    d.gift_week = campaign.week
    local p = campaign:player(key)
    if p then
        score.add(p, "trust", data.GIFT.trust)
        score.add(p, "investment", data.GIFT.investment)
        p.gift_glow = campaign.week          -- they bring the good mood to next session
    end
    d.last_gift = { key = key, set = id, week = campaign.week }
    return id, data.GIFT_LINES[rng:int(1, #data.GIFT_LINES)]
end

-- Before the session starts: a player who loved last session and is all in may turn up with a
-- new set and show it off. One a night at most. Returns the player and their new set, or nil.
function M.show_off(night)
    local campaign = night.campaign
    local d = M.get(campaign)
    local rng = stream(campaign, 17)
    local cands = {}
    local gifted = d.last_gift and d.last_gift.week == campaign.week - 1 and d.last_gift.key
    for _, p in ipairs(night.players) do
        local s = data.SETS[M.of(campaign, p.key)] or data.SETS.grey
        local recent = d.shown[p.key] and campaign.week - d.shown[p.key] < 3
        if (p.commitment or 0) >= data.SHOW_OFF.commitment and (p.last_tier == "loved" or p.last_tier == "fun")
            and s.tier < 3 and not recent and p.key ~= gifted then
            table.insert(cands, p)
        end
    end
    if #cands == 0 or not rng:chance(data.SHOW_OFF.chance) then
        return nil
    end
    local p = cands[rng:int(1, #cands)]
    local id = M.upgrade_for(campaign, p.key, rng)
    if not id then
        return nil
    end
    d.players[p.key] = id
    d.shown[p.key] = campaign.week
    return p, id
end

-- Whoever the DM gave dice to last week, here tonight to roll them for the first time.
function M.gifted(night)
    local campaign = night.campaign
    local g = M.get(campaign).last_gift
    if not g or g.week ~= campaign.week - 1 then
        return nil
    end
    for _, p in ipairs(night.players) do
        if p.key == g.key then
            return p, g.set
        end
    end
end

-- A line from a list, from the dice's own stream.
function M.line(campaign, list, salt)
    return list[stream(campaign, salt or 19):int(1, #list)]
end

return M
