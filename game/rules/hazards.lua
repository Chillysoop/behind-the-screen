-- Hazards in a fight (A10): falling rubble, spreading fire, rising water, a bridge coming apart,
-- slippery ice and strong wind, built from SRD 5.2.1 (game/rules/data/hazards.lua says where).
-- A hazard lives on the battle (b.hazard) as zones on the mat; round() runs it at the top of
-- each round, before anyone moves. The battle asks wind(), deep() and the Burning effect while
-- it plays. Pure Lua.

local data = require "game.rules.data.hazards"

local M = {}
M.data = data

local function key(x, y)
    return x .. "," .. y
end

local function free(b, x, y)
    return b:in_bounds(x, y) and not (b.blocked and b.blocked[x * 1000 + y]) and not (b.blocked and b.blocked[key(x, y)])
end

local function cells_list(set)
    local out = {}
    for k in pairs(set) do
        local x, y = string.match(k, "^(%-?%d+),(%-?%d+)$")
        table.insert(out, { tonumber(x), tonumber(y) })
    end
    table.sort(out, function(a, c) return a[1] * 1000 + a[2] < c[1] * 1000 + c[2] end)
    return out
end

-- (Re)draw a hazard zone on the mat: the old one goes, the new one with every cell comes up.
local function redraw(b, st, name, cells, extra)
    local old = st.zones[name]
    if old then
        for i = #b.zones, 1, -1 do
            if b.zones[i] == old then
                table.remove(b.zones, i)
            end
        end
        b:emit({ kind = "zone_end", zone = old.uid, what = old.kind })
    end
    if next(cells) == nil then
        st.zones[name] = nil
        return nil
    end
    local z = { kind = name, cells = cells, hazard = st.id }
    for k, v in pairs(extra or {}) do
        z[k] = v
    end
    st.zones[name] = b:add_zone(z)
    return st.zones[name]
end

local function burning_effect(b, c, dmg)
    if c.dead or b:find_effect(c, "Burning") then
        return
    end
    b:add_effect(c, { name = "Burning", conds = {}, burning = dmg, tag = true })
    b:log("  %s catches fire!", c.name)
end

-- Somewhere between the two sides: the middle of the creatures.
local function middle(b)
    local sx, sy, n = 0, 0, 0
    for _, c in ipairs(b.creatures) do
        if not c.dead then
            sx, sy, n = sx + c.x, sy + c.y, n + 1
        end
    end
    if n == 0 then
        return math.floor(b.W / 2), math.floor(b.H / 2)
    end
    return math.floor(sx / n + 0.5), math.floor(sy / n + 0.5)
end

-- The board's own source for a hazard (b.sources, from game/model/board.lua): the one nearest
-- the fight, so a fire starts at the hearth and the ice is where the frost was.
local SOURCE_OF = { spreading_fire = "fire", rising_water = "water", slippery_ice = "ice" }

local function source(b, what)
    local list = b.sources and b.sources[what]
    if not list or #list == 0 then
        return nil
    end
    local mx, my = middle(b)
    local best, bd
    for _, src in ipairs(list) do
        for _, sq in ipairs(src.squares) do
            local d = math.max(math.abs(sq[1] - mx), math.abs(sq[2] - my))
            if not bd or d < bd then
                best, bd = src, d
            end
        end
    end
    return best
end

-- How far every free square is from the water on the board (a flood rises out of it).
local function water_distance(b)
    local dist, queue = {}, {}
    for _, src in ipairs(b.sources.water) do
        for _, sq in ipairs(src.squares) do
            local k = key(sq[1], sq[2])
            if dist[k] == nil and b:in_bounds(sq[1], sq[2]) then
                -- the water's own squares: open water (a stream) floods first, a pond's edge next
                dist[k] = free(b, sq[1], sq[2]) and 0 or -1
                table.insert(queue, { sq[1], sq[2] })
            end
        end
    end
    local i = 1
    while i <= #queue do
        local x, y = queue[i][1], queue[i][2]
        i = i + 1
        local d = math.max(dist[key(x, y)], 0)
        for _, dd in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = x + dd[1], y + dd[2]
            local k = key(nx, ny)
            if dist[k] == nil and free(b, nx, ny) then
                dist[k] = d + 1
                table.insert(queue, { nx, ny })
            end
        end
    end
    return dist
end

