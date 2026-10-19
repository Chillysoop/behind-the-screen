-- Pulls and skews (the rebuild's second milestone, October 18). Every player has a hidden pull on
-- what's in play: their hero's own story, the storylines they care about going quiet, a theory
-- they're sure of, a place that's exactly what they come to the table for, or somewhere nobody
-- prepped. Now and then, at most once a stop, one of them pulls the table toward it, and the DM
-- answers with one of four calls: follow it, weave it in, park it or steer back. Each call sticks.
--
-- Who pulls leans toward whoever has had the least say: each player has a hidden share of who
-- moved the story, kept over the slice, so the quiet player gets pulled in. You never see the
-- numbers; the report shows the share as fills after the night.
--
-- This replaces the old wander-off, split-the-party and quantum-ogre cards (campaign.old_night
-- brings them back, for comparison). Data: game/data/skews.lua. Pure Lua.
--
-- campaign.pulls = {
--   share = { [key] = { total = n, weeks = { [week] = n } } }   who moved the story
--   owed  = { { key, kind, id, name, place, story, week, due, state = "owed" | "paid" | "sour",
--               reminded } }                                     parked pulls
--   log   = { { week, stop, key, kind, id, name, why, answer, tie } }   every pull and your call
-- }

local data = require "game.data.skews"
local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"

local function storylines_mod()
    return require "game.model.storylines"
end
local function valley_mod()
    return require "game.model.valley"
end
local function places_mod()
    return require "game.model.places"
end
local function seeds_mod()
    return require "game.model.seeds"
end

local M = {}
M.data = data
M.ORDER = { "follow", "weave", "park", "steer" }

function M.get(campaign)
    campaign.pulls = campaign.pulls or {}
    local g = campaign.pulls
    g.share = g.share or {}
    g.owed = g.owed or {}
    g.log = g.log or {}
    return g
end

-- Skews are on unless a campaign asks for the old night (the comparison switch).
function M.enabled(campaign)
    return not campaign.old_night
end

-- The share ---------------------------------------------------------------------------------

function M.credit(campaign, key, n, week)
    if not key or not n or n == 0 then
        return
    end
    local g = M.get(campaign)
    local s = g.share[key] or { total = 0, weeks = {} }
    g.share[key] = s
    s.total = s.total + n
    week = week or campaign.week or 1
    s.weeks[week] = (s.weeks[week] or 0) + n
end

-- A player's share: over the campaign so far, and this week.
function M.share(campaign, key)
    local s = M.get(campaign).share[key]
    if not s then
        return 0, 0
    end
    return s.total, s.weeks[campaign.week or 1] or 0
end

-- Everyone's share as fills (0 to 1, the biggest share full), for the report.
function M.fills(campaign, players, week)
    local out, top = {}, 0
    for _, p in ipairs(players) do
        local s = M.get(campaign).share[p.key]
        local v = s and (week and (s.weeks[week] or 0) or s.total) or 0
        out[p.key] = v
        top = math.max(top, v)
    end
    for k, v in pairs(out) do
        out[k] = top > 0 and v / top or 0
    end
    return out
end

-- Words -------------------------------------------------------------------------------------

local function soft(name)
    return util.lower_first(name or "")
end

local function name_of(c)
    return soft(c.short or c.name)
end

local function fill(text, v)
    text = util.fill(text, v)
    return util.sentence_case(text)
end

-- The words for one pull: what they pull toward, and why.
local function vars(night, p, t, extra)
    local v = { name = p.name, Name = p.name, char = p.char, Char = p.char, target = t.name,
                Target = util.capitalize(t.name) }
    if t.story then
        local d = storylines_mod().def(night.campaign, t.story)
        v.story = d and soft(d.short or d.name) or "that story"
        v.Story = util.capitalize(v.story)
    end
    if t.theory then
        local cl = seeds_mod().claim(t.theory)
        v.claim = cl and cl.says or ""
    end
    if t.taste then
        v.taste = string.lower(content.scenes[t.taste] and content.scenes[t.taste].name or t.taste)
    end
    for k, x in pairs(extra or {}) do
        v[k] = x
    end
    return v
end

-- What's in play ----------------------------------------------------------------------------

-- Tonight's route places and the cards on it.
local function tonight(night)
    local route, placed = {}, {}
    for _, sc in ipairs(night.scenes or {}) do
        for _, c in pairs(sc.comps or {}) do
            placed[c.id] = true
            if c.kind == "location" then
                route[c.id] = true
            end
        end
        for _, id in ipairs(sc.spots or {}) do
            route[id] = true
        end
    end
    return route, placed
end

local function owed_ids(campaign)
    local out = {}
    for _, o in ipairs(M.get(campaign).owed) do
        if o.state == "owed" then
            out[o.id] = true
        end
    end
    return out
end

-- Every target that pulls at this player now, strongest first. A target:
--   { kind = "own" | "story" | "theory" | "taste" | "offmap", id, name, card, place, story, theory,
--     taste, weight }
function M.targets(night, p, sc)
    local campaign = night.campaign
    local prep = night.prep
    local sl = storylines_mod()
    local valley = valley_mod()
    local route, placed = tonight(night)
    local owed = owed_ids(campaign)
    local pulled = night.pulled_ids or {}
    local out, seen = {}, {}
    local function add(t)
        if not t.id or seen[t.id] or pulled[t.id] or owed[t.id] then
            return
        end
        if t.card and (placed[t.card.id] or night:muted(t.card)) then
            return
        end
        if t.place and route[t.place.id] then
            return
        end
        seen[t.id] = true
        t.name = t.name or name_of(t.card or t.place)
        table.insert(out, t)
    end
    local vis = valley.visible(campaign, prep)
    local vis_ids = {}
    for id in pairs(vis) do
        table.insert(vis_ids, id)
    end
    table.sort(vis_ids)
    -- Their hero's own story: a card of theirs in the hand, or a place on the map that's theirs.
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep and prep.hand and prep.hand[kind] or {}) do
            if c.thread == p.key then
                local home = c.kind == "location" and c or content.tied_place(c)
                if c.kind == "complication" then
                    -- (Nobody pulls toward a complication: toward where it happens, if anywhere.)
                    if home then
                        add({ kind = "own", id = home.id, place = home, weight = data.WEIGHT.own * 0.9 })
                    end
                else
                    add({ kind = "own", id = c.id, card = c, place = home, weight = data.WEIGHT.own })
                end
            end
        end
    end
    for _, id in ipairs(vis_ids) do
        if util.contains(valley.storylines_at(campaign, prep, id), "bs_" .. p.key) then
            local c = content.components[id]
            add({ kind = "own", id = id, place = c, weight = data.WEIGHT.own * 0.9 })
        end
    end
    -- A storyline they care about, going quiet: a place on the map where it is.
    for _, d in ipairs(sl.defs(campaign)) do
        local h = sl.heat(campaign, d.id)
        if (h == "cooling" or h == "cold" or h == "loose") and not (night.story_moved or {})[d.id] then
            local rate = 0
            for _, cr in ipairs(sl.carers(campaign, d)) do
                if cr.p.key == p.key then
                    rate = cr.rate
                end
            end
            if rate > 0 then
                for _, id in ipairs(vis_ids) do
                    if util.contains(valley.storylines_at(campaign, prep, id), d.id) then
                        add({ kind = "story", id = id, place = content.components[id], story = d.id,
                              weight = data.WEIGHT.story * rate * (h == "cooling" and 0.8 or 1) })
                    end
                end
            end
        end
    end
    -- A theory they're sure of (and that can still come true).
    for _, th in ipairs(seeds_mod().pinned(campaign)) do
        if th.key == p.key and seeds_mod().can_steal(campaign, th) then
            local s = content.seeds[th.seed]
            add({ kind = "theory", id = "theory_" .. th.seed, theory = th, name = s and soft(s.name) or "their theory",
                  owner = p.name, weight = data.WEIGHT.theory })
        end
    end
    -- A place on the map that's exactly what they come to the table for.
    for _, id in ipairs(vis_ids) do
        local c = content.components[id]
        local best, best_t = 0, nil
        for _, t in ipairs(c.fits or {}) do
            local v = score.taste(p, t)
            if v > best and t ~= (sc and sc.type) then
                best, best_t = v, t
            end
        end
        if best >= 1.25 then
            add({ kind = "taste", id = id, place = c, taste = best_t, weight = data.WEIGHT.taste * best })
        end
    end
    -- Somewhere nobody prepped: off the map.
    local off = {}
    for id, c in pairs(content.components) do
        if c.kind == "location" and not vis[id] and not valley.hub_of(id) and not route[id] then
            local best = 0
            for _, t in ipairs(c.fits or {}) do
                best = math.max(best, score.taste(p, t))
            end
            if best >= 1.25 then
                table.insert(off, id)
            end
        end
    end
    table.sort(off)
    if #off > 0 then
        local id = off[night.rng:int(1, #off)]
        add({ kind = "offmap", id = id, place = content.components[id], weight = data.WEIGHT.offmap })
    end
    table.sort(out, function(a, b)
        if a.weight ~= b.weight then
            return a.weight > b.weight
        end
        return a.id < b.id
    end)
    return out
end

-- How readily this player pulls the table off the plan.
local function propensity(p)
    local a = data.PROPENSITY[p.primary] or 1
    local b = data.PROPENSITY[p.secondary] or a
    return (2 * a + b) / 3 * (p.shy and 0.5 or 1)
end

-- Who pulls now, and toward what: the strongest pull, leaning toward whoever has had the least
-- say in the story. Nil when nobody has one.
function M.choose(night, sc)
    local campaign = night.campaign
    local low
    for _, p in ipairs(night.players) do
        local s = M.share(campaign, p.key)
        low = math.min(low or s, s)
    end
    local cands, weights = {}, {}
    for _, p in ipairs(night.players) do
        if not (night.pulled_by or {})[p.key] then
            local ts = M.targets(night, p, sc)
            if ts[1] then
                -- What they pull toward: the strongest pull most often, the others now and then.
                local pick, tw = ts[1], 0
                for k, t in ipairs(ts) do
                    if k <= 3 then
                        tw = tw + t.weight * t.weight
                    end
                end
                local r = night.rng:next() * tw
                for k, t in ipairs(ts) do
                    r = r - (k <= 3 and t.weight * t.weight or 0)
                    if r <= 0 then
                        pick = t
                        break
                    end
                end
                local s = M.share(campaign, p.key)
                -- Mostly whoever has had the least say; the player this session is for still leads.
                local w = propensity(p) * pick.weight / (1 + math.max(0, s - (low or 0)))
                if night.prep and night.prep.spot == p.key then
                    w = w * 1.5
                end
                table.insert(cands, { p = p, t = pick })
                table.insert(weights, w)
            end
        end
    end
    if #cands == 0 then
        return nil
    end
    local total = 0
    for _, w in ipairs(weights) do
        total = total + w
    end
    local r = night.rng:next() * total
    for i, w in ipairs(weights) do
        r = r - w
        if r <= 0 then
            return cands[i].p, cands[i].t
        end
    end
    return cands[#cands].p, cands[#cands].t
end

-- What ties a pull to this stop, so the DM can weave it in: a storyline they share, two cards
-- that go together, the same place or town, or a theory that can come true. Returns the words
-- for the tie and the stop's storyline it links to, or nil.
function M.tie(night, sc, t)
    local campaign = night.campaign
    local sl = storylines_mod()
    local valley = valley_mod()
    if t.kind == "theory" then
        return "making " .. (t.owner or "their") .. "'s theory true", nil
    end
    local stop_ids, stop_set = {}, {}
    for _, c in util.sorted_pairs(sc.comps or {}) do
        if not night:muted(c) then
            for _, id in ipairs(sl.of_card(campaign, c)) do
                if not stop_set[id] then
                    stop_set[id] = true
                    table.insert(stop_ids, id)
                end
            end
        end
    end
    local t_ids = {}
    if t.story then
        table.insert(t_ids, t.story)
    end
    if t.card then
        for _, id in ipairs(sl.of_card(campaign, t.card)) do
            table.insert(t_ids, id)
        end
    end
    if t.place then
        for _, id in ipairs(valley.storylines_at(campaign, night.prep, t.place.id)) do
            table.insert(t_ids, id)
        end
    end
    for _, id in ipairs(t_ids) do
        if stop_set[id] then
            local d = sl.def(campaign, id)
            return d and soft(d.short or d.name) or "the same story", id
        end
    end
    -- Two cards that go together.
    local tid = t.card and t.card.id or (t.place and t.place.id)
    for _, c in util.sorted_pairs(sc.comps or {}) do
        if tid and content.goes_with[c.id] and content.goes_with[c.id][tid] and not night:muted(c) then
            return name_of(c), stop_ids[1]
        end
    end
    -- The same place, or the same town.
    local loc = sc.comps and sc.comps.location
    if loc and t.place then
        if t.place.id == loc.id then
            return name_of(loc), stop_ids[1]
        end
        local hub = valley.hub_of(loc.id)
        if hub and hub == valley.hub_of(t.place.id) then
            return "being here in " .. valley.name(hub), stop_ids[1]
        end
    end
    if loc and t.card and content.tied_place(t.card) and content.tied_place(t.card).id == loc.id then
        return name_of(loc), stop_ids[1]
    end
    return nil
end

-- The skew card ------------------------------------------------------------------------------

-- The card for this pull: who, what, why, and the four answers with what each costs and gives.
function M.card(night, sc, p, t)
    local campaign = night.campaign
    local tie = M.tie(night, sc, t)
    if t.theory and not seeds_mod().can_steal(campaign, t.theory) then
        tie = nil
    end
    local due = (campaign.week or 1) + data.OWED_SESSIONS
    local v = vars(night, p, t, { tie = tie or "", due = util.int(due) })
    local why = fill(data.WHY[t.kind], v)
    local options = {}
    local fight = sc.type == "combat" or sc.type == "set_piece"
    for _, key in ipairs(M.ORDER) do
        local a = data.ANSWERS[key]
        local o = { answer = key, label = a.label }
        if key == "weave" and not tie then
            o.disabled = true
            o.sub = a.none
        else
            o.sub = fill((fight and a.cost_fight) or a.cost, v) .. "  " .. fill((fight and a.gives_fight) or a.gives, v)
        end
        table.insert(options, o)
    end
    return {
        id = "skew", type = "skew", trigger = "skew",
        title = fill("{Name} pulls toward {target}", v),
        text = why,
        options = options,
        who = p.key,
        tie = tie,
    }
end

-- Answers ----------------------------------------------------------------------------------

local function remember(night, entry)
    local g = M.get(night.campaign)
    table.insert(g.log, entry)
    night.pull_log = night.pull_log or {}
    table.insert(night.pull_log, entry)
end

-- The pull moves the story: its storyline (or the target's) moves tonight; a place they went to
-- is on the map from now on.
local function move_target(night, sc, t, link_to)
    local campaign = night.campaign
    local sl = storylines_mod()
    local moved = {}
    local ids = {}
    if t.story then
        table.insert(ids, t.story)
    end
    if t.card then
        for _, id in ipairs(sl.of_card(campaign, t.card)) do
            table.insert(ids, id)
        end
    end
    if t.place then
        for _, id in ipairs(valley_mod().storylines_at(campaign, night.prep, t.place.id)) do
            table.insert(ids, id)
        end
    end
    local seen = {}
    sc.stories = sc.stories or {}
    for _, id in ipairs(ids) do
        if not seen[id] then
            seen[id] = true
            if sl.move(night, id, link_to) then
                table.insert(moved, id)
                -- The stop is part of that story now: its Story log files it there too.
                if not util.contains(sc.stories, id) then
                    table.insert(sc.stories, id)
                end
            end
        end
    end
    if t.place then
        places_mod().learn(campaign, t.place.id)
    end
    return moved
end

local RAIL = "railroad"

-- One skew at this stop: who pulls, the card, your call, and what it does. Returns the answer, or
-- nil when nobody pulled.
function M.skew(night, sc, p, t)
    local campaign = night.campaign
    if not p then
        p, t = M.choose(night, sc)
    end
    if not p then
        return nil
    end
    night.pulled_by = night.pulled_by or {}
    night.pulled_ids = night.pulled_ids or {}
    night.pulled_by[p.key] = true
    night.pulled_ids[t.id] = true
    sc.skewed = true
    sc.card_done = true        -- the pull is this stop's card (night:scene_card deals none after it)
    local card = M.card(night, sc, p, t)
    local v = vars(night, p, t, { tie = card.tie or "",
                                  due = util.int((campaign.week or 1) + data.OWED_SESSIONS) })
    -- They say it at the table, out of character.
    night:react({ [p.key] = "lean" })
    night:emit({ kind = "say", who = p.key, text = fill(night.rng:pick(data.SAY[t.kind]), v), ic = false })
    night.actor, night.other = p, nil
    local o = night:decision(card, { pull = true })
    local answer = o and o.answer or "steer"
    local entry = { week = campaign.week, stop = sc.index, key = p.key, kind = t.kind, id = t.id, name = t.name,
                    why = card.text, answer = answer, tie = card.tie }
    local log_line = fill(night.rng:pick(data.AFTER[answer]), v)
    night:say(log_line, "record")
    if answer == "follow" or answer == "weave" then
        sc.pull_lead = p.key       -- they take this stop's final roll (night:climax)
    end
    if answer == "follow" then
        sc.slip = t.name
        night:progress_event(sc)       -- the dots' word: the final roll is harder now
        entry.moved = move_target(night, sc, t, nil)
        night:apply(data.EFFECTS.follow)
        M.credit(campaign, p.key, data.SHARE.follow)
        night:highlight(6, p.char .. " takes the table to " .. t.name, { p }, "curveball")
    elseif answer == "weave" then
        local _, link = M.tie(night, sc, t)
        entry.link = link
        entry.moved = move_target(night, sc, t, link)
        if t.theory then
            local ok = seeds_mod().steal(campaign, t.theory)
            entry.made_true = ok or nil
        end
        night:apply(data.EFFECTS.weave)
        M.credit(campaign, p.key, data.SHARE.weave)
        night:highlight(8, "You weave " .. p.char .. "'s " .. t.name .. " into the plan", { p }, "curveball")
    elseif answer == "park" then
        local g = M.get(campaign)
        table.insert(g.owed, { key = p.key, kind = t.kind, id = t.id, name = t.name,
                               card = t.card and t.card.id or nil, place = t.place and t.place.id or nil,
                               story = t.story, theory = t.theory and t.theory.seed or nil,
                               week = campaign.week, due = (campaign.week or 1) + data.OWED_SESSIONS, state = "owed" })
        night:apply(data.EFFECTS.park)
    else
        night:apply(data.EFFECTS.steer)
        night.steered = (night.steered or 0) + 1
        if night.steered == data.RAILROAD_AT then
            night.railroaded = true
            night:emit({ kind = "say", who = p.key, text = fill(night.rng:pick(data.RAILROAD), v), ic = false })
            night:apply(data.EFFECTS.railroad)
            entry.railroad = true
        end
    end
    remember(night, entry)
    return answer
end

-- A stop starts: any pull you parked that this stop plays is paid off.
function M.on_stop(night, sc)
    local campaign = night.campaign
    local g = M.get(campaign)
    local ids = {}
    for _, c in pairs(sc.comps or {}) do
        ids[c.id] = true
    end
    local stories = {}
    for _, id in ipairs(sc.stories or {}) do
        stories[id] = true
    end
    for _, o in ipairs(g.owed) do
        local p
        for _, q in ipairs(o.state == "owed" and night.players or {}) do
            if q.key == o.key then
                p = q
            end
        end
        if p and (ids[o.id] or (o.card and ids[o.card]) or (o.place and ids[o.place]) or (o.story and stories[o.story])) then
            o.state = "paid"
            o.paid = campaign.week
            local v = { name = p.name, Name = p.name, char = p.char, target = o.name, Target = util.capitalize(o.name) }
            night:react({ [p.key] = "cheer" })
            night:emit({ kind = "say", who = p.key, text = fill(night.rng:pick(data.PAID), v), ic = false })
            night.actor = p
            night:apply(data.EFFECTS.paid)
            M.credit(campaign, p.key, data.SHARE.paid)
            night:highlight(7, "You paid off " .. p.char .. "'s " .. o.name, { p }, "thread")
            night.pulls_paid = night.pulls_paid or {}
            table.insert(night.pulls_paid, o)
        end
    end
end

-- After the night: credit who moved the story in the scenes (the final roll's hero on a won goal,
-- a hero whose own card played), and what the report shows.
function M.after_night(campaign, night)
    -- A Casual's share counts table moments, not spotlight (they dislike a forced one): a stop of
    -- the kind they love counts, two a night at most.
    for _, p in ipairs(night.players or {}) do
        if p.primary == "casual" then
            local n = 0
            for _, sc in ipairs(night.scenes or {}) do
                if sc.terrain and score.taste(p, sc.type) >= 1.2 and n < 2 then
                    n = n + 1
                end
            end
            M.credit(campaign, p.key, n)
        end
    end
    for _, sc in ipairs(night.scenes or {}) do
        if sc.outcome == "win" and sc.final_by then
            M.credit(campaign, sc.final_by, data.SHARE.final_roll)
        end
        local owners = {}
        for _, c in pairs(sc.comps or {}) do
            if c.thread and not owners[c.thread] and sc.terrain then
                owners[c.thread] = true
                M.credit(campaign, c.thread, data.SHARE.own_card)
            end
        end
    end
    return {
        pulls = night.pull_log or {},
        paid = night.pulls_paid or {},
        railroaded = night.railroaded or nil,
        tonight = M.fills(campaign, campaign.players, campaign.week),
        slice = M.fills(campaign, campaign.players, nil),
        owed = M.open_owed(campaign),
    }
end

-- Parked pulls still owed.
function M.open_owed(campaign)
    local out = {}
    for _, o in ipairs(M.get(campaign).owed) do
        if o.state == "owed" then
            table.insert(out, o)
        end
    end
    return out
end

-- What's owed at a place on the map (its own id, a card that happens there, a storyline there).
function M.owed_at(campaign, prep, place_id)
    local out = {}
    for _, o in ipairs(M.open_owed(campaign)) do
        local c = o.card and content.components[o.card]
        local home = c and content.tied_place(c)
        if o.place == place_id or (home and home.id == place_id) then
            table.insert(out, o)
        end
    end
    return out
end

-- The start of a week: a parked pull past its sessions sours; one still owed comes up in the
-- group chat. Returns chat posts { who, key, text, owed = true }.
function M.start_week(campaign)
    local posts = {}
    local week = campaign.week or 1
    for _, o in ipairs(M.get(campaign).owed) do
        local p = campaign:player(o.key)
        if o.state == "owed" and p then
            local v = { name = p.name, Name = p.name, char = p.char, target = o.name, Target = util.capitalize(o.name) }
            if week > o.due then
                o.state = "sour"
                o.soured = week
                for k, n in pairs(data.EFFECTS.sour) do
                    score.add(p, k, n)
                end
                table.insert(posts, { who = p.name, key = p.key, owed = true, sour = true,
                                      text = util.fill(data.SOUR[(week % #data.SOUR) + 1], v) })
            elseif not o.reminded and week > o.week then
                o.reminded = week
                table.insert(posts, { who = p.name, key = p.key, owed = true,
                                      text = util.fill(data.REMIND[(week % #data.REMIND) + 1], v) })
            end
        end
    end
    return posts
end

return M
