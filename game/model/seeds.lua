-- Seeds and inspiration (M6). Pure Lua.
--
-- Seeds: plant one during prep (game/data/seeds.lua); game night mentions it; from the
-- next week its payoff card is in your hand for a few weeks. Put that card on the board
-- and it pays off: a big story moment, and a nudge toward the subclasses it suits. Leave
-- it too long and it goes stale. The group chat theorizes about planted seeds, and how
-- you answer (encourage, deflect, shoot it down) changes how big the payoff feels.
--
-- Inspiration: what the DM does with an evening off (game/data/inspiration.lua). Each
-- activity costs prep time and draws extra cards into this week's hand.

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

function M.init(campaign)
    campaign.seeds = { planted = {}, paid = 0, stale = 0, callbacks = 0 }
end

function M.record(campaign, id)
    for _, s in ipairs(campaign.seeds.planted) do
        if s.id == id then
            return s
        end
    end
end

function M.is_fan(p, def)
    for _, a in ipairs(def.fans or {}) do
        if p.primary == a or p.secondary == a then
            return true
        end
    end
    return false
end

-- Seeds still waiting for their payoff.
function M.growing(campaign)
    local list = {}
    for _, s in ipairs(campaign.seeds.planted) do
        if s.state == "growing" then
            table.insert(list, s)
        end
    end
    return list
end