-- Set a hazard up on a battle (after everyone's placed).
function M.setup(b, id)
    local def = data.hazards[id]
    if not def then
        return nil
    end
    local st = { id = id, def = def, zones = {}, round = 0 }
    b.hazard = st
    local src = SOURCE_OF[id] and source(b, SOURCE_OF[id])
    st.from = src and src.name
    b:log("Hazard: %s%s.", def.name, src and (", from the " .. src.name) or "")
    b:emit({ kind = "hazard", id = id, name = def.name, about = def.about, from = st.from })
    local rng = b.dice.rng
    if id == "spreading_fire" then
        local mx, my = middle(b)
        st.fire = {}
        if src then
            -- It catches beside the hearth (the campfire, the brazier) and spreads from there.
            local near, seen = {}, {}
            for r = 1, 2 do
                for _, sq in ipairs(src.squares) do
                    for dx = -r, r do
                        for dy = -r, r do
                            local x, y = sq[1] + dx, sq[2] + dy
                            if not seen[key(x, y)] and free(b, x, y) and not b:occupant(x, y) then
                                seen[key(x, y)] = true
                                table.insert(near, { x, y })
                            end
                        end
                    end
                end
                if #near >= def.start then
                    break
                end
            end
            for _ = 1, def.start do
                if #near == 0 then
                    break
                end
                local cell = table.remove(near, rng:int(1, #near))
                st.fire[key(cell[1], cell[2])] = true
            end
        end
        local tries = 0
        while tries < 40 and #cells_list(st.fire) < def.start do
            tries = tries + 1
            local x, y = mx + rng:int(-2, 2), my + rng:int(-3, 3)
            if free(b, x, y) and not b:occupant(x, y) then
                st.fire[key(x, y)] = true
            end
        end
        redraw(b, st, "fire", st.fire, { on_enter = function(bb, z, c) burning_effect(bb, c, def.burning) end,
                                         on_start = function(bb, z, c) burning_effect(bb, c, def.burning) end })
    elseif id == "rising_water" then
        st.water, st.level = {}, 0
        if src then
            st.dist = water_distance(b)      -- it comes up out of the stream (the pond, the harbour)
        end
    elseif id == "slippery_ice" then
        st.ice = {}
        local mx, my = middle(b)
        local frost = {}
        if src then
            for _, f in ipairs(b.sources.ice) do
                for _, sq in ipairs(f.squares) do
                    table.insert(frost, sq)
                end
            end
        end
        for _ = 1, def.patches do
            local x0, y0 = mx + rng:int(-4, 3), my + rng:int(-4, 3)
            if #frost > 0 then
                -- where the frost already was
                local sq = frost[rng:int(1, #frost)]
                x0, y0 = sq[1] - rng:int(0, def.size - 1), sq[2] - rng:int(0, def.size - 1)
            end
            for dx = 0, def.size - 1 do
                for dy = 0, def.size - 1 do
                    if free(b, x0 + dx, y0 + dy) then
                        st.ice[key(x0 + dx, y0 + dy)] = true
                    end
                end
            end
        end
        local function slip(bb, z, c)
            if c.dead or c.down or bb:has(c, "prone") or (c.turn and c.turn.slipped) then
                return
            end
            if c.turn then
                c.turn.slipped = true
            end
            if not bb:save(c, def.save[1], def.save[2], { kind = "prone" }) then
                bb:knock_prone(c, "slippery ice")
                bb:log("  %s goes down on the ice.", c.name)
            end
        end
        redraw(b, st, "ice", st.ice, { difficult = true, on_enter = slip, on_start = slip })
    elseif id == "strong_wind" then
        b.wind = true
    end
    return st
end

-- The top of a round: the hazard acts.
function M.round(b)
    local st = b.hazard
    if not st then
        return
    end
    st.round = st.round + 1
    local def, id, rng = st.def, st.id, b.dice.rng
    if id == "falling_rubble" then
        -- What was warned comes down now.
        if st.warned then
            local hit = {}
            for _, c in ipairs(b.creatures) do
                if not c.dead and not c.removed and st.warned[key(c.x, c.y)] then
                    table.insert(hit, c)
                end
            end
            b:log("The ceiling comes down.")
            b:emit({ kind = "hazard_act", id = id, name = "Rubble falls", cells = cells_list(st.warned) })
            for _, c in ipairs(hit) do
                local ok = b:save(c, def.save[1], def.save[2], { kind = "rubble" })
                local parts = b:roll_parts({ def.damage })
                if ok and def.half then
                    parts[1][1] = math.floor(parts[1][1] / 2)
                end
                b:deal(nil, c, parts, { hazard = true })
            end
            st.rubble = st.rubble or {}
            for k in pairs(st.warned) do
                st.rubble[k] = true
            end
            redraw(b, st, "rubble", st.rubble, { difficult = true })
            st.warned = nil
            redraw(b, st, "dust", {}, nil)
        end
        -- Dust trickles where the next piece will fall: near someone, so it matters.
        local alive = {}
        for _, c in ipairs(b.creatures) do
            if not c.dead and not c.removed and not c.down then
                table.insert(alive, c)
            end
        end
        if #alive > 0 then
            st.warned = {}
            for _ = 1, def.per_round do
                local t = alive[rng:int(1, #alive)]
                local x0, y0 = t.x + rng:int(-1, 0), t.y + rng:int(-1, 0)
                for dx = 0, def.size - 1 do
                    for dy = 0, def.size - 1 do
                        if free(b, x0 + dx, y0 + dy) then
                            st.warned[key(x0 + dx, y0 + dy)] = true
                        end
                    end
                end
            end
            redraw(b, st, "dust", st.warned, { warning = true })
        end
    elseif id == "spreading_fire" then
        local edge = {}
        for k in pairs(st.fire) do
            local x, y = string.match(k, "^(%-?%d+),(%-?%d+)$")
            x, y = tonumber(x), tonumber(y)
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = x + d[1], y + d[2]
                if free(b, nx, ny) and not st.fire[key(nx, ny)] then
                    edge[key(nx, ny)] = { nx, ny }
                end
            end
        end
        local list = cells_list(edge)
        for _ = 1, def.spread do
            if #list == 0 then
                break
            end
            local i = rng:int(1, #list)
            local cell = table.remove(list, i)
            st.fire[key(cell[1], cell[2])] = true
            local o = b:occupant(cell[1], cell[2])
            if o and o.x then
                burning_effect(b, o, def.burning)
            end
        end
        b:emit({ kind = "hazard_act", id = id, name = "The fire spreads" })
        redraw(b, st, "fire", st.fire, { on_enter = function(bb, z, c) burning_effect(bb, c, def.burning) end,
                                         on_start = function(bb, z, c) burning_effect(bb, c, def.burning) end })
    elseif id == "rising_water" then
        st.level = st.level + def.rise
        if st.dist then
            -- out of the board's water, a ring a round
            for k, d in pairs(st.dist) do
                if d >= 0 and d <= st.level then
                    st.water[k] = true
                end
            end
        else
            for y = b.H - st.level + 1, b.H do
                for x = 1, b.W do
                    if free(b, x, y) then
                        st.water[key(x, y)] = true
                    end
                end
            end
        end
        st.deep = st.round > def.deep_after
        b:emit({ kind = "hazard_act", id = id, name = st.deep and "The water's deep now" or "The water rises" })
        redraw(b, st, "water", st.water, { difficult = true, deep = st.deep })
    elseif id == "crumbling_bridge" then
        -- On a board with a bridge, only its planks give way (b.planks); anywhere, on a bare mat.
        local planks = b.planks and next(b.planks) and b.planks or nil
        local alive = {}
        for _, c in ipairs(b.creatures) do
            if not c.dead and not c.removed and not c.down and (not planks or planks[key(c.x, c.y)]) then
                table.insert(alive, c)
            end
        end
        st.holes = st.holes or {}
        local fell = {}
        for _ = 1, def.per_round do
            if #alive == 0 then
                break
            end
            -- Planks give way under someone's feet, or right beside them.
            local t = alive[rng:int(1, #alive)]
            local x, y = t.x + rng:int(-1, 1), t.y + rng:int(-1, 1)
            if free(b, x, y) and not st.holes[key(x, y)] and (not planks or planks[key(x, y)]) then
                st.holes[key(x, y)] = true
                local o = b:occupant(x, y)
                if o and o.x and not o.dead and not fell[o] then
                    fell[o] = true
                    if not b:save(o, def.save[1], def.save[2], { kind = "fall" }) then
                        -- Falling (p. 182): 1d6 per 10 feet, and Prone on landing.
                        local dice = math.floor(def.fall_feet / 10)
                        b:log("  The planks give way under %s!", o.name)
                        b:deal(nil, o, b:roll_parts({ { dice, 6, 0, "bludgeoning" } }), { hazard = true })
                        if not o.dead then
                            b:knock_prone(o, "the fall")
                            b:add_effect(o, { name = "Climbing back up", speed_zero = true, expires = b:next_turn(o, "end") })
                        end
                    else
                        b:log("  %s jumps clear as the planks go.", o.name)
                    end
                end
            end
        end
        b:emit({ kind = "hazard_act", id = id, name = "Planks give way" })
        redraw(b, st, "holes", st.holes, { difficult = true })
    end
end

-- Is c standing in deep water (underwater combat, p. 16)?
function M.deep(b, c)
    local st = b.hazard
    return st and st.id == "rising_water" and st.deep and st.water[key(c.x, c.y)] and true or false
end

-- The start of c's turn: Burning (p. 178) burns.
function M.start_turn(b, c)
    local e = b:find_effect(c, "Burning")
    if e and not c.dead then
        if M.deep(b, c) then
            b:remove_effect(c, e, "doused")
            b:log("  The water puts out the flames on %s.", c.name)
            return
        end
        b:log("  %s burns.", c.name)
        b:deal(nil, c, b:roll_parts({ e.burning }), { hazard = true })
    end
end

-- Ice the DM put on the map (Set the stage): SRD 5.2.1 Slippery Ice (p. 195), Difficult Terrain,
-- and a DC 10 Dexterity save or Prone on stepping in or starting a turn there.
function M.slip_zone(b, cells)
    local function slip(bb, z, c)
        if c.dead or c.down or bb:has(c, "prone") or (c.turn and c.turn.slipped) then
            return
        end
        if c.turn then
            c.turn.slipped = true
        end
        if not bb:save(c, "dex", 10, { kind = "prone" }) then
            bb:knock_prone(c, "slippery ice")
            bb:log("  %s goes down on the ice.", c.name)
        end
    end
    local z = { kind = "ice", difficult = true, cells = cells, on_enter = slip, on_start = slip, map = true }
    table.insert(b.zones, z)
    return z
end

-- What the meter adds for a hazard: { xp, dpr } (game/rules/encounter.lua).
-- Traps the DM put on a map (B9): the first creature to step on the square springs it, using the
-- SRD trap's own numbers (game/rules/data/hazards.lua). One square, one trap; it's spent once sprung.
function M.place_traps(b, cells, trap_id)
    local def = data.traps[trap_id] or data.traps.hidden_pit
    local n = 0
    for k in pairs(cells or {}) do
        local z = { kind = "trap", cells = { [k] = true }, trap = trap_id, hidden = true }
        z.on_enter = function(bb, zz, c)
            M.spring(bb, zz, c, def)
        end
        table.insert(b.zones, z)
        n = n + 1
    end
    return n
end

function M.spring(b, z, c, def)
    for i = #b.zones, 1, -1 do
        if b.zones[i] == z then
            table.remove(b.zones, i)
        end
    end
    local sp = def.sprung
    b:log("%s springs a trap: %s.", c.name, def.name)
    b:emit({ kind = "feature", who = c, name = def.name })
    local victims = { c }
    if sp.who == "near" then
        for _, o in ipairs(b.creatures) do
            if o ~= c and not o.dead and not o.removed and b:dist(o, c) <= 5 then
                table.insert(victims, o)
            end
        end
    end
    for _, v in ipairs(victims) do
        local ok = false
        if sp.save then
            ok = b:save(v, sp.save[1], sp.save[2], { kind = "trap" })
        end
        if sp.damage and (not ok or sp.half) then
            local hits = sp.darts and b.dice:roll(sp.darts[1], sp.darts[2]) or 1
            for _ = 1, hits do
                local parts = b:roll_parts({ sp.damage })
                if ok and sp.half then
                    parts[1][1] = math.floor(parts[1][1] / 2)
                end
                if not v.dead then
                    b:deal(nil, v, parts, { hazard = true })
                end
            end
        end
        if sp.extra and not ok and not v.dead then
            b:deal(nil, v, b:roll_parts({ sp.extra }), { hazard = true })
        end
        if sp.condition and not ok and not v.dead then
            b:add_effect(v, { name = (sp.condition == "restrained" and "Netted") or "Poisoned", conds = { [sp.condition] = true },
                              expires = b:next_turn(v, "end"), tag = true })
        end
        if sp.climb and not v.dead and v == c then
            b:knock_prone(v, "fell into the pit")
            v.turn = v.turn or {}
            v.turn.move = 0          -- climbing out takes the rest of the move
        end
    end
end

function M.weight(id)
    local def = data.hazards[id]
    return def and def.xp or 0, def and def.dpr or 0
end

return M
