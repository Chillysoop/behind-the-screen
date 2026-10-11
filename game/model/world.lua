-- The world turns (the slice rework, S7): what the factions do off screen between sessions.
-- Each week every faction proposes a move (game/data/factions.lua). The DM lets it happen (a
-- fortune roll behind the screen: tier d6s, keep the highest; 6 works, 4 or 5 half works,
-- 1 to 3 goes badly), brings it on screen as a card in the hand (the party's scene decides
-- it), or holds it for a week. Moves the DM never got to play out at the start of the next
-- week. Results go to the timeline, the deck, people and places, and the group chat.
-- Pure Lua.
--
-- campaign.world = {
--   week     the week the proposals are for
--   moves    { { faction, move, state = "pending" | "let" | "screen" | "held", result, dice, text, cards } }
--   held     { [faction] = move id }    held last week: proposed again first
--   holds    holds used this week
--   timeline { { week, faction, move, name, result, text, know, cards, via = "roll" | "screen" | "auto" | "project", dice } }
--   news     rumours waiting for the next group chat: { { text, faction } }
--   done     { ["faction:move"] = week } for once-only moves
-- }

local content = require "game.model.content"
local util = require "game.model.util"
local deck = require "game.model.deck"
local ledger = require "game.model.ledger"

local data = require "game.data.factions"

local M = {}
M.data = data

function M.get(campaign)
    local w = campaign.world
    if not w then
        w = { week = 0, moves = {}, held = {}, holds = 0, timeline = {}, news = {}, done = {} }
        campaign.world = w
    end
    return w
end

local function move_def(fid, id)
    for _, mv in ipairs(data[fid].moves) do
        if mv.id == id then
            return mv
        end
    end
end
M.move_def = move_def

-- Is this faction the planner's front (its portents are its project)?
function M.is_front(campaign, fid)
    local fd = data[fid]
    if not fd.front then
        return false
    end
    if fd.front == "kessrick" then
        return true
    end
    return campaign.plan ~= nil and campaign.plan.front == fd.front
end

-- A faction's project, if it has a clock of its own right now: { name, size, clock, done }.
function M.project(campaign, fid)
    local fd = data[fid]
    if not fd.project or M.is_front(campaign, fid) then
        return nil
    end
    local f = ledger.get(campaign).factions[fid]
    return { name = fd.project.name, size = fd.project.size, clock = f.clock or 0, done = f.done }
end

-- Can a card join the deck for the world? Not a person who's gone, nothing spent or shelved.
local function can_add(campaign, id)
    local c = content.components[id]
    if not c then
        return false
    end
    local st = deck.state(campaign, id)
    if st == "spent" or st == "shelved" then
        return false
    end
    if c.kind == "cast" then
        local pid = ledger.person_of(c)
        if pid and not ledger.around(campaign, pid) then
            return false
        end
    end
    return true
end
M.can_add = can_add

-- Does a move's condition hold this week?
function M.allowed(campaign, fid, mv)
    local w = M.get(campaign)
    local when = mv.when or {}
    local week = campaign.week
    local nbf = ledger.get(campaign).factions[fid]
    if mv.project then
        local pr = M.project(campaign, fid)
        if not pr or pr.done then
            return false
        end
    end
    if when.crossed and not (nbf.crossed and nbf.crossed >= week - 2) then
        return false
    end
    local standing = ledger.standing(campaign, fid)
    if when.min_standing and standing < when.min_standing then
        return false
    end
    if when.max_standing and standing > when.max_standing then
        return false
    end
    if when.week and week < when.week then
        return false
    end
    if when.present then
        local p = campaign:player(when.present)
        if not (p and p.present) then
            return false
        end
    end
    if when.needs and not deck.available(campaign, when.needs) then
        return false
    end
    if when.lacks and (deck.state(campaign, when.lacks) ~= nil or not content.components[when.lacks]) then
        return false
    end
    if when.member and not ledger.around(campaign, when.member) then
        return false
    end
    if when.not_front and M.is_front(campaign, fid) then
        return false
    end
    if when.once and w.done[fid .. ":" .. mv.id] then
        return false
    end
    return true
end

-- The card a move becomes on screen, if it can come into the hand this week.
function M.screen_card(campaign, fid, mv)
    local id = mv.screen
    if not id or not can_add(campaign, id) then
        return nil
    end
    return content.components[id]
