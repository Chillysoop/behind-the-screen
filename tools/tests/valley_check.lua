-- The valley map (October 17): the prep board's map of the region holds together. Checks the data
-- (every place has a spot or a town, every road joins places that exist), the layout (the
-- places with no hand-made spot are laid once, apart, inside the map, the same way every campaign
-- and after a save), and over whole slices with each simulated DM, every week:
--   * the map shows every place in play: your places, the hand, places a hand card happens at,
--     and tonight's route; a town's places show on the town's pin
--   * every stop is numbered on its pin, and a place put on the route from the map is where the
--     night plays that scene
--   * threads join only pins that share the storyline, and each one starts from the route
--   * a pin glows only for a storyline there that's cold or dropped
--   * no two pins share a name, and the map stays readable (how many pins at most)
-- Run from the project root: texlua tools/tests/valley_check.lua [runs]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local content = require "game.model.content"
local valley = require "game.model.valley"
local places = require "game.model.places"
local storylines = require "game.model.storylines"
local save = require "game.model.save"

local RUNS = tonumber(arg and arg[1]) or 3

local ok_all = true
local fails = {}
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail or ""))
    ok_all = ok_all and cond
end
local function fail(msg)
    if #fails < 25 then
        table.insert(fails, msg)
    end
end
local function has(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then
            return true
        end
    end
    return false
end

-- The data ------------------------------------------------------------------------------------
print("The data")
local d = valley.data
local bad = {}
for id in pairs(d.places) do
    local c = content.components[id]
    if not (c and c.kind == "location") then
        table.insert(bad, "place " .. id)
    end
end
for id, hub in pairs(d.members) do
    local c = content.components[id]
    if not (c and c.kind == "location") then
        table.insert(bad, "member " .. id)
    end
    if not d.hubs[hub] then
        table.insert(bad, "hub " .. hub)
    end
end
for _, r in ipairs(d.roads) do
    for _, e in ipairs(r) do
        if not (d.hubs[e] or (content.components[e] and content.components[e].kind == "location" and not valley.hub_of(e))) then
            table.insert(bad, "road end " .. e)
        end
    end
end
check(#bad == 0, "every hand-made spot, town member and road end is a place", table.concat(bad, ", "))
-- One road network: every place on a road can be reached from Millbrook (the route follows it).
do
    local c0 = campaign_mod.new(1)
    local cut = {}
    local seen = {}
    for _, r in ipairs(d.roads) do
        for _, e in ipairs(r) do
            if not seen[e] then
                seen[e] = true
                if not valley.road_path(c0, "millbrook", e) then
                    table.insert(cut, e)
                end
            end
        end
    end
    check(#cut == 0, "every road leads back to Millbrook", table.concat(cut, ", "))
end

-- The layout ----------------------------------------------------------------------------------
print("The layout")
local a = campaign_mod.new(1701)
valley.ensure(a)
local pins, total, in_towns = {}, 0, 0
for id, c in pairs(content.components) do
    if c.kind == "location" then
        total = total + 1
        if valley.hub_of(id) then
            in_towns = in_towns + 1
        else
            local x, y = valley.pos(a, id)
            table.insert(pins, { id = id, x = x, y = y })
        end
    end
end
for id, h in pairs(d.hubs) do
    table.insert(pins, { id = id, x = h.x, y = h.y })
end
local outside, closest, pair = {}, math.huge, ""
for i, p in ipairs(pins) do
    if p.x < 0.03 or p.x > 0.97 or p.y < 0.05 or p.y > 0.97 then
        table.insert(outside, p.id)
    end
    for j = i + 1, #pins do
        local q = pins[j]
        local dd = math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
        if dd < closest then
            closest, pair = dd, p.id .. " / " .. q.id
        end
    end
end
check(#outside == 0, "every pin sits inside the map", table.concat(outside, ", "))
check(closest >= 0.06, "no two pins on top of each other",
    string.format("%d places: %d pins, %d in towns; closest %.3f (%s)", total, #pins, in_towns, closest, pair))
local b = campaign_mod.new(9001)
valley.ensure(b)
local moved = {}
for id, p in pairs(a.valley.pos) do
    local q = b.valley.pos[id]
    if not q or math.abs(q.x - p.x) > 1e-9 or math.abs(q.y - p.y) > 1e-9 then
        table.insert(moved, id)
    end
end
check(#moved == 0, "the laid-out places land in the same spots in every campaign", table.concat(moved, ", "))

-- Over whole slices -----------------------------------------------------------------------------
print("Slices")
local T = { weeks = 0, nodes = 0, max_nodes = 0, stops = 0, from_map = 0, played_there = 0, threads = 0, glows = 0,
            saved = 0 }

-- A DM who preps on the map: an empty stop gets a place from the map, where hand cards happen first.
local function fill_from_map(c, prep)
    local placed = {}
    local m = valley.map(c, prep)
    for i, s in ipairs(prep.scenes) do
        if not s.open and not s.module and not s.slots.location then
            local best, best_score
            for _, n in ipairs(m.nodes) do
                for _, pc in ipairs(n.places) do
                    if #valley.stops_at(prep, pc.id) == 0 and prep:can_place(i, pc.id) then
                        local sc = #valley.cards_for(prep, pc.id) * 10 + (places.is_known(c, pc.id) and 1 or 0)
                        if not best_score or sc > best_score then
                            best, best_score = pc, sc
                        end
                    end
                end
            end
            if best then
                local ok = valley.make_stop(prep, i, best.id)
                if ok and s.slots.location and s.slots.location.id == best.id then
                    placed[i] = best.id
                    T.from_map = T.from_map + 1
                else
                    fail(string.format("week %d: Make it stop %d didn't put %s on the scene", c.week, i, best.id))
                end
            end
        end
    end
    return placed
end

for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, RUNS do
        local seed = 17000 + run * 37 + #dm_key
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 3)
        c:session_zero(dm.s0)
        for w = 1, 4 do
            local prep = c:start_week()
            bots.prep(dm, c, prep, rng)
            local placed = fill_from_map(c, prep)
            local m = valley.map(c, prep)
            local where = string.format("%s run %d week %d", dm_key, run, w)
            T.weeks = T.weeks + 1
            T.nodes = T.nodes + #m.nodes
            T.max_nodes = math.max(T.max_nodes, #m.nodes)
            -- Every place in play is on the map, on its own pin or its town's.
            local shown = {}
            for _, n in ipairs(m.nodes) do
                for _, pc in ipairs(n.places) do
                    shown[pc.id] = n
                    if valley.node_of(pc.id) ~= n.id then
                        fail(where .. ": " .. pc.id .. " shows on " .. n.id .. ", not its own pin")
                    end
                end
            end
            local want = {}
            for id in pairs(places.get(c)) do
                want[id] = "known"
            end
            for _, hc in ipairs(prep.hand.location or {}) do
                want[hc.id] = "hand"
            end
            for _, kind in ipairs(content.kinds) do
                for _, hc in ipairs(prep.hand[kind] or {}) do
                    local home = kind ~= "location" and content.tied_place(hc)
                    if home then
                        want[home.id] = "a hand card's place"
                    end
                end
            end
            for i, s in ipairs(prep.scenes) do
                if s.slots.location then
                    want[s.slots.location.id] = "stop " .. i
                end
            end
            for id, why in pairs(want) do
                if not shown[id] then
                    fail(where .. ": " .. id .. " (" .. why .. ") isn't on the map")
                end
            end
            -- Every stop is numbered on its pin.
            for i, s in ipairs(prep.scenes) do
                local loc = s.slots.location
                if loc and not s.open then
                    T.stops = T.stops + 1
                    local n = m.by_id[valley.node_of(loc.id)]
                    if not (n and has(n.stops, i)) then
                        fail(where .. ": stop " .. i .. " (" .. loc.id .. ") isn't numbered on the map")
                    end
                end
            end
            -- Threads join pins that share the storyline, starting from the route.
            local route_sl = {}
            for _, r in ipairs(m.route) do
                for _, sid in ipairs(r.n and r.n.storylines or {}) do
                    route_sl[sid] = true
                end
            end
            for _, t in ipairs(m.threads) do
                T.threads = T.threads + 1
                if not (has(t.a.storylines, t.storyline) and has(t.b.storylines, t.storyline)) then
                    fail(where .. ": a " .. t.storyline .. " thread joins " .. t.a.id .. " and " .. t.b.id .. ", which don't both have it")
                end
                if not route_sl[t.storyline] then
                    fail(where .. ": a " .. t.storyline .. " thread that tonight's route doesn't move")
                end
            end
            -- A glow means a storyline there is cold or dropped.
            local names = {}
            for _, n in ipairs(m.nodes) do
                if n.glow then
                    local found = false
                    for _, sid in ipairs(n.storylines) do
                        if storylines.heat(c, sid) == n.glow then
                            found = true
                        end
                    end
                    if not found then
                        fail(where .. ": " .. n.id .. " glows " .. n.glow .. " with no storyline there that is")
                    end
                    if n.glow == "cold" or n.glow == "loose" then
                        T.glows = T.glows + 1
                    end
                end
                if names[n.name] then
                    fail(where .. ": two pins named " .. n.name)
                end
                names[n.name] = true
            end
            -- The night plays each stop at the place the map put there.
            local night = c:start_night()
            for i, id in pairs(placed) do
                local sc = night.scenes[i]
                if sc and sc.comps.location and sc.comps.location.id == id then
                    T.played_there = T.played_there + 1
                else
                    fail(where .. ": stop " .. i .. " was " .. id .. " on the map, but the night played "
                        .. tostring(sc and sc.comps.location and sc.comps.location.id))
                end
            end
            bots.play_night(night, rng, dm, function() end)
            c:finish_night()
            -- The laid-out spots survive a save.
            local loaded = save.load(save.dump(c))
            local same = loaded and loaded.valley and true
            for id, p in pairs(c.valley and c.valley.pos or {}) do
                local q = loaded and loaded.valley and loaded.valley.pos[id]
                if not q or q.x ~= p.x or q.y ~= p.y then
                    same = false
                end
            end
            if same then
                T.saved = T.saved + 1
            else
                fail(where .. ": the map's laid-out places didn't survive a save")
            end
            if c.slice_over and c:slice_over() then
                break
            end
        end
    end
end

print(string.format("  %d weeks: %.1f pins a week (at most %d), %d stops (%d put there from the map, %d played there), %d threads, %d glowing",
    T.weeks, T.nodes / math.max(1, T.weeks), T.max_nodes, T.stops, T.from_map, T.played_there, T.threads, T.glows))
check(#fails == 0, "the map tells the truth every week", #fails == 0 and "" or (#fails .. " slips"))
check(T.played_there == T.from_map and T.from_map > 0, "every stop put on the route from the map is where the night plays it",
    T.played_there .. " of " .. T.from_map)
check(T.max_nodes <= 18, "the map stays readable", "at most " .. T.max_nodes .. " pins")
check(T.saved == T.weeks, "the layout survives a save every week", T.saved .. " of " .. T.weeks)
for _, f in ipairs(fails) do
    print("    " .. f)
end
print(ok_all and "VALLEY CHECK PASSED" or "VALLEY CHECK FAILED")
os.exit(ok_all and 0 or 1)
