-- The story deck (the slice rework): each campaign's own deck of scene cards, in place of a
-- fixed pool drawn at random every week. Places and people recur and remember what happened;
-- goals, complications, rewards and clues are spent once they've played, and open follow-up
-- cards by how their scene went (components.lua: deck, recurring, on). Pure Lua.
--
-- campaign.deck = {
--   cards  = { [id] = entry },
--   opened = { { week, id, from, why } },     every card another card opened, in order
-- }
-- entry = { state, since, joined, from, why, plays, last, history = { outcome... }, revealed }
--   state   "waiting" (joins the deck at week `since`), "deck" (in it), "spent" (gone for good),
--           "shelved" (the DM put it aside, S6: never dealt until it's brought back)
--   joined  the week it came into the deck; from/why: the card that opened it, and how that
--           card's scene went ("win", "lose", "played", "escaped"), or "story" for a beat's card
--   history how each scene it played in went, oldest first

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

-- Is this a story card (a reveal still to tell)? game.model.story is required lazily.
local function is_story_card(campaign, c)
    local story = util.lazy("game.model.story")
    return story.pending_reveal(campaign, c) ~= nil
end

M.HAND_CAP = 8        -- cards of a kind in the hand: they all fit on one page
local STRAY = 0.15    -- chance a card from far outside the campaign's style still makes the hand
local OFF_CAP = 2     -- far-off cards in a kind's hand (A18), unless the hand would be thin
M.MIN_PER_KIND = 5    -- below this, a kind tops up from the spare cards

-- Places and people come back; everything else is spent once played. Foes and villains are
-- settled by how the fight went (after_night).
function M.recurring(c)
    if c.recurring ~= nil then
        return c.recurring
    end
    return c.kind == "location" or c.kind == "cast"
end

local function new_deck()
    return { cards = {}, opened = {} }
end

-- The deck, made the first time it's asked for (a new campaign, or a save from before it).
function M.get(campaign)
    if campaign.deck then
        return campaign.deck
    end
    local d = new_deck()
    campaign.deck = d
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(content.by_kind[kind]) do
            if (c.deck or "start") == "start" then
                d.cards[c.id] = { state = "deck", since = 1, joined = 1, plays = 0, history = {} }
            end
        end
    end
    return d
end

function M.entry(campaign, id)
    return M.get(campaign).cards[id]
end

function M.state(campaign, id)
    local e = M.entry(campaign, id)
    return e and e.state or nil
end

function M.is_spent(campaign, id)
    return M.state(campaign, id) == "spent"
end

-- In the deck right now (not waiting, not spent)?
function M.available(campaign, id)
    return M.state(campaign, id) == "deck"
end

-- Has it played before? (A recurring card's second visit uses its "again" line.)
function M.returning(campaign, c)
    local e = c and M.entry(campaign, c.id)
    return e ~= nil and (e.plays or 0) > 0
end

-- Joined the deck this week from somewhere (a follow-up or the story), so the hand marks it new.
function M.is_new(campaign, id)
    local e = M.entry(campaign, id)
    return e ~= nil and e.state == "deck" and e.joined == campaign.week and e.from ~= nil and campaign.week > 1
end

-- The card this one follows from, if another card opened it: card, why.
function M.follows(campaign, id)
    local e = M.entry(campaign, id)
    if e and e.from and content.components[e.from] then
        return content.components[e.from], e.why
    end
    return nil
end

-- A card joins the deck (now, or at week `at`). A spent card never comes back; one that's
-- already in the deck (or on its way) stays as it is. Returns true if it's new to the deck.
function M.add(campaign, id, at, from, why)
    local d = M.get(campaign)
    if not content.components[id] then
        return false
    end
    local e = d.cards[id]
    if e then
        if e.state == "waiting" and at and at < e.since then
            e.since = at
        end
        return false
    end
    at = at or campaign.week
    local now = at <= campaign.week
    d.cards[id] = { state = now and "deck" or "waiting", since = at, joined = now and campaign.week or nil,
                    from = from, why = why, plays = 0, history = {} }
    if from and from ~= "story" then
        table.insert(d.opened, { week = campaign.week, id = id, from = from, why = why })
    end
    return true
end

function M.spend(campaign, id)
    local d = M.get(campaign)
    local e = d.cards[id]
    if not e then
        e = { plays = 0, history = {} }
        d.cards[id] = e
    end
    e.state = "spent"
end

-- Shelving (S6): the DM puts a card aside so it stops coming up. This week's story cards stay.
function M.can_shelve(campaign, id)
    local c = content.components[id]
    if not c or M.state(campaign, id) ~= "deck" then
        return false, "Only a card in the deck can be shelved."
    end
    if is_story_card(campaign, c) then
        return false, "Story cards can't be shelved: the story needs them."
    end
    return true
end

function M.shelve(campaign, id)
    local ok, why = M.can_shelve(campaign, id)
    if not ok then
        return false, why
    end
    local e = M.entry(campaign, id)
    e.state = "shelved"
    e.shelved = campaign.week
    return true
end

function M.unshelve(campaign, id)
    local e = M.entry(campaign, id)
    if not e or e.state ~= "shelved" then
        return false
    end
    e.state = "deck"
    e.shelved = nil
    return true
end

function M.shelved(campaign)
    local out = {}
    for id, e in pairs(M.get(campaign).cards) do
        local c = content.components[id]
        if c and e.state == "shelved" then
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Cards in the deck now, of a kind (or all kinds), in a stable order.
function M.cards(campaign, kind)
    local d = M.get(campaign)
    local out = {}
    for id, e in pairs(d.cards) do
        local c = content.components[id]
        if c and e.state == "deck" and (not kind or c.kind == kind) then
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Start of a week: cards whose time has come join, this week's beat deals its story cards, and
-- a kind that's run short tops up from the spare cards.
function M.start_week(campaign)
    local d = M.get(campaign)
    local week = campaign.week
    local ids = {}
    for id in pairs(d.cards) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local e = d.cards[id]
        if e.state == "waiting" and (e.since or 0) <= week then
            e.state = "deck"
            e.joined = week
        end
    end
    local beat = campaign:arc_beat()
    for _, id in ipairs(beat and beat.cards or {}) do
        M.add(campaign, id, week, "story", "story")
    end
    for _, kind in ipairs(content.kinds) do
        local have = #M.cards(campaign, kind)
        if have < M.MIN_PER_KIND then
            local spare = {}
            for _, c in ipairs(content.by_kind[kind]) do
                if c.deck == "spare" and not d.cards[c.id] then
                    table.insert(spare, c)
                end
            end
            table.sort(spare, function(a, b) return a.id < b.id end)
            campaign.rng:shuffle(spare)
            for i = 1, math.min(M.MIN_PER_KIND - have, #spare) do
                M.add(campaign, spare[i].id, week, nil, nil)
            end
        end
    end
end

local is_story = is_story_card

-- This week's hand from the deck: every kind on one page, story cards first, then cards that
-- just joined, then the rest. Backstory cards of someone who isn't here wait in the deck.
-- A backstory card whose hero is still the one at the table: once a hero falls and their player
-- rolls up someone new, that hero's own story cards leave with them (the story playtest: Pip's
-- debt kept coming up after Pip died). A way back for them is the exception.
function M.thread_live(campaign, c)
    if not c.thread or c.way_back then
        return true
    end
    local p = campaign.player and campaign:player(c.thread)
    return not (p and p.pregen)
end

-- How many of each kind the hand shows: fewer while a small table is starting out (October 15).
function M.hand_cap(campaign)
    if campaign.roster and campaign.roster.kind == "small" then
        local w = campaign.week or 1
        return (w <= 1 and 5) or (w == 2 and 6) or M.HAND_CAP
    end
    return M.HAND_CAP
end

function M.hand(campaign)
    local hand = {}
    local present = {}
    local cap = M.hand_cap(campaign)
    local storylines = util.lazy("game.model.storylines")
    for _, p in ipairs(campaign.players) do
        present[p.key] = p.present and true or false
    end
    local rng = campaign.rng
    for _, kind in ipairs(content.kinds) do
        local list = {}
        for _, c in ipairs(M.cards(campaign, kind)) do
            if (not c.thread or present[c.thread]) and M.thread_live(campaign, c)
                and (is_story(campaign, c) or storylines.card_in_scope(campaign, c)) then
                local e = M.entry(campaign, c.id)
                local rank
                if is_story(campaign, c) then
                    rank = 1
                elseif M.is_new(campaign, c.id) or (c.thread and campaign.plan
                    and util.contains(campaign.plan.threads or {}, c.thread)) then
                    rank = 2                 -- just joined, or a featured backstory (the planner)
                elseif c.thread then
                    rank = 3
                elseif (e.plays or 0) > 0 then
                    rank = 4
                else
                    rank = 5
                end
                -- Within a rank, what suits the campaign's truths leans first.
                local lean = util.lazy("game.model.styles").tilt(campaign, c)   -- the campaign's style (A18)
                local tilt = util.lazy("game.model.planner").tilt(campaign, c) + lean
                -- A card from a style the campaign has left behind waits behind the home style's
                -- and its neighbors' (now and then one still turns up).
                if lean < 0 and rank >= 4 and rng:next() > STRAY then
                    rank = rank + 2
                elseif lean >= 0.45 and rank == 5 and c.styles then
                    rank = 4                 -- the home style's own cards come up like old favorites
                end
                table.insert(list, { c = c, rank = rank, r = rng:next() - tilt, off = lean < 0 and rank >= 4 })
            end
        end
        table.sort(list, function(a, b)
            if a.rank ~= b.rank then
                return a.rank < b.rank
            end
            return a.r < b.r
        end)
        -- Far-off cards fill out a thin hand, but only a couple of them.
        local picked, off = {}, 0
        for _, it in ipairs(list) do
            if #picked >= cap then
                break
            end
            if not it.off or off < OFF_CAP or #picked < 4 then
                table.insert(picked, it.c)
                off = off + (it.off and 1 or 0)
            end
        end
        hand[kind] = picked
    end
    return hand
end

-- How a scene went, for its cards: "win" or "lose" (nil if it never played).
function M.outcome_of(sc)
    if not sc.terrain then
        return nil
    end
    if sc.outcome then
        return sc.outcome
    end
    if sc.result then
        return sc.result.winner == "party" and "win" or "lose"
    end
    return "win"
end

-- After game night: every card that played is spent or comes back (remembering how it went),
-- and opens what it opens. Returns the cards opened tonight, in order: { id, from, why }.
function M.after_night(campaign, night)
    local d = M.get(campaign)
    local week = campaign.week
    local opened = {}
    local function open_list(c, ids, why)
        for _, id in ipairs(ids or {}) do
            if M.add(campaign, id, week + 1, c.id, why) then
                table.insert(opened, { id = id, from = c.id, why = why })
            end
        end
    end
    for _, sc in ipairs(night.scenes or {}) do
        local outcome = M.outcome_of(sc)
        if outcome then
            local kinds = {}
            for kind in pairs(sc.comps) do
                table.insert(kinds, kind)
            end
            table.sort(kinds)
            for _, kind in ipairs(kinds) do
                local c = sc.comps[kind]
                local e = d.cards[c.id]
                if not e then
                    e = { state = "deck", since = week, joined = week, plays = 0, history = {} }
                    d.cards[c.id] = e
                end
                e.plays = (e.plays or 0) + 1
                e.last = week
                local how = outcome
                if (c.villain or c.foe) and sc.escaped and sc.escaped[c.id] then
                    how = "escaped"
                end
                e.history = e.history or {}
                table.insert(e.history, how)
                if night.revealed and night.revealed[c.id] then
                    e.revealed = e.revealed or week
                end
                -- Spent, or back in the deck?
                local keep
                if c.villain then
                    keep = how ~= "win"            -- beaten, they're done; got away, they'll be back
                elseif c.foe then
                    keep = how == "lose"
                elseif c.kind == "reward" then
                    keep = how == "lose"           -- a reward they didn't win is still out there
                else
                    keep = M.recurring(c)
                end
                if keep then
                    if e.state ~= "spent" then
                        e.state = "deck"
                    end
                else
                    e.state = "spent"
                end
                -- What it opens.
                local on = c.on
                if on then
                    open_list(c, on.played, "played")
                    open_list(c, on[how] or (how == "escaped" and on.lose) or nil, how)
                end
            end
        end
    end
    -- Story cards that told their part tonight never tell it again, wherever they were (A5).
    for id in pairs(night.revealed or {}) do
        local e = d.cards[id]
        if e then
            e.revealed = e.revealed or week
        else
            d.cards[id] = { state = "deck", since = week, joined = week, plays = 0, history = {}, revealed = week }
        end
    end
    -- An agenda card (S6) is made for its week: if it didn't play, it's gone (next time the
    -- person comes, they bring whatever fits how they feel then).
    for id, e in pairs(d.cards) do
        local c = content.components[id]
        if c and c.agenda and (e.plays or 0) == 0 and e.state ~= "spent" then
            d.cards[id] = nil
            for i = #(campaign.registered or {}), 1, -1 do
                if campaign.registered[i].id == id then
                    table.remove(campaign.registered, i)
                end
            end
        end
    end
    -- Cards from an evening off that didn't make the board stay in the deck for later.
    local prep = campaign.prep
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep and prep.hand and prep.hand[kind] or {}) do
            if (c.reserve == "inspiration" or c.runtime) and not d.cards[c.id] then
                d.cards[c.id] = { state = "deck", since = week, joined = week, from = "inspiration", why = "inspiration",
                                  plays = 0, history = {} }
            end
        end
    end
    return opened
end

-- Every backstory thread, for the notebook's Threads page: per player key, the thread's cards
-- in order, each { card, state = "done" | "open" | "coming" | "locked", how }.
-- A card no step has opened yet shows as locked (a question mark in the notebook).
function M.threads(campaign)
    local d = M.get(campaign)
    local out = {}
    for _, p in ipairs(campaign.players) do
        local steps = {}
        for _, c in pairs(content.components) do
            if c.thread == p.key and not c.reserve and c.step then
                local e = d.cards[c.id]
                local st
                if not e then
                    st = "locked"
                elseif e.state == "spent" or (e.plays or 0) > 0 then
                    st = "done"
                elseif e.state == "waiting" then
                    st = "coming"
                else
                    st = "open"
                end
                local how = e and e.history and e.history[#e.history] or nil
                table.insert(steps, { card = c, state = st, how = how, step = c.step })
            end
        end
        table.sort(steps, function(a, b)
            if a.step ~= b.step then
                return a.step < b.step
            end
            return a.card.id < b.card.id
        end)
        out[p.key] = steps
    end
    return out
end

-- Did any thread move this week (a thread card opened, or joined the deck)? For the notes'
-- notification dot.
function M.thread_moved(campaign)
    local d = M.get(campaign)
    for id, e in pairs(d.cards) do
        local c = content.components[id]
        if c and c.thread and e.joined == campaign.week and e.from and e.from ~= "story" then
            return true
        end
    end
    return false
end

return M