end

-- Each faction's likeliest move this week (a held move comes back first).
function M.propose(campaign)
    local w = M.get(campaign)
    local rng = campaign.rng
    w.week = campaign.week
    w.moves = {}
    w.holds = 0
    for _, fid in ipairs(data.order) do
        local pick
        local held = w.held[fid] and move_def(fid, w.held[fid])
        if held and M.allowed(campaign, fid, held) then
            pick = held
        end
        if not pick then
            local list, weights = {}, {}
            for _, mv in ipairs(data[fid].moves) do
                if M.allowed(campaign, fid, mv) then
                    table.insert(list, mv)
                    -- A faction the party crossed strikes back first; a project close to done pushes on.
                    local wgt = mv.weight or 1
                    if mv.when and mv.when.crossed then
                        wgt = wgt * 2
                    end
                    table.insert(weights, wgt)
                end
            end
            pick = #list > 0 and rng:weighted(list, weights) or nil
        end
        if pick then
            table.insert(w.moves, { faction = fid, move = pick.id, state = "pending", was_held = held ~= nil and pick == held })
        end
    end
    w.held = {}
    return w.moves
end

-- Fortune: tier d6s, keep the highest.
function M.fortune(campaign, fid)
    local n = data[fid].tier or 1
    local dice, best = {}, 0
    for i = 1, n do
        dice[i] = campaign.rng:int(1, 6)
        best = math.max(best, dice[i])
    end
    local result = best == 6 and "full" or (best >= 4 and "half" or "bad")
    return result, dice
end

-- Post a rumour to the group chat (you post it; a player answers).
function M.post(campaign, text, fid, msgs)
    msgs = msgs or campaign.chat
    if not msgs or not text then
        return
    end
    table.insert(msgs, { who = "You", key = "dm", text = text, world = fid })
    local rng = campaign.rng
    local here = {}
    for _, p in ipairs(campaign.players) do
        if not p.on_break then
            table.insert(here, p)
        end
    end
    -- Whoever's thread it touches answers; anyone else, in their own voice.
    local by = data.reactions[fid] or {}
    local who
    for _, p in ipairs(here) do
        if by[p.key] then
            who = p
        end
    end
    local lines = who and by[who.key]
    if not who then
        who = rng:pick(here)
        lines = who and data.reactions.any[who.key]
    end
    if who and lines then
        table.insert(msgs, { who = who.name, key = who.key, text = rng:pick(lines), world = fid })
    end
end

local function add_card(campaign, id, fid, result, out)
    if not can_add(campaign, id) then
        return
    end
    if deck.state(campaign, id) == "deck" then
        return
    end
    if deck.add(campaign, id, campaign.week, "world:" .. fid, result) then
        table.insert(out, id)
        -- Mid-prep, the card goes straight into this week's hand.
        local prep = M.get(campaign).posting_now and campaign.prep
        if prep and prep.take_new then
            prep:take_new(content.components[id])
        end
    end
end

-- Do what a result says. Returns the cards it added.
function M.apply_fx(campaign, fid, fx, text, result)
    fx = fx or {}
    local cards = {}
    local nb = ledger.get(campaign)
    for _, id in ipairs(fx.add or {}) do
        add_card(campaign, id, fid, result, cards)
    end
    for pid, d in pairs(fx.att or {}) do
        ledger.adjust(campaign, pid, d, text)
    end
    for pid, st in pairs(fx.status or {}) do
        ledger.set_status(campaign, pid, st, text)
    end
    for lid, st in pairs(fx.place or {}) do
        ledger.set_place(campaign, lid, st)
    end
    for pid, to in pairs(fx.join or {}) do
        local p = nb.people[pid]
        if p then
            p.faction = to
        end
    end
    if fx.standing then
        ledger.shift(campaign, fid, fx.standing, text)
    end
    if fx.spend_goal then
        -- A rival gets to one of the party's open jobs first.
        local story = require "game.model.story"
        local prep = M.get(campaign).posting_now and campaign.prep or nil
        local best
        for _, c in ipairs(deck.cards(campaign, "goal")) do
            local e = deck.entry(campaign, c.id)
            if not c.thread and not c.reserve and (c.deck or "start") ~= "arc" and not story.pending_reveal(campaign, c)
                and not (prep and prep.placed_at and prep:placed_at(c.id)) and not (prep and prep.pins and prep.pins[c.id])
                and (e.plays or 0) == 0 then
                best = best or c
            end
        end
        if best then
            deck.spend(campaign, best.id)
            if prep and prep.drop_from_hand then
                prep:drop_from_hand(best.id)
            end
            cards.spent = best.id
        end
    end
    if fx.clock then
        local pr = M.project(campaign, fid)
        if pr and not pr.done then
            local f = nb.factions[fid]
            f.clock = util.clamp((f.clock or 0) + fx.clock, 0, pr.size)
            if f.clock >= pr.size then
                M.complete(campaign, fid)
            end
        end
    end
    return cards
