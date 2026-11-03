-- Rewards after a session (the playtest, November 3: "the DM should earn new dice that can be gifted
-- to players only through happy sessions... like opening a loot box"). A happy table earns a box; a
-- box holds one set of dice, its rarity rolled (game/data/dice.lua RARITIES: common to mythic), and a
-- happier night tips the odds. What you win goes in your dice bag, to give to a friend from the
-- report. Later, boxes can hold more than dice. Pure Lua: its own random stream, so opening a box
-- never shifts what happens at the table.

local rng_mod = require "game.model.rng"
local dice = require "game.data.dice"
local dice_sets = require "game.model.dice_sets"

local M = {}

M.GOOD = 55       -- the Table Score that earns a box
M.GREAT = 72      -- ...and a better box

local function stream(campaign, salt)
    return rng_mod.new((campaign.seed or 1) * 53 + (campaign.week or 0) * 211 + salt)
end

function M.rarity(id)
    for i, r in ipairs(dice.RARITIES) do
        if r.id == id then
            return r, i
        end
    end
    return nil, 0
end

function M.bag(campaign)
    local d = dice_sets.get(campaign)
    d.bag = d.bag or {}
    return d.bag
end

-- What tonight earned: nil, or { quality = "box" | "great", score }.
function M.earned(campaign, rep)
    local score = rep and rep.score or 0
    if score >= M.GREAT then
        return { quality = "great", score = score }
    elseif score >= M.GOOD then
        return { quality = "box", score = score }
    end
    return nil
end

-- The odds, in order of rarity, for a box of this quality: { { rarity, chance 0..1 } }.
function M.odds(quality)
    local out, total = {}, 0
    for i, r in ipairs(dice.RARITIES) do
        local w = r.weight
        if quality == "great" then
            -- (A great night: commons halve, everything rarer doubles.)
            w = i == 1 and w * 0.5 or w * 2
        end
        table.insert(out, { r, w })
        total = total + w
    end
    for _, o in ipairs(out) do
        o[2] = o[2] / total
    end
    return out
end

-- Has this week's box been opened? { set, rarity, week } once it has.
function M.opened(campaign)
    local d = dice_sets.get(campaign)
    local o = d.opened
    return o and o.week == campaign.week and o or nil
end

-- Open this week's box: roll the rarity, then a set of it you don't already have in the bag (any of
-- it if you have them all). Into the bag it goes. Returns { set, rarity, week }.
function M.open(campaign, quality)
    local done = M.opened(campaign)
    if done then
        return done
    end
    local rng = stream(campaign, 3)
    local roll = rng:next()
    local pick
    for _, o in ipairs(M.odds(quality)) do
        roll = roll - o[2]
        if roll <= 0 then
            pick = o[1]
            break
        end
    end
    pick = pick or dice.RARITIES[1]
    local have = {}
    for _, sid in ipairs(M.bag(campaign)) do
        have[sid] = true
    end
    local pool, any = {}, {}
    for _, sid in ipairs(dice.ORDER) do
        local s = dice.SETS[sid]
        if s.rarity == pick.id then
            table.insert(any, sid)
            if not have[sid] then
                table.insert(pool, sid)
            end
        end
    end
    if #pool == 0 then
        pool = any
    end
    local sid = pool[rng:int(1, #pool)]
    table.insert(M.bag(campaign), sid)
    local d = dice_sets.get(campaign)
    d.opened = { set = sid, rarity = pick.id, week = campaign.week }
    return d.opened
end

-- Give a set from the bag to a friend: theirs now, out of the bag; the rarer, the more it means to
-- them. Once a session. Returns true when it went.
function M.give(campaign, key, sid)
    local bag = M.bag(campaign)
    local at
    for i, b in ipairs(bag) do
        if b == sid then
            at = i
        end
    end
    local d = dice_sets.get(campaign)
    if not at or d.gift_week == campaign.week then
        return false
    end
    table.remove(bag, at)
    local s = dice.SETS[sid]
    local r = M.rarity(s and s.rarity)
    local k = r and r.gift or 1
    d.players[key] = sid
    d.gifts[key] = campaign.week
    d.gift_week = campaign.week
    d.last_gift = { key = key, set = sid, week = campaign.week }
    local p = campaign:player(key)
    if p then
        local score = require "game.model.score"
        score.add(p, "trust", dice.GIFT.trust * k)
        score.add(p, "investment", dice.GIFT.investment * k)
        p.gift_glow = campaign.week
        require("game.model.keepsakes").dice_given(campaign, key)
    end
    return true
end

return M
