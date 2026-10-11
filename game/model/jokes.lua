-- Running jokes and shower thoughts (M8, B5). Pure Lua.
--
-- Running jokes come from the event log (game/model/ledger.lua, B1): a pratfall, a natural 1
-- in dice jail, a curveball, someone the DM made up on the spot. The report flags a new one;
-- on a later night a callback card can bring it back, a Social spike for the table. Each
-- callback wears it a little, and it goes stale by the shared rule (game/model/stale.lua).
--
-- Shower thoughts: zero to two a week, a card from the deck that comes to you out of nowhere.
-- It arrives pinned in the hand, marked "Shower thought", and costs nothing to place.

local content = require "game.model.content"
local score = require "game.model.score"
local stale = require "game.model.stale"
local util = require "game.model.util"

local M = {}

M.CALLBACK_SOCIAL = 8      -- a fresh joke called back: Social for everyone
M.STALE_FUN = -2           -- a joke called back once too often
M.SHOWER = { 0.3, 0.5, 0.2 }   -- chances of 0, 1 and 2 shower thoughts a week

function M.list(campaign)
    campaign.jokes = campaign.jokes or {}
    return campaign.jokes
end

-- After the night: tonight's moments that could become running jokes. Returns the new ones.
local KINDS = {
    fail_card = function(e) return e.kind == "pratfall" and e.text end,
    jail = function(e) return e.text end,
    curveball = function(e) return e.text end,
}

function M.after_night(campaign, night)
    local list = M.list(campaign)
    local new = {}
    local have = {}
    for _, j in ipairs(list) do
        have[j.text] = true
    end
    local jailed = {}
    for _, e in ipairs(night.ledger or {}) do
        local f = e.ev and KINDS[e.ev]
        local text = f and f(e)
        -- One dice-jail joke per player: "Jess's d20 is a repeat offender".
        if e.ev == "jail" then
            local n = (campaign.fails and campaign.fails.jail and campaign.fails.jail[e.who]) or 0
            if n >= 2 and not jailed[e.who] then
                local p = campaign:player(e.who)
                text = p and (p.name .. "'s d20 is a repeat offender") or nil
                jailed[e.who] = true
            else
                text = nil
            end
        end
        if text and not have[text] and #new < 2 then
            local j = { text = text, born = campaign.week, uses = 0, who = e.who, origin = e.ev }
            table.insert(list, j)
            table.insert(new, j)
            have[text] = true
        end
    end
    -- Someone made up on the spot who stuck around: an NPC's quirk.
    for id in pairs(night.improvised or {}) do
        local c = content.components[id]
        if c and c.kind == "cast" and #new < 2 then
            local text = (c.short and util.capitalize(c.short) or c.name) .. ", who you made up on the spot"
            if not have[text] then
                local j = { text = text, born = campaign.week, uses = 0, who = "party", origin = "improv", card = id }
                table.insert(list, j)
                table.insert(new, j)
                have[text] = true
            end
        end
    end
    return new
end

-- A joke ready for a callback tonight: ripe, not called back last week, the freshest first.
function M.ripe(campaign)
    local best, best_f
    for _, j in ipairs(M.list(campaign)) do
        if j.born < campaign.week and stale.state(j, campaign.week, "joke") == "ripe" and not stale.too_soon(j, campaign.week, 2) then
            local f = stale.freshness(j, campaign.week, "joke")
            if not best_f or f > best_f then
                best, best_f = j, f
            end
        end
    end
    return best
end

-- The callback card for a joke.
function M.card(j)
    return {
        id = "callback", type = "table", title = "A running joke",
        text = "Somebody's grinning. This is the moment for it: " .. j.text .. ".",
        options = {
            { label = "Call it back.", log = "You call it back. The table loses it.", callback = true, effects = {} },
            { label = "Not tonight.", log = "You let it lie. It'll keep.", effects = {} },
        },
    }
end

-- They called it back: how it lands depends on how fresh it still is.
function M.called(night, j)
    local campaign = night.campaign
    local f = stale.freshness(j, campaign.week, "joke")
    stale.use(j, campaign.week)
    for _, p in ipairs(night.players) do
        if f > 0.2 then
            score.add(p, "social", M.CALLBACK_SOCIAL * f)
            score.add(p, "fun", 3 * f)
        else
            score.add(p, "fun", M.STALE_FUN)
        end
    end
    night:event("joke", { who = j.who or "party", joke = j.text, text = "The running joke came back: " .. j.text .. ".",
                          weight = f > 0.2 and 5 or 2, stale = f <= 0.2 })
    if f <= 0.2 then
        night:say("It's been told one time too many. A couple of polite smiles.", "aside")
    end
end

-- Shower thoughts for this week's hand (B5): deck cards that aren't in the hand, the ones tied
-- to a quiet player's story first, pinned and free.
function M.shower_thoughts(campaign, prep, rng)
    local roll = rng:next()
    local n = roll < M.SHOWER[1] and 0 or (roll < M.SHOWER[1] + M.SHOWER[2] and 1 or 2)
    if n == 0 or campaign.week < 2 then
        return {}
    end
    local deck = require "game.model.deck"
    local d = deck.get(campaign)
    local in_hand = {}
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep.hand[kind] or {}) do
            in_hand[c.id] = true
        end
    end
    local low
    for _, p in ipairs(campaign.players) do
        if p.present and (not low or p.investment < low.investment) then
            low = p
        end
    end
    local pool, weights = {}, {}
    for id, e in pairs(d.cards) do
        local c = content.components[id]
        if c and e.state == "deck" and not in_hand[id] and not prep:pinned(id) and not c.agenda then
            table.insert(pool, c)
            table.insert(weights, (low and c.thread == low.key) and 4 or (e.from and 2 or 1))
        end
    end
    table.sort(pool, function(a, b) return a.id < b.id end)
    -- (weights follow the same order as the sorted pool)
    weights = {}
    for i, c in ipairs(pool) do
        local e = d.cards[c.id]
        weights[i] = (low and c.thread == low.key) and 4 or (e.from and 2 or 1)
    end
    local out = {}
    for _ = 1, n do
        if #pool == 0 then
            break
        end
        local idx = {}
        for i = 1, #pool do
            idx[i] = i
        end
        local i = rng:weighted(idx, weights)
        local c = table.remove(pool, i)
        table.remove(weights, i)
        prep:pin(c.id, "Shower thought", "It came to you in the shower.", { free = true, shower = true })
        table.insert(out, c)
    end
    return out
end

return M