end

local function record(campaign, entry)
    local w = M.get(campaign)
    entry.week = campaign.week
    table.insert(w.timeline, entry)
    return entry
end

-- A project's clock filled: the world changes for good.
function M.complete(campaign, fid)
    local fd = data[fid]
    local f = ledger.get(campaign).factions[fid]
    if f.done then
        return
    end
    f.done = campaign.week
    local d = fd.project.done
    local cards = M.apply_fx(campaign, fid, d.fx, d.text, "done")
    record(campaign, { faction = fid, move = "project", name = fd.project.name, result = "done", text = d.text,
                       know = d.know, cards = cards, via = "project" })
    if d.know ~= "secret" and d.rumour then
        M.queue_or_post(campaign, d.rumour, fid)
    end
end

-- A rumour now (the DM's deciding during prep) or with next week's chat (it happened between weeks).
function M.queue_or_post(campaign, text, fid)
    local w = M.get(campaign)
    if w.posting_now then
        M.post(campaign, text, fid)
    else
        table.insert(w.news, { text = text, faction = fid })
    end
end

-- Play a move's result. via: "roll", "screen" or "auto".
function M.resolve(campaign, m, result, via, dice)
    local fid = m.faction
    local mv = move_def(fid, m.move)
    local res = mv.results[result]
    local w = M.get(campaign)
    m.result, m.dice = result, dice
    local text = res.text
    if via == "screen" then
        text = (result == "bad" and "On the table, the party stopped it: " or "On the table, it happened anyway: ") .. text
    end
    m.text = text
    local cards = M.apply_fx(campaign, fid, res.fx, text, result)
    if cards.spent then
        local c = content.components[cards.spent]
        text = text .. " (" .. (c and c.name or cards.spent) .. " is gone.)"
        m.text = text
    end
    m.cards = cards
    if mv.when and mv.when.once then
        w.done[fid .. ":" .. mv.id] = campaign.week
    end
    record(campaign, { faction = fid, move = mv.id, name = mv.name, result = result, text = text, know = res.know,
                       cards = cards, via = via, dice = dice })
    if res.know ~= "secret" and res.rumour then
        M.queue_or_post(campaign, res.rumour, fid)
    end
    return m
end

-- The DM's call on a proposed move: "let" (roll for it now), "screen" (into the hand as a
-- card), "hold" (next week), or "undo" (back to undecided, from screen or hold).
-- Returns true, or false and why not.
function M.decide(campaign, i, choice)
    local w = M.get(campaign)
    local m = w.moves[i]
    if not m or w.week ~= campaign.week then
        return false, "That move isn't this week's."
    end
    local mv = move_def(m.faction, m.move)
    local prep = campaign.prep
    if choice == "let" then
        if m.state ~= "pending" then
            return false, "You've already decided that one."
        end
        local result, dice = M.fortune(campaign, m.faction)
        m.state = "let"
        w.posting_now = true
        M.resolve(campaign, m, result, "roll", dice)
        w.posting_now = false
        return true
    elseif choice == "screen" then
        if m.state ~= "pending" then
            return false, "You've already decided that one."
        end
        for _, o in ipairs(w.moves) do
            if o.state == "screen" then
                return false, "One move on screen a week: you've chosen " .. data[o.faction].name .. "'s."
            end
        end
        local c = M.screen_card(campaign, m.faction, mv)
        if not c then
            return false, "There's no card for that this week."
        end
        if deck.state(campaign, c.id) == nil or deck.state(campaign, c.id) == "waiting" then
            deck.add(campaign, c.id, campaign.week, "world:" .. m.faction, "screen")
            local e = deck.entry(campaign, c.id)
            e.state, e.joined = "deck", campaign.week
        end
        m.state = "screen"
        m.card = c.id
        if prep and prep.pin then
            prep:pin(c.id, "screen", data[m.faction].name .. ": " .. mv.name)
        end
        return true
    elseif choice == "hold" then
        if m.state ~= "pending" then
            return false, "You've already decided that one."
        end
        if w.holds >= data.HOLDS then
            return false, "One hold a week."
        end
        w.holds = w.holds + 1
        m.state = "held"
        return true
    elseif choice == "undo" then
        if m.state == "screen" then
            if prep and prep.unpin then
                prep:unpin(m.card)
            end
            m.state, m.card = "pending", nil
            return true
        elseif m.state == "held" then
            w.holds = w.holds - 1
            m.state = "pending"
            return true
        end
        return false, "The dice are rolled."
    end
    return false, "?"
