-- The valley map (the rebuild spec's first milestone, October 17): prep happens on a map of the
-- region. Every place the campaign has sits somewhere on it, laid once and kept; the map shows the
-- ones in play (your places, the places in your hand, places a card in your hand happens at, and
-- tonight's route), the roads between them, and a coloured thread between places that share a
-- storyline. Tonight's route is the prep board's three scenes: stop N is scene N's place. Pure
-- Lua; the data is game/data/valley.lua and the view is game/ui/valley_view.lua.
--
--   campaign.valley = { pos = { [location id] = { x = 0..1, y = 0..1 } } }
--     where the places with no hand-made spot were laid out, once, so they stay put.

local data = require "game.data.valley"
local content = require "game.model.content"
local util = require "game.model.util"

local function places_mod()
    return require "game.model.places"
end
local function storylines_mod()
    return require "game.model.storylines"
end

local M = {}
M.data = data

function M.get(campaign)
    campaign.valley = campaign.valley or {}
    campaign.valley.pos = campaign.valley.pos or {}
    return campaign.valley
end

local function has(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then
            return true
        end
    end
    return false
end

-- The hub a place belongs to (Millbrook for a town place), or nil: it stands on its own.
function M.hub_of(id)
    if data.members[id] then
        return data.members[id]
    end
    local c = content.components[id]
    if c and c.kind == "location" and not data.not_millbrook[id] and not data.places[id] and has(c.setting, "town") then
        return "millbrook"
    end
    return nil
end

-- The pin a place shows on: its hub, or itself.
function M.node_of(id)
    return M.hub_of(id) or id
end

function M.is_hub(node)
    return data.hubs[node] ~= nil
end

-- A small, stable number from a string (the same place lands in the same spot every campaign).
local function hash(s, salt)
    local h = 5381 + (salt or 0) * 7919
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 2147483647
    end
    return h
end

local function frac(s, salt)
    return (hash(s, salt) % 10007) / 10007
end

local function sector_for(c)
    for _, sec in ipairs(data.SECTORS) do
        if sec.tag == nil or has(c.setting, sec.tag) then
            return sec
        end
    end
    return data.SECTORS[#data.SECTORS]
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- Every spot already taken: the hubs, the hand-made places, and what's been laid out.
local function taken(campaign)
    local out = {}
    for _, h in pairs(data.hubs) do
        table.insert(out, { h.x, h.y })
    end
    for _, p in pairs(data.places) do
        table.insert(out, { p.x, p.y })
    end
    for _, p in pairs(M.get(campaign).pos) do
        table.insert(out, { p.x, p.y })
    end
    return out
end

local function nearest(list, x, y)
    local best = math.huge
    for _, p in ipairs(list) do
        local dx, dy = p[1] - x, p[2] - y
        best = math.min(best, math.sqrt(dx * dx + dy * dy))
    end
    return best
end

-- Lay out one place with no hand-made spot: in its tags' part of the valley, clear of the rest.
local function lay(campaign, c)
    local home = data.hubs.millbrook
    local sec = sector_for(c)
    local spots = taken(campaign)
    local bx, by, bd
    for k = 0, 23 do
        local a = math.rad(sec.angle + (frac(c.id, k * 2) * 2 - 1) * sec.spread)
        local r = sec.near + frac(c.id, k * 2 + 1) * (sec.far - sec.near)
        local x = clamp(home.x + math.cos(a) * r, 0.05, 0.95)
        local y = clamp(home.y + math.sin(a) * r, 0.07, 0.95)
        local d = nearest(spots, x, y)
        if d >= data.MIN_GAP then
            bx, by = x, y
            break
        end
        if not bd or d > bd then
            bx, by, bd = x, y, d
        end
    end
    M.get(campaign).pos[c.id] = { x = bx, y = by }
end

-- Lay out every place that needs it, in a fixed order (laid once per campaign, so a place is
-- where it was last week; a place added later finds a gap).
function M.ensure(campaign)
    local v = M.get(campaign)
    local ids = {}
    for id, c in pairs(content.components) do
        if c.kind == "location" and not data.places[id] and not M.hub_of(id) and not v.pos[id] then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        lay(campaign, content.components[id])
    end
end

-- Where a pin sits, in map fractions, and which side its name goes.
function M.pos(campaign, node)
    local h = data.hubs[node]
    if h then
        return h.x, h.y, h.label or "r"
    end
    local p = data.places[node]
    if p then
        return p.x, p.y, p.label or "r"
    end
    p = M.get(campaign).pos[node]
    if not p then
        local c = content.components[node]
        if not c then
            return 0.5, 0.5, "r"
        end
        lay(campaign, c)
        p = M.get(campaign).pos[node]
    end
    return p.x, p.y, (p.x > 0.8 and "l" or "r")
end

-- A pin's name.
function M.name(node)
    local h = data.hubs[node]
    if h then
        return h.name
    end
    local c = content.components[node]
    return c and util.capitalize(c.short or c.name) or node
end

-- Which places the map shows: your places, the places in your hand, any place a card in your hand
-- happens at, and tonight's route. id -> how it got there ("known", "hand", "lead", "route").
function M.visible(campaign, prep)
    local out = {}
    local function add(id, why)
        local c = content.components[id]
        if c and c.kind == "location" and not out[id] then
            out[id] = why
        end
    end
    for _, s in ipairs(prep and prep.scenes or {}) do
        if s.slots.location then
            add(s.slots.location.id, "route")
        end
        for _, id in ipairs(s.spots or {}) do
            add(id, "route")
        end
    end
    for id in pairs(places_mod().get(campaign)) do
        add(id, "known")
    end
    for _, c in ipairs(prep and prep.hand and prep.hand.location or {}) do
        add(c.id, "hand")
    end
    for _, kind in ipairs(content.kinds) do
        if kind ~= "location" then
            for _, c in ipairs(prep and prep.hand and prep.hand[kind] or {}) do
                local home = content.tied_place(c)
                if home then
                    add(home.id, "lead")
                end
            end
        end
    end
    return out
end

-- The cards that happen at a place: hand cards tied to it, not on the board yet.
function M.cards_for(prep, id)
    local out = {}
    for _, kind in ipairs(content.kinds) do
        if kind ~= "location" then
            for _, c in ipairs(prep and prep.hand and prep.hand[kind] or {}) do
                local home = content.tied_place(c)
                if home and home.id == id and not prep:placed_at(c.id) then
                    table.insert(out, c)
                end
            end
        end
    end
    return out
end

-- The route: { { i = scene, id = place id, node = pin, open = true for an open scene's spots } }.
function M.route(prep)
    local out = {}
    for i, s in ipairs(prep and prep.scenes or {}) do
        if s.open then
            for _, id in ipairs(s.spots or {}) do
                table.insert(out, { i = i, id = id, node = M.node_of(id), open = true })
            end
        elseif s.slots.location then
            local id = s.slots.location.id
            table.insert(out, { i = i, id = id, node = M.node_of(id) })
        end
    end
    return out
end

-- The stops a place (or a hub) is on tonight.
function M.stops_at(prep, node)
    local out = {}
    for _, r in ipairs(M.route(prep)) do
        if (r.node == node or r.id == node) and not has(out, r.i) then
            table.insert(out, r.i)
        end
    end
    table.sort(out)
    return out
end

-- How a storyline stands, worst first (for a pin's glow).
local HEAT_RANK = { loose = 4, cold = 3, cooling = 2, warm = 1 }
M.HEAT_RANK = HEAT_RANK
M.HEAT_WORDS = {
    loose = "dropped: the table noticed",
    cold = "cold: move it this week or the table notices",
    cooling = "going cold",
    warm = "warm",
    unopened = "not started yet",
}

-- The storylines a place moves: the place's own card, the cards on scenes there, and the hand
-- cards that happen there. { id... }, in a fixed order.
function M.storylines_at(campaign, prep, id)
    local sl = storylines_mod()
    local set, list = {}, {}
    local function add_card(c)
        for _, sid in ipairs(sl.of_card(campaign, c)) do
            if not set[sid] then
                set[sid] = true
                table.insert(list, sid)
            end
        end
    end
    local c = content.components[id]
    if c then
        add_card(c)
    end
    for _, s in ipairs(prep and prep.scenes or {}) do
        if s.slots.location and s.slots.location.id == id then
            for kind, sc in pairs(s.slots) do
                if kind ~= "location" then
                    add_card(sc)
                end
            end
        end
    end
    for _, hc in ipairs(M.cards_for(prep, id)) do
        add_card(hc)
    end
    table.sort(list)
    return list
end

-- One pin's story: { id, hub, name, x, y, label, places = { card... }, stops = { i... },
-- known, lead (in play but never prepped), storylines = { id... }, glow (the worst heat, when a
-- storyline there is going cold), cards (hand cards that happen there) }.
local function node_info(campaign, prep, node, member_ids, why_of)
    local x, y, label = M.pos(campaign, node)
    local n = { id = node, hub = M.is_hub(node), name = M.name(node), x = x, y = y, label = label, places = {},
                stops = M.stops_at(prep, node), storylines = {}, cards = 0 }
    -- Stops here that are an open scene's spots (the players may go here, or elsewhere).
    n.only_open = #n.stops > 0
    for _, r in ipairs(M.route(prep)) do
        if (r.node == node or r.id == node) and not r.open then
            n.only_open = false
        end
    end
    local sl = storylines_mod()
    local seen = {}
    local known = false
    local worst = 0
    table.sort(member_ids)
    for _, id in ipairs(member_ids) do
        table.insert(n.places, content.components[id])
        if places_mod().is_known(campaign, id) then
            known = true
        end
        n.cards = n.cards + #M.cards_for(prep, id)
        for _, sid in ipairs(M.storylines_at(campaign, prep, id)) do
            if not seen[sid] then
                seen[sid] = true
                table.insert(n.storylines, sid)
                local h = sl.heat(campaign, sid)
                if (HEAT_RANK[h] or 0) > worst then
                    worst = HEAT_RANK[h]
                    n.heat = h
                end
            end
        end
    end
    n.known = known
    n.lead = not known and #n.stops == 0 and not n.hub
    if worst >= HEAT_RANK.cooling then
        n.glow = n.heat
    end
    return n
end

-- Everything the map draws, worked out once per refresh:
--   nodes    the pins (a hub stands for its visible places), in a fixed order
--   by_id    node id -> node
--   roads    { a = node, b = node, faint = true for a path to a place with no road }
--   route    the route, as above, each with its node
--   threads  { a = node, b = node, storyline = id, color = "#hex" }: storylines tonight's route
--            moves, joined to the other places they're at
function M.map(campaign, prep)
    M.ensure(campaign)
    local vis = M.visible(campaign, prep)
    local groups, order = {}, {}
    for id in pairs(vis) do
        local node = M.node_of(id)
        if not groups[node] then
            groups[node] = {}
            table.insert(order, node)
        end
        table.insert(groups[node], id)
    end
    -- Millbrook is always on the map: it's home.
    if not groups.millbrook then
        groups.millbrook = {}
        table.insert(order, "millbrook")
    end
    table.sort(order)
    local out = { nodes = {}, by_id = {}, roads = {}, threads = {}, route = {} }
    local names = {}
    for _, node in ipairs(order) do
        local n = node_info(campaign, prep, node, groups[node], vis)
        table.insert(out.nodes, n)
        out.by_id[node] = n
        names[n.name] = (names[n.name] or 0) + 1
    end
    -- Two places with the same short name (two crypts) go by their full names.
    for _, n in ipairs(out.nodes) do
        if names[n.name] > 1 and not n.hub and content.components[n.id] then
            n.name = util.capitalize(content.components[n.id].name)
        end
    end
    -- Roads where both ends are on the map; a place left with none gets a faint path to its nearest pin.
    local roaded = {}
    for _, r in ipairs(data.roads) do
        local a, b = out.by_id[r[1]], out.by_id[r[2]]
        if a and b then
            table.insert(out.roads, { a = a, b = b })
            roaded[a.id], roaded[b.id] = true, true
        end
    end
    local pathed = {}
    for _, n in ipairs(out.nodes) do
        if not roaded[n.id] and #out.nodes > 1 then
            local best, bd
            for _, o in ipairs(out.nodes) do
                if o ~= n then
                    local d = (o.x - n.x) ^ 2 + (o.y - n.y) ^ 2
                    if not bd or d < bd then
                        best, bd = o, d
                    end
                end
            end
            local key = n.id < best.id and (n.id .. "|" .. best.id) or (best.id .. "|" .. n.id)
            if not pathed[key] then
                pathed[key] = true
                table.insert(out.roads, { a = n, b = best, faint = true })
            end
            roaded[n.id] = true
        end
    end
    for _, r in ipairs(M.route(prep)) do
        r.n = out.by_id[r.node]
        table.insert(out.route, r)
    end
    -- Threads: each storyline the route moves, joined to the other pins it's at (nearest first,
    -- so it reads as one line through the valley, not a web).
    local sl = storylines_mod()
    local on_route = {}
    for _, r in ipairs(out.route) do
        if r.n then
            on_route[r.n.id] = true
        end
    end
    local sids, sid_set = {}, {}
    for _, n in ipairs(out.nodes) do
        if on_route[n.id] then
            for _, sid in ipairs(n.storylines) do
                if not sid_set[sid] then
                    sid_set[sid] = true
                    table.insert(sids, sid)
                end
            end
        end
    end
    table.sort(sids)
    for _, sid in ipairs(sids) do
        local d = sl.def(campaign, sid)
        local at = {}
        for _, n in ipairs(out.nodes) do
            if has(n.storylines, sid) then
                table.insert(at, n)
            end
        end
        if #at >= 2 and d then
            -- Prim's: grow from the first route stop.
            local inside = {}
            local start
            for _, n in ipairs(at) do
                if on_route[n.id] then
                    start = start or n
                end
            end
            inside[start.id] = true
            local count = 1
            while count < #at do
                local ba, bb, bd
                for _, a in ipairs(at) do
                    if inside[a.id] then
                        for _, b in ipairs(at) do
                            if not inside[b.id] then
                                local dd = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
                                if not bd or dd < bd then
                                    ba, bb, bd = a, b, dd
                                end
                            end
                        end
                    end
                end
                inside[bb.id] = true
                count = count + 1
                table.insert(out.threads, { a = ba, b = bb, storyline = sid, color = d.color or "#c8a24a",
                                            name = d.short or d.name })
            end
        end
    end
    return out
end

-- The way from one pin to another along the valley's roads (through places not on the map yet,
-- too: the road is there either way), shortest first. A list of pins from a to b, or nil when no
-- road joins them.
local adjacency
function M.road_path(campaign, a, b)
    if a == b then
        return { a }
    end
    if not adjacency then
        adjacency = {}
        for _, r in ipairs(data.roads) do
            adjacency[r[1]] = adjacency[r[1]] or {}
            adjacency[r[2]] = adjacency[r[2]] or {}
            table.insert(adjacency[r[1]], r[2])
            table.insert(adjacency[r[2]], r[1])
        end
    end
    if not (adjacency[a] and adjacency[b]) then
        return nil
    end
    local dist, prev, done = { [a] = 0 }, {}, {}
    while true do
        local u, best
        for n, d in pairs(dist) do
            if not done[n] and (not best or d < best or (d == best and n < u)) then
                u, best = n, d
            end
        end
        if not u or u == b then
            break
        end
        done[u] = true
        local ux, uy = M.pos(campaign, u)
        for _, v in ipairs(adjacency[u]) do
            local vx, vy = M.pos(campaign, v)
            local nd = best + math.sqrt((ux - vx) ^ 2 + (uy - vy) ^ 2)
            if not dist[v] or nd < dist[v] then
                dist[v], prev[v] = nd, u
            end
        end
    end
    if not dist[b] then
        return nil
    end
    local path, n = {}, b
    while n do
        table.insert(path, 1, n)
        n = prev[n]
    end
    return path
end

-- Put a place on tonight's route as stop i (scene i's place).
function M.make_stop(prep, i, id)
    return prep:place(i, id)
end

-- Take stop i's place off the route.
function M.clear_stop(prep, i)
    local s = prep.scenes[i]
    if s and s.slots.location then
        prep:clear(i, "location")
        return true
    end
    return false
end

-- A place as words: "Out in the wild, ruined." From its settings.
function M.tag_line(c)
    local words = {}
    for _, t in ipairs(c and c.setting or {}) do
        local w = data.TAG_WORDS[t]
        if w and #words < 2 then
            table.insert(words, w)
        end
    end
    if #words == 0 then
        return ""
    end
    return util.capitalize(table.concat(words, ", ")) .. "."
end

return M
