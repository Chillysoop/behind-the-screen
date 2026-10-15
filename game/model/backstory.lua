-- Their backstories, at Session Zero (October 13; the data is game/data/backstories.lua): each
-- player pitches their hero's past, the DM asks a few questions (six, all told), answers the
-- player's own idea, and chooses what from that past turns up first. Session Zero writes it into
-- the campaign: the answers become facts in the hero's Story log, the chosen card joins the deck
-- for week 1 and waits at the front of the first hand, and how it went adds to how each player
-- leaves Session Zero. Pure Lua.
--
-- The screen's choices: { [player key] = { asked = { question ids, in order }, idea = "yes" |
-- "no", hook = card id } }.
-- campaign.backstories = { [player key] = { char, asked, idea, hook, hook_text, facts = { ... } } }

local content = require "game.model.content"

local M = {}
M.data = content.backstories

local function find(list, field, value)
    for _, it in ipairs(list or {}) do
        if it[field] == value then
            return it
        end
    end
    return nil
end

function M.question(key, qid)
    return find((M.data[key] or {}).questions, "id", qid)
end

function M.hook_of(key, card)
    return find((M.data[key] or {}).hooks, "card", card)
end

-- Questions asked so far across the table, and how many are left.
function M.asked(all)
    local n = 0
    for _, ch in pairs(all or {}) do
        n = n + #(ch.asked or {})
    end
    return n
end

function M.left(all, budget)
    return math.max(0, (budget or M.data.QUESTIONS) - M.asked(all))
end

-- Ask a question (or take it back). Returns true if it changed. budget: the questions there's
-- time for (Session Zero's six, or a joining player's own three).
function M.toggle_question(all, key, qid, budget)
    all[key] = all[key] or { asked = {} }
    local ch = all[key]
    ch.asked = ch.asked or {}
    for i, id in ipairs(ch.asked) do
        if id == qid then
            table.remove(ch.asked, i)
            return true
        end
    end
    if M.left(all, budget) <= 0 or not M.question(key, qid) then
        return false
    end
    table.insert(ch.asked, qid)
    return true
end

-- How a player feels about what was asked, said and chosen: -n..n, like Session Zero's asks.
-- Past their `tires`, every question is one too many.
function M.like(key, ch)
    local d = M.data[key]
    if not (d and ch) then
        return 0
    end
    local total = 0
    for i, qid in ipairs(ch.asked or {}) do
        local q = M.question(key, qid)
        total = total + (q and q.like or 0)
        if i > (d.tires or 3) then
            total = total - 1
        end
    end
    if ch.idea and d.idea and d.idea[ch.idea] then
        total = total + (d.idea[ch.idea].like or 0)
    end
    local h = ch.hook and M.hook_of(key, ch.hook)
    if h then
        total = total + (h.like or 0)
    end
    return total
end

-- Every hero's past has something written in to turn up first.
function M.complete(all, players)
    for _, key in ipairs(players or content.players.order) do
        if M.data[key] and not (all and all[key] and all[key].hook) then
            return false
        end
    end
    return true
end

-- What you wrote, as the Story log tells it: the facts in the order they came out.
local function facts_of(key, ch)
    local d = M.data[key]
    local out = {}
    for _, qid in ipairs(ch.asked or {}) do
        local q = M.question(key, qid)
        if q then
            table.insert(out, q.fact)
        end
    end
    if ch.idea == "yes" and d.idea and d.idea.yes and d.idea.yes.fact then
        table.insert(out, d.idea.yes.fact)
    end
    return out
end

-- Session Zero settles (social.apply_session_zero): write it into the campaign.
function M.settle(campaign, all)
    if not all then
        return
    end
    local deck = require "game.model.deck"
    campaign.backstories = {}
    for _, p in ipairs(campaign.players or {}) do
        local ch = all[p.key]
        if ch and M.data[p.key] then
            local h = ch.hook and M.hook_of(p.key, ch.hook)
            local asked = {}
            for i, id in ipairs(ch.asked or {}) do
                asked[i] = id
            end
            campaign.backstories[p.key] = { char = p.char, asked = asked, idea = ch.idea, hook = h and h.card or nil,
                                            hook_text = h and h.text or nil, facts = facts_of(p.key, ch) }
            if h then
                -- It turns up first: in the deck for week 1, at the front of the first hand.
                deck.add(campaign, h.card, 1, "session_zero", "backstory")
            end
        end
    end
end

-- One hero's past, written in on its own: a player joining a small table (October 15), or the
-- defaults when nobody chose. Replaces what was there; the hook joins the deck this week.
function M.settle_one(campaign, key, ch)
    local p = campaign:player(key)
    if not (p and ch and M.data[key]) then
        return
    end
    local deck = require "game.model.deck"
    campaign.backstories = campaign.backstories or {}
    local h = ch.hook and M.hook_of(key, ch.hook)
    local asked = {}
    for i, id in ipairs(ch.asked or {}) do
        asked[i] = id
    end
    campaign.backstories[key] = { char = p.char, asked = asked, idea = ch.idea, hook = h and h.card or nil,
                                  hook_text = h and h.text or nil, facts = facts_of(key, ch), joined = campaign.week }
    if h then
        deck.add(campaign, h.card, math.max(1, campaign.week), "session_zero", "backstory")
    end
end

-- What a hero's page says when nobody wrote it: the questions they enjoy, a yes to their idea,
-- and the first thing that could turn up.
function M.default_choice(key)
    local d = M.data[key]
    if not d then
        return nil
    end
    local asked = {}
    for i, q in ipairs(d.questions or {}) do
        if i <= math.min(2, d.tires or 2) then
            table.insert(asked, q.id)
        end
    end
    return { asked = asked, idea = "yes", hook = d.hooks and d.hooks[1] and d.hooks[1].card or nil }
end

-- What was written for a hero, if it's still that hero (a new character starts their own story).
function M.written(campaign, key, char)
    local b = campaign.backstories and campaign.backstories[key]
    if not b then
        return nil
    end
    if char and b.char ~= char then
        return nil
    end
    return b
end

-- The first prep after Session Zero: each hero's hook waits at the front of the hand.
function M.start_week(campaign, prep)
    if not campaign.backstories then
        return
    end
    -- Each hero's hook is pinned once: week 1 for Session Zero's, the week they join for a player
    -- who joins later (October 15). (Saves from before kept one flag for everyone.)
    local old_flag = campaign.backstories_dealt
    campaign.backstories_dealt = campaign.backstories_dealt or campaign.week
    local deck = require "game.model.deck"
    for _, p in ipairs(campaign.players or {}) do
        local b = M.written(campaign, p.key, p.char)
        local due = b and not b.dealt and not (old_flag and not b.joined)
        local c = due and b.hook and content.components[b.hook]
        if due then
            b.dealt = campaign.week
        end
        if c and p.present and deck.available(campaign, c.id) and not prep:pinned(c.id) then
            local when = b.joined and b.joined > 1 and "When they joined" or "Session Zero"
            prep:pin(c.id, "backstory", when .. ": you wrote this into " .. p.char .. "'s past.", { key = p.key })
        end
    end
end

-- What you wrote for a hero, for the Story log and its hovers: the facts as they came out, then
-- what turns up first.
function M.lines(campaign, key, char)
    local b = M.written(campaign, key, char)
    if not b then
        return nil
    end
    local out = {}
    for _, f in ipairs(b.facts or {}) do
        table.insert(out, f)
    end
    if b.hook_text then
        table.insert(out, b.hook_text)
    end
    return out
end

return M