end

-- Moves still waiting on the DM this week (the notes' dot and the Run game night check).
function M.pending(campaign)
    local w = M.get(campaign)
    if w.week ~= campaign.week then
        return 0
    end
    local n = 0
    for _, m in ipairs(w.moves) do
        if m.state == "pending" then
            n = n + 1
        end
    end
    return n
end

-- Start of a week: last week's undecided moves play out (and on-screen moves whose card never
-- made it to the table), held moves wait to be proposed again, and this week's are proposed.
function M.start_week(campaign)
    local w = M.get(campaign)
    if w.week > 0 and w.week < campaign.week then
        for _, m in ipairs(w.moves) do
            if m.state == "pending" or (m.state == "screen" and not m.settled) then
                local result, dice = M.fortune(campaign, m.faction)
                M.resolve(campaign, m, result, "auto", dice)
                m.state = "let"
            elseif m.state == "held" then
                w.held[m.faction] = m.move
            end
        end
    end
    return M.propose(campaign)
end

-- After game night: an on-screen move is settled by its scene (won: it goes badly for the
-- faction; lost: it works). Then pushback and help: a won scene against a faction's cards
-- takes a segment off its project; a won goal that helps it adds one.
function M.after_night(campaign, night)
    local w = M.get(campaign)
    local nb = ledger.get(campaign)
    for _, m in ipairs(w.moves) do
        if m.state == "screen" and not m.settled and m.card then
            for _, sc in ipairs(night.scenes or {}) do
                local played = false
                for _, c in pairs(sc.comps) do
                    played = played or c.id == m.card
                end
                local outcome = played and deck.outcome_of(sc)
                if outcome then
                    m.settled = true
                    M.resolve(campaign, m, outcome == "win" and "bad" or "full", "screen")
                    break
                end
            end
        end
    end
    for _, fid in ipairs(data.order) do
        local f = nb.factions[fid]
        local pr = M.project(campaign, fid)
        if pr and not pr.done then
            if f.pushed == campaign.week then
                f.clock = math.max(0, (f.clock or 0) - 1)
                record(campaign, { faction = fid, move = "pushback", name = pr.name, result = "pushed",
                                   text = "The party set " .. data[fid].short .. " back: " .. string.lower(pr.name) .. " lost a step.",
                                   know = "secret", cards = {}, via = "scene" })
            end
            if f.helped == campaign.week then
                f.clock = math.min(pr.size, (f.clock or 0) + 1)
                ledger.shift(campaign, fid, 1, "The party helped " .. data[fid].short .. ".")
                record(campaign, { faction = fid, move = "helped", name = pr.name, result = "helped",
                                   text = "The party helped " .. data[fid].short .. ": " .. string.lower(pr.name) .. " moved on a step.",
                                   know = "public", cards = {}, via = "scene" })
                if f.clock >= pr.size then
                    M.complete(campaign, fid)
                end
            end
        end
    end
end

-- The rumours waiting for this week's group chat (written at the start of the week).
function M.post_news(campaign, msgs)
    local w = M.get(campaign)
    for _, n in ipairs(w.news) do
        M.post(campaign, n.text, n.faction, msgs)
    end
    w.news = {}
end

-- The timeline for a faction (or everyone), newest first.
function M.timeline(campaign, fid)
    local out = {}
    local tl = M.get(campaign).timeline
    for i = #tl, 1, -1 do
        if not fid or tl[i].faction == fid then
            table.insert(out, tl[i])
        end
    end
    return out
end

return M