-- This week's seed ideas: a few that have never been planted.
function M.offer(campaign, n)
    local pool = {}
    for _, id in ipairs(content.seeds.order) do
        if not M.record(campaign, id) then
            table.insert(pool, id)
        end
    end
    campaign.rng:shuffle(pool)
    local out = {}
    for i = 1, math.min(n, #pool) do
        out[i] = pool[i]
    end
    return out
end

-- Start of a week: payoff cards for seeds that are ready join the hand; old ones go stale.
-- Returns the seeds that went stale this week.
function M.start_week(campaign, prep)
    local stale = {}
    for _, s in ipairs(campaign.seeds.planted) do
        if s.state == "growing" then
            local age = campaign.week - s.week
            local def = content.seeds[s.id]
            if age > content.seeds.PAYOFF_WEEKS then
                s.state = "stale"
                s.stale_week = campaign.week
                campaign.seeds.stale = campaign.seeds.stale + 1
                table.insert(stale, s)
                for _, p in ipairs(campaign.players) do
                    if M.is_fan(p, def) and not p.on_break then
                        score.add(p, "investment", -2)
                    end
                end
            elseif age >= 1 then
                local c = content.components[def.payoff]
                local list = prep.hand[c.kind]
                local have = false
                for _, h in ipairs(list) do
                    have = have or h.id == c.id
                end
                if not have then
                    table.insert(list, c)
                end
                prep.payoffs[c.id] = s.id
            end
        end
    end
    return stale
end

-- Commit the seed planted in prep, when game night starts.
function M.commit(campaign, prep)
    if prep.planted and not M.record(campaign, prep.planted) then
        table.insert(campaign.seeds.planted, { id = prep.planted, week = campaign.week, state = "growing", hype = 0 })
    end
end

-- A payoff card hit the table. Returns the seed record, or nil if it wasn't waiting.
function M.pay_off(campaign, comp)
    local s = comp.payoff_of and M.record(campaign, comp.payoff_of)
    if not s or s.state ~= "growing" then
        return nil
    end
    s.state = "paid"
    s.paid_week = campaign.week
    campaign.seeds.paid = campaign.seeds.paid + 1
    return s
end

-- Theories in the group chat ---------------------------------------------------------------

M.THEORY_REPLIES = {
    { label = "Ooh, maybe", reply = "encourage" },
    { label = "No comment", reply = "deflect" },
    { label = "Ha, no", reply = "shoot_down" },
}

-- Who theorizes about this seed: the biggest fan who's around.
function M.theorist(campaign, def)
    local best, best_v
    for _, p in ipairs(campaign.players) do
        if not p.on_break then
            local v = 0
            for _, a in ipairs(def.fans or {}) do
                v = v + score.arch(p, a)
            end
            v = v + 0.5 * (score.arch(p, "storyteller") + score.arch(p, "instigator"))
            if not best_v or v > best_v then
                best, best_v = p, v
            end
        end
    end
    return best
end

-- The DM answers a theory in the group chat.
function M.answer_theory(campaign, msg, i)
    if msg.answered then
        return
    end
    local r = M.THEORY_REPLIES[util.clamp(i, 1, #M.THEORY_REPLIES)]
    msg.answered = r.label
    local s = M.record(campaign, msg.seed)
    local p = campaign:player(msg.key)
    if r.reply == "encourage" then
        if s then
            s.hype = (s.hype or 0) + 1
        end
        score.add(p, "investment", 3)
    elseif r.reply == "deflect" then
        score.add(p, "investment", 1)
    else
        if s then
            s.hype = math.max(0, (s.hype or 0) - 1)
        end
        score.add(p, "investment", -2)
    end
    return r
end

-- Inspiration ---------------------------------------------------------------------------------

local function in_hand(prep, id)
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep.hand[kind]) do
            if c.id == id then
                return true
            end
        end
    end
    return false
end

local function has_any(c, tags)
    for _, t in ipairs(c.tags or {}) do
        for _, w in ipairs(tags) do
            if t == w then
                return true
            end
        end
    end
    return false
end

-- Whose backstory the DM rereads: the present player with the lowest Investment.
function M.backstory_target(campaign)
    local best
    for _, p in ipairs(campaign.players) do
        if p.present and (not best or p.investment < best.investment) then
            best = p
        end
    end
    return best
end

-- The canon line a callback card would use, or nil.
function M.callback_line(campaign)
    local used = campaign.seeds.called or {}
    for i = #campaign.canon, 1, -1 do
        local c = campaign.canon[i]
        if not used[c] then
            return c
        end
    end
end

-- Cards from a player's backstory a reread could bring to the hand (the story deck): the
-- thread's cards that are in the deck now but didn't make the hand. Later steps of a thread
-- only open by playing the earlier ones.
function M.backstory_pool(campaign, prep, p)
    local deck = require "game.model.deck"
    local pool = {}
    for _, c in ipairs(deck.cards(campaign)) do
        if c.thread == p.key and not in_hand(prep, c.id) then
            table.insert(pool, c)
        end
    end
    return pool
end

-- Can the DM do this activity right now? Returns ok, why.
function M.can_inspire(campaign, prep, id)
    local a = content.inspiration[id]
    if not a then
        return false, "Unknown activity."
    end
    if prep.inspired_by[id] then
        return false, "Already done this week."
    end
    if prep.inspirations >= content.inspiration.PER_WEEK then
        return false, "That's enough evenings off for one week."
    end
    if prep:left() < a.cost then
        return false, "Not enough prep time left."
    end
    if a.canon and not M.callback_line(campaign) then
        return false, "Nothing's become canon yet."
    end
    if a.thread then
        local p = M.backstory_target(campaign)
        if not p then
            return false, "Nobody's coming this week."
        end
        if #M.backstory_pool(campaign, prep, p) == 0 then
            return false, "Nothing new in " .. p.name .. "'s backstory right now."
        end
    end
    return true
end

-- Draw cards for an activity. Returns the list of cards drawn.
function M.inspire(campaign, prep, id)
    local ok = M.can_inspire(campaign, prep, id)
    if not ok then
        return nil
    end
    local a = content.inspiration[id]
    local rng = campaign.rng
    local drawn = {}
    local function take(c)
        table.insert(prep.hand[c.kind], c)
        prep.inspired[c.id] = id
        table.insert(drawn, c)
    end
    if a.draw then
        -- Fresh cards that fit the activity first, then other fresh ones, then repeats.
        local seen = campaign.inspired_seen or {}
        local pool = {}
        for _, c in ipairs(content.reserve.inspiration or {}) do
            local kind_ok = not a.draw.kinds or util.contains(a.draw.kinds, c.kind)
            local in_deck = require("game.model.deck").entry(campaign, c.id) ~= nil
            if kind_ok and not in_hand(prep, c.id) and not in_deck then
                local rank = (seen[c.id] and 2 or 0) + ((a.draw.tags and not has_any(c, a.draw.tags)) and 1 or 0)
                table.insert(pool, { c = c, rank = rank + rng:next() * 0.5 })
            end
        end
        table.sort(pool, function(x, y)
            return x.rank < y.rank
        end)
        for i = 1, math.min(a.draw.n, #pool) do
            take(pool[i].c)
        end
    end
    if a.thread then
        local p = M.backstory_target(campaign)
        local pool = M.backstory_pool(campaign, prep, p)
        rng:shuffle(pool)
        for i = 1, math.min(a.thread, #pool) do
            take(pool[i])
        end
        prep.backstory_of = p.key
    end
    if a.canon then
        local line = M.callback_line(campaign)
        campaign.seeds.called = campaign.seeds.called or {}
        campaign.seeds.called[line] = true
        campaign.seeds.callbacks = campaign.seeds.callbacks + 1
        local short = line
        if #short > 34 then
            short = string.sub(short, 1, 32) .. "..."
        end
        -- A card made for this campaign: it lives in the campaign (so a save keeps it) and is
        -- registered with the content again when the save is loaded (game/model/save.lua).
        local c = content.register({
            runtime = true,
            id = "callback_" .. util.int(campaign.seeds.callbacks), kind = "complication",
            name = "Callback: " .. short, cost = 1, difficulty = 0, callback = true,
            fits = { "combat", "social", "exploration", "puzzle", "mystery", "downtime", "set_piece" },
            tags = { "heart", "funny" }, meters = { story = 6, social = 3 },
            line = "Twist: remember " .. line .. "? It matters now.",
        })
        campaign.registered = campaign.registered or {}
        table.insert(campaign.registered, c)
        take(c)
    end
    if a.seed then
        prep.extra_ideas = (prep.extra_ideas or 0) + a.seed
        local more = M.offer(campaign, #prep.seed_ideas + a.seed)
        for _, sid in ipairs(more) do
            if not util.contains(prep.seed_ideas, sid) and #prep.seed_ideas < content.seeds.OFFERED + prep.extra_ideas then
                table.insert(prep.seed_ideas, sid)
            end
        end
    end
    prep.inspired_by[id] = drawn
    prep.inspirations = prep.inspirations + 1
    prep.extra = prep.extra + a.cost
    campaign.inspired_seen = campaign.inspired_seen or {}
    for _, c in ipairs(drawn) do
        if c.reserve then
            campaign.inspired_seen[c.id] = true
        end
    end
    return drawn
end

return M
