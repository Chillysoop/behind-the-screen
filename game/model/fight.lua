-- Fights on game night: takes the room's encounter, runs it on the M3 rules engine turn by
-- turn, and turns the engine's events into beats for the table (minis moving, dice in the strip,
-- speech bubbles). The DM's decision cards arrive at the moments the fight creates: a crit about
-- to end the boss in round one, a hidden roll that would drop a hero, a fight dragging on. Pure Lua.

local battle = require "game.rules.battle"
local creature = require "game.rules.creature"
local monsters = require "game.rules.data.monsters"
local party_mod = require "game.rules.party"
local encounter = require "game.rules.encounter"
local ai = require "game.rules.ai"
local spells = require "game.rules.spells"
local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"
local takeover = require "game.model.takeover"
local maps = require "game.model.maps"
local museum = require "game.rules.museum"
local barks = require "game.model.barks"
local BARKS = require "game.data.barks"
local able = require "game.model.able"

local M = {}

-- Placement ----------------------------------------------------------------------------------

-- Free squares near (ax, ay), nearest first, spaced out when there is room.
function M.squares_near(blocked, taken, ax, ay, n, spread, W, H)
    local out = {}
    local function free(x, y)
        local k = x * 1000 + y
        return x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not taken[k]
    end
    local function far_enough(x, y)
        for _, s in ipairs(out) do
            if math.max(math.abs(s[1] - x), math.abs(s[2] - y)) < spread then
                return false
            end
        end
        return true
    end
    for pass = 1, 2 do
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n then
                        local x, y = ax + dx, ay + dy
                        if free(x, y) and (pass == 2 or far_enough(x, y)) then
                            table.insert(out, { x, y })
                            taken[x * 1000 + y] = true
                        end
                    end
                end
            end
            if #out >= n then
                return out
            end
        end
    end
    return out
end

-- Squares near (ax, ay) where every mini shows (round three, A1 and engine_screens 4: "Thessaly is behind
-- an interior wall, only her hat shows"; "Oswin is mostly behind Pip"). The camera looks from the south
-- (a higher y is nearer it), so a mini hides one standing in the same or the next column a row or two
-- behind it, and a wall in front hides whoever's behind it: with the board's `occ` (board.compile), every
-- piece by its height, so an office partition hides the next two rows and a plinth the next one
-- (sight.shows: the confirming playtest, three of four heroes behind the offices' partitions); without
-- it, a blocked square straight in front. First pass: none of that, against the squares already chosen
-- and `others` (minis standing there already), within `reach` (6) of the anchor; then clear of the walls
-- a little further out, where another mini may stand two rows ahead; then as squares_near would.
function M.squares_shown(blocked, taken, ax, ay, n, W, H, others, occ, reach, doors)
    local sight = require "game.model.sight"
    reach = reach or 6
    local out = {}
    -- (Only squares in the same room as the anchor: the corners outside an octagon's walls are open
    -- squares too, and nobody can stand there. With `doors`, the board's doors bound the room, open or
    -- not: Conner's playtest, C23, Pip and Thessaly set down in the study across the hall, through its
    -- open door, because the hall was behind a wall from the camera.)
    local door_at = {}
    for _, d in ipairs(doors or {}) do
        door_at[d.x * 1000 + d.y] = true
    end
    local inside = {}
    if ax >= 1 and ay >= 1 and ax <= W and ay <= H and not blocked[ax * 1000 + ay] then
        local queue, head = { { ax, ay } }, 1
        inside[ax * 1000 + ay] = true
        while head <= #queue do
            local q = queue[head]
            head = head + 1
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local x, y = q[1] + d[1], q[2] + d[2]
                local k = x * 1000 + y
                if x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not inside[k] and not door_at[k] then
                    inside[k] = true
                    table.insert(queue, { x, y })
                end
            end
        end
    else
        inside = nil
    end
    local function free(x, y)
        local k = x * 1000 + y
        return x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not taken[k] and (not inside or inside[k])
    end
    local function clear_of_walls(x, y)
        if occ then
            return (sight.shows(occ, x, y))
        end
        return not blocked[x * 1000 + y + 1]        -- (a wall right in front of it)
    end
    local function shows(x, y, strict)
        if not clear_of_walls(x, y) then
            return false
        end
        for _, list in ipairs({ out, others or {} }) do
            for _, s in ipairs(list) do
                local dx, dy = math.abs(s[1] - x), math.abs(s[2] - y)
                if strict and dx <= 1 and dy <= 2 then
                    return false
                elseif not strict and dx == 0 and dy == 1 then
                    return false
                end
            end
        end
        return true
    end
    for pass = 1, 2 do
        local far = pass == 1 and reach or (reach + 4)
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n then
                        local x, y = ax + dx, ay + dy
                        if free(x, y) and shows(x, y, pass == 1) then
                            table.insert(out, { x, y })
                            taken[x * 1000 + y] = true
                        end
                    end
                end
            end
            if #out >= n or r >= far then
                break                       -- (too far from where they should be: crowd in, as before)
            end
        end
        if #out >= n then
            break
        end
    end
    if #out < n and inside and doors then
        -- (Crowd in, inside the room: nobody spills through a door.)
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    local x, y = ax + dx, ay + dy
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n and free(x, y) then
                        table.insert(out, { x, y })
                        taken[x * 1000 + y] = true
                    end
                end
            end
        end
    end
    if #out < n then
        for _, sq in ipairs(M.squares_near(blocked, taken, ax, ay, n - #out, 1, W, H)) do
            table.insert(out, sq)
        end
    end
    return out
end

function M.blocked_set(set_name, map)
    if map and map.template == set_name then
        return maps.layout(map)        -- the DM's own map (B9)
    end
    local layout = content.terrain_layout.sets[set_name] or content.terrain_layout.sets.blank
    local blocked = {}
    for _, sq in ipairs(layout.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    -- The board's own cover (low walls, crates, tables: Half or Three-Quarters), what can't be
    -- seen through (walls), doors, rough ground (brush, rubble, webs), ice and its fires.
    local extras = { cover = {}, deg = {}, rough = {}, traps = {}, planks = layout.planks, sources = layout.sources,
                     opaque = layout.opaque or {}, doors = layout.doors or {}, slippery = layout.slippery or {},
                     lights = layout.lights or {} }
    for k, what in pairs(layout.cover or {}) do
        extras.cover[k] = what           -- true, or what the piece is called ("crate")
        extras.deg[k] = layout.deg and layout.deg[k]
    end
    for k in pairs(layout.rough or {}) do
        extras.rough[k] = true
    end
    return blocked, layout, extras
end

-- The party ---------------------------------------------------------------------------------

local function zero_stats()
    return { dealt = 0, taken = 0, healed = 0, downs = 0, crits = 0, hits = 0, misses = 0, kills = 0 }
end

-- Rules creatures for the players at the table tonight, kept across the night's fights.
function M.party(night)
    if night.pcs then
        return night.pcs
    end
    local camp = night.campaign
    night.pc_level = camp.level or 2      -- what the sheets were built at (the carry checks it)
    local built = party_mod.build(night.pc_level, camp.subclasses)
    night.pcs, night.pc_list = {}, {}
    for _, c in ipairs(built) do
        for _, p in ipairs(night.players) do
            if p.class == c.class then
                c.player_key = p.key
                c.mini = p.key
                c.name = p.char or c.name      -- a new character after a death (B3) keeps the class
                c.hp_full = c.hp_max          -- what a Long Rest brings a drained maximum back to
                night.pcs[p.key] = c
                table.insert(night.pc_list, c)
            end
        end
    end
    -- Where they left off (A16): HP, slots, Hit Point Dice and features carry across nights.
    -- After a Long Rest, the day's buffs go up before the night starts (Mage Armor, Aid).
    local carried = M.load_state(night)
    -- Magic items the party carries (A13). A night that starts rested starts at dawn.
    local items = require "game.model.items"
    if not carried then
        items.dawn(camp, night.rng)
    end
    for _, c in ipairs(night.pc_list) do
        items.apply(camp, c.player_key, c)
    end
    if not carried then
        M.prebuff(night)
    end
    return night.pcs
end

-- What the morning's buffs cost, in words (a slot each: the tile shows one fewer than "every spell
-- back" would suggest, the playtest found).
function M.buff_line(night)
    local who = {}
    for _, c in ipairs(night.pc_list or {}) do
        local p = night.campaign:player(c.player_key)
        local name = p and p.char or c.name
        if c.mage_armor then
            table.insert(who, name .. " puts on Mage Armor")
        end
        if c.aid_caster then
            table.insert(who, name .. " casts Aid on the party")
        end
    end
    if #who == 0 then
        return ""
    end
    return " First thing, " .. table.concat(who, " and ") .. ": a spell slot each, for the day."
end

function M.prebuff(night)
    local b = battle.new({ seed = night.rng:int(1, 2147483000), ai = ai })
    if #night.pc_list > 0 then
        local filler = {}
        for i = 1, 4 do
            filler[i] = night.pc_list[((i - 1) % #night.pc_list) + 1]
        end
        encounter.prebuff(b, filler)
    end
end

-- The party's state lives on the campaign between nights (campaign.party_state). Returns true
-- when it was carried over (no Long Rest since).
local function copy(t)
    if type(t) ~= "table" then
        return t
    end
    local o = {}
    for k, v in pairs(t) do
        o[k] = copy(v)
    end
    return o
end

function M.load_state(night)
    local st = night.campaign.party_state
    if not st or st.rested or st.level ~= (night.campaign.level or 2) then
        return false
    end
    local any = false
    for _, c in ipairs(night.pc_list) do
        local s = st.pcs and st.pcs[c.player_key]
        if s then
            any = true
            c.hp_max = s.hp_max or c.hp_max
            c.hp = math.min(c.hp_max, math.max(1, s.hp or c.hp))
            c.temp = s.temp or 0
            local res = copy(s.res) or c.res
            -- A carried sheet always has a slot count for every level it can cast at.
            if c.slots_max then
                res.slots = res.slots or {}
                for l, n in ipairs(c.slots_max) do
                    res.slots[l] = math.min(n, res.slots[l] or n)
                end
            end
            c.res = res
            if c.hd and s.hd_left then
                c.hd.left = s.hd_left
            end
            c.arcane_used = s.arcane_used
            c.mage_armor = s.mage_armor or false
            c.aid_hp = s.aid_hp
        end
    end
    return any
end

function M.save_state(night, rested)
    local camp = night.campaign
    for _, c in ipairs(night.pc_list or {}) do
        require("game.model.items").settle(c, camp)
    end
    local st = camp.party_state or { pcs = {} }
    st.pcs = st.pcs or {}
    st.level = night.pc_level or camp.level or 2
    st.rested = rested and true or false
    st.week = camp.week
    st.fights_since_long = night.fights_since_long or st.fights_since_long or 0
    for _, c in ipairs(night.pc_list or {}) do
        st.pcs[c.player_key] = { hp = math.max(1, c.hp), hp_max = c.hp_max, temp = c.temp or 0, res = copy(c.res),
                                 hd_left = c.hd and c.hd.left, arcane_used = c.arcane_used or nil,
                                 mage_armor = c.mage_armor or nil, aid_hp = c.aid_hp or nil }
    end
    camp.party_state = st
end

local function ready_for_battle(c)
    c.effects = {}
    c.conc = nil
    c.temp = 0
    c.decoy = nil
    c.turn = {}
    c.reaction_used = false
    c.has_acted = nil
    c.slot_turn = nil
    c.removed = nil
    c.stats = zero_stats()
    if c.down and not c.dead then
        c.down = false
        c.hp = math.max(1, c.hp)
    end
    c.ds = { s = 0, f = 0 }
    c.stable = false
    c.knocked_out = nil          -- (the Sentinel's fists, last fight)
end

-- The encounter ------------------------------------------------------------------------------

-- The meter counts a fight's hazard too (A10).
local function hz_opts(sc)
    local hz = M.hazard_of and M.hazard_of(sc)
    return hz and { hazard = hz } or nil
end

-- An adventure's room brings the book's own fight: that is its family (the leader first, then
-- more of the rest), so nothing falls back to the old story's goblins (the combat audit, Nov 2:
-- a museum fight's "more of them" were goblin warriors, and its fallback leader "the goblin chief").
local function own_family(sc)
    local e = sc and sc.encounter
    if not (e and e.ids and #e.ids > 0) then
        return nil
    end
    local lead = e.ids[1]
    local name = e.boss_name
    if not name then
        local mon = monsters[lead]
        name = "the " .. string.lower(mon and mon.name or lead)
    end
    return { boss = lead, name = name, minion = { e.ids[#e.ids] }, own = true }
end

-- How low a boss prepped to yield gets before she asks to stop (a share of her hit points).
M.YIELD_AT = 0.3

-- Which monsters a scene brings: its cast's, else its location's, else its own, else the default.
function M.family(sc)
    local enc = content.encounters
    local cast = sc.comps and sc.comps.cast
    local loc = sc.comps and sc.comps.location
    return (cast and enc.by_cast[cast.id]) or (loc and enc.by_location[loc.id]) or own_family(sc) or enc.default
end

-- The Museum of Nightmares (v2): what an encounter can bring besides its monsters (see
-- game/rules/museum.lua). On the encounter table, next to ids and boss_name:
--   allies = { "steam_mech" }          creatures fighting for the party (or { id, name, commander })
--   commander = "wizard"               the hero the allies answer to (a class, hero name or player
--                                      key; default the cleverest hero, false for nobody): they power
--                                      down if that hero drops, and Euryale goes for them
--   paint, mirror, averted, drowsy, earplugs, fire_arrows, manual, no_hyper = true
--                                      the battle's options (or in encounter.opts)
M.ENCOUNTER_OPTIONS = { "allies", "commander", "paint", "mirror", "averted", "drowsy", "earplugs", "fire_arrows", "manual",
                        "no_hyper", "charmed", "pond" }

function M.museum_options(sc)
    local e = sc and sc.encounter
    if not e then
        return nil
    end
    local o
    for _, k in ipairs(M.ENCOUNTER_OPTIONS) do
        local v = e[k]
        if v == nil and type(e.opts) == "table" then
            v = e.opts[k]                -- (the options may come grouped: encounter.opts)
        end
        if v ~= nil then
            o = o or {}
            o[k] = v
        end
    end
    return o
end

-- The meter's options for a scene: its hazard, allies on the party's side, paint-touched weapons.
local function meter_opts(sc, mo)
    local o = hz_opts(sc)
    if mo and mo.allies and #mo.allies > 0 then
        o = o or {}
        o.allies = mo.allies
    end
    if mo and mo.paint then
        o = o or {}
        o.paint = true
    end
    return o
end

-- The fight as the room has it (its encounter, or the one boss night builds): its monsters as
-- they are, the meter's read on them, and the battle's options.
function M.plan(night, sc)
    local enc = content.encounters
    local cast = sc.comps.cast
    local fam = M.family(sc)
    local level = night.campaign.level or 2
    local n = math.max(1, #night.pc_list)
    local ids = {}
    for _, id in ipairs(sc.encounter.ids) do
        table.insert(ids, id)
    end
    local boss_name = sc.encounter.boss_name or fam.name
    -- The scene's villain is always on the mat, leading (A7).
    local cfam = cast and enc.by_cast[cast.id]
    if cfam and boss_name ~= cfam.name then
        ids[1] = cfam.boss
        boss_name = cfam.name
    end
    local mo = M.museum_options(sc)
    local meter = encounter.meter(level, n, ids, meter_opts(sc, mo))
    return { ids = ids, boss_name = boss_name, meter = meter, crew = cfam and cfam.crew or nil,
             cast = cast and enc.by_cast[cast.id] and cast.id, built = true, museum = mo }
end

-- Running it -----------------------------------------------------------------------------------

local function ref(c)
    return c.mini
end

local function target_ref(t)
    if type(t) ~= "table" then
        return nil
    end
    if t.mini then
        return t.mini
    end
    if t.x and not t.hp then
        return { t.x, t.y }
    end
    local list = {}
    for _, o in ipairs(t) do
        if o.mini then
            table.insert(list, o.mini)
        end
    end
    return #list > 0 and list or nil
end

-- The squares an area spell covers, for the template on the mat: { {x, y}... }, shape.
function M.area(night, ev)
    local sp = spells.list[ev.id]
    local b = night.battle
    if not sp or not sp.area or not b then
        return nil
    end
    local shape, size = sp.area[1], sp.area[2]
    local c, t = ev.caster, ev.target
    local tx, ty
    if type(t) == "table" then
        if t.x and t.y then
            tx, ty = t.x, t.y
        elseif t[1] and t[1].x then
            tx, ty = t[1].x, t[1].y
        end
    end
    if not tx or not c then
        return nil
    end
    local n = math.max(1, math.floor(size / 5))
    local out, seen = {}, {}
    local function add(x, y)
        if x >= 1 and y >= 1 and x <= b.W and y <= b.H and not seen[x * 1000 + y] then
            seen[x * 1000 + y] = true
            table.insert(out, { x, y })
        end
    end
    if shape == "sphere" then
        for x = tx - n, tx + n do
            for y = ty - n, ty + n do
                add(x, y)
            end
        end
    elseif shape == "square" then
        for x = tx, tx + n - 1 do
            for y = ty, ty + n - 1 do
                add(x, y)
            end
        end
    elseif shape == "cube" and (sp.range or 0) == 0 then
        -- A cube pushed out from the caster (Thunderwave), as spells.cube_from places it.
        local sx = tx > c.x and 1 or (tx < c.x and -1 or 0)
        local sy = ty > c.y and 1 or (ty < c.y and -1 or 0)
        local x0, y0
        if sx ~= 0 and sy ~= 0 then
            x0 = sx > 0 and c.x + 1 or c.x - n
            y0 = sy > 0 and c.y + 1 or c.y - n
        elseif sx ~= 0 then
            x0 = sx > 0 and c.x + 1 or c.x - n
            y0 = c.y - math.floor((n - 1) / 2)
        else
            y0 = sy > 0 and c.y + 1 or c.y - n
            x0 = c.x - math.floor((n - 1) / 2)
        end
        for x = x0, x0 + n - 1 do
            for y = y0, y0 + n - 1 do
                add(x, y)
            end
        end
    elseif shape == "cube" then
        for x = tx, tx + n - 1 do
            for y = ty, ty + n - 1 do
                add(x, y)
            end
        end
    elseif shape == "cone" then
        local dx, dy = tx - c.x, ty - c.y
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 0 then
            for x = c.x - n, c.x + n do
                for y = c.y - n, c.y + n do
                    local ox, oy = x - c.x, y - c.y
                    local ol = math.sqrt(ox * ox + oy * oy)
                    if ol > 0 and math.max(math.abs(ox), math.abs(oy)) <= n and (ox * dx + oy * dy) / (ol * dl) >= 0.86 then
                        add(x, y)
                    end
                end
            end
        end
    end
    if #out == 0 then
        return nil
    end
    return out, shape
end

-- Convert one engine event into a step the table can animate.
function M.step(night, ev)
    local k = ev.kind
    local s = { kind = k }
    if k == "move" then
        s.id = ref(ev.who)
        s.path = {}
        for _, p in ipairs(ev.path) do
            table.insert(s.path, { p[1], p[2] })
        end
    elseif k == "attack" then
        s.id, s.target = ref(ev.att), ref(ev.tgt)
        s.hit, s.crit, s.roll, s.total, s.ac = ev.hit, ev.crit, ev.roll, ev.total, ev.ac
        s.ranged, s.blocked, s.weapon, s.spell = ev.ranged, ev.blocked, ev.weapon, ev.spell
        -- (A hero fighting with a weapon they picked up fights with it: "Crit with the shortsword!" from
        -- the hero the table was told fights with the twin daggers. The second playtest review.)
        if s.weapon and not s.spell and ev.att and ev.att.weapon_item and not ev.ranged then
            s.weapon = ev.att.weapon_item
        end
        s.dmg, s.to_hit, s.cover_what = ev.dmg, ev.to_hit, ev.cover_what
        s.dm = ev.att.side ~= "party"
        s.hidden = s.dm and night.dm_rolls == "hidden"
        s.mode = ev.mode
        -- Why it landed or didn't (the newcomer playtest, October 16): the cover in the AC, and a
        -- Heroic Inspiration reroll.
        s.cover, s.heroic = (ev.cover or 0) > 0 and ev.cover or nil, ev.heroic
    elseif k == "damage" then
        s.id, s.amount, s.hp, s.hp_max, s.crit = ref(ev.tgt), ev.amount, ev.hp, ev.hp_max, ev.crit
        s.graze, s.spell, s.weak = ev.graze, ev.spell, ev.weak
        s.src = ev.src and ev.src ~= ev.tgt and ev.src.mini or nil
    elseif k == "heal" then
        s.id, s.amount, s.hp, s.hp_max = ref(ev.tgt), ev.amount, ev.hp, ev.hp_max
        s.by = ev.src and ref(ev.src)
    elseif k == "spell" then
        s.id, s.name, s.spell, s.target = ref(ev.caster), ev.name, ev.id, target_ref(ev.target)
        s.reaction = ev.reaction
        s.level = ev.slot
        s.free = ev.free          -- (cast without a slot: Quick Reflection, Magic Initiate, the wand)
        s.area, s.shape = M.area(night, ev)
    elseif k == "initiative" then
        s.order = {}
        for _, o in ipairs(ev.order or {}) do
            local c = o.who
            table.insert(s.order, { id = ref(c), name = c.name, side = c.side, roll = o.roll, bonus = o.bonus,
                                    total = o.total, pc = c.pc and true or false })
        end
    elseif k == "zone" or k == "zone_end" then
        s.zone, s.what, s.cells = ev.zone, ev.what, ev.cells
    elseif k == "feature" then
        s.id, s.name, s.target = ref(ev.who), ev.name, target_ref(ev.target)
        s.from, s.to = ev.from, ev.to
        -- The Museum of Nightmares: which big moment this is, and who caused it (museum.lua).
        s.museum, s.by = ev.museum, ev.by and ref(ev.by) or nil
    elseif k == "door" then
        s.id, s.x, s.y, s.state, s.fid = ev.who and ref(ev.who), ev.x, ev.y, ev.state, ev.fid
    elseif k == "save" then
        s.id, s.ok, s.roll, s.dc, s.total, s.ab = ref(ev.who), ev.ok, ev.roll, ev.dc, ev.total, ev.ab
        s.mode, s.why_mode = ev.mode, ev.why_mode
        s.dm = ev.who.side ~= "party"
        s.hidden = s.dm and night.dm_rolls == "hidden"
    elseif k == "condition" or k == "condition_end" then
        s.id, s.name, s.conds = ref(ev.who), ev.name, ev.conds
    elseif k == "death_save" then
        s.id, s.roll = ref(ev.who), ev.roll
    elseif k == "join" then
        local c = ev.who
        s.id, s.monster, s.x, s.y, s.name = ref(c), c.monster_id, c.x, c.y, c.name
        s.hp, s.hp_max = c.hp, c.hp_max
        s.pc, s.class = c.pc or nil, c.class      -- (a hero who split off, coming back: night_view)
    elseif k == "temp" then
        s.id, s.amount = ref(ev.who), ev.amount
    elseif k == "hazard" or k == "hazard_act" then
        s.name, s.about, s.from = ev.name, ev.about, ev.from
    elseif k == "flee" then
        s.id, s.why = ref(ev.who), ev.why
    else
        s.id = ev.who and ref(ev.who)
    end
    return s
end

local function alive_foes(b)
    local n = 0
    for _, c in ipairs(b.creatures) do
        if c.side == "foes" and not c.dead and not c.removed then
            n = n + 1
        end
    end
    return n
end

local function player_of(night, c)
    if c and c.player_key then
        for _, p in ipairs(night.players) do
            if p.key == c.player_key then
                return p
            end
        end
    end
end

-- Who plays a creature fighting on the party's side that isn't a hero: the friend flying it (its pilot),
-- else the companion's owner. nil: it's the DM's to run (the Mech, unless a friend took it over).
function M.ally_player(night, c)
    if not c or c.pc then
        return nil
    end
    if c.pilot then
        return night.campaign:player(c.pilot)
    end
    for _, e in ipairs(require("game.model.companions").active(night.campaign, night.players)) do
        if e.monster and e.monster == c.monster_id and e.owner then
            return night.campaign:player(e.owner)
        end
    end
    return nil
end

-- The Museum of Nightmares (v2): the fight's big moments, logged the way a hero going down or a
-- crit is (a night event, a highlight for the biggest) and played on the players' faces. Each
-- lands in the night's ledger as ev = "moment" with museum = the kind and tags = { "museum", kind }.
M.MUSEUM_MOMENTS = {
    veil = { weight = 7, highlight = true, pose = "gasp", text = "{name} tore off her hood, and the snakes came out" },
    scarabs = { weight = 5, pose = "gasp", text = "Scarabs came pouring out of {name}",
                soft = { bugs = "Something swarmed out of {name}, kept off screen" } },
    petrified = { weight = 8, highlight = true, pose = "gasp", text = "{name} turned to stone" },
    self_stone = { weight = 9, highlight = true, pose = "cheer", text = "{name} met her own eyes in the mirror and turned to stone" },
    freed = { weight = 6, pose = "cheer", text = "{name} cracked free of the stone" },
    mirror = { weight = 6, pose = "lean", text = "The mirror went up, and {name} saw her own eyes" },
    hyper = { weight = 6, highlight = true, pose = "cheer", text = "{name} went into Hyper Destroyer Mode" },
    overheat = { weight = 5, pose = "gasp", text = "{name} overheated, vented steam and shut down" },
    power_down = { weight = 4, pose = "gasp", text = "{name} powered down when {target} fell" },
    listening = { weight = 4, pose = "yawn", text = "{name} sat down to listen to the lecture" },
    woken = { weight = 3, text = "{name} shook {target} out of the lecture" },
    charmed = { weight = 4, text = "{name} fell under {by}'s charm" },
    knocked_out = { weight = 5, pose = "gasp", text = "{name} got knocked out cold by {by}" },
    fled = { weight = 3, text = "{name} lost its nerve and ran" },
}

local function name_of(f, id)
    local c = id and f.by_ref[id]
    return c and c.name or "someone"
end

function M.museum_moments(night, f, steps)
    local poses = {}
    for _, s in ipairs(steps) do
        local kind = s.museum
        if s.kind == "flee" and s.why == "morale" then
            kind = "fled"
        end
        local c = f.by_ref[s.id]
        if kind == "petrified" and c and not c.pc then
            kind = "self_stone"
        end
        local m = kind and M.MUSEUM_MOMENTS[kind]
        if m and c then
            -- (A table that veiled what this is hears it gently, and the DM says so once.)
            local mt = m.text
            if m.soft and night.mus then
                local adv = util.lazy("game.model.adventure")
                for tag, alt in util.sorted_pairs(m.soft) do
                    if adv.test(night.campaign, { soft = tag }) then
                        mt = alt
                        util.lazy("game.model.museum_night").soft_check(night, { { when = { soft = tag } } })
                    end
                end
            end
            local text = util.fill(mt, { name = c.name, target = name_of(f, type(s.target) == "string" and s.target or nil),
                                             by = name_of(f, s.by) })
            local p = c.pc and player_of(night, c) or nil
            local list = p and { p } or night.players
            if m.highlight then
                night:highlight(m.weight, text, list, "moment")
            else
                night:event("moment", { who = p and p.key or "party", text = text, weight = m.weight })
            end
            local e = night.ledger and night.ledger[#night.ledger]
            if e and e.text == text then
                e.museum, e.tags = kind, { "museum", kind }
            end
            f.moments = f.moments or {}
            table.insert(f.moments, { kind = kind, id = s.id, text = text })
            if m.pose then
                if p then
                    poses[p.key] = m.pose
                else
                    for _, q in ipairs(night.players) do
                        poses[q.key] = poses[q.key] or m.pose
                    end
                end
            end
        end
    end
    return poses
end

-- A condition on a hero that has somebody reaching for the rulebook next time (rules_lookup).
M.QUESTIONS = { Charmed = "being charmed", Restrained = "turning to stone", Petrified = "turning to stone",
                Asleep = "Sleep", Grappled = "getting out of a grapple", Listening = "the Lecturer's droning",
                Prone = "getting up off the floor", Frightened = "being frightened" }

-- What happened in the fight that lines afterwards can lean on (F13, the second playtest review:
-- "Oswin's prayer catches Thessaly a heartbeat before they drop" when she took no damage, "pulled off a
-- move together" with no move): night.fight_record = { saves = { { by, to } }, combos = { { a, b } },
-- close = { [hero mini] = true } }. A save is a heal on someone down or at a quarter of their hit
-- points or less; a combo, a foe two heroes both hit within a round of each other, finished by one of
-- them; a close call, a hero who went down or fell to under a third of their hit points.
function M.record(night, f, bb, steps, who)
    local rec = night.fight_record
    if not rec or rec.fight ~= f then
        rec = { fight = f, saves = {}, combos = {}, close = {}, hits = {} }
        night.fight_record = rec
    end
    local round = bb.round or 0
    f.happened = f.happened or {}
    -- (A swing that missed and still did a little, a greatsword's Graze, isn't a hit two heroes made
    -- together: round three heard "pulled off a move together" from a hero who missed both swings.)
    local missed = {}
    for _, s in ipairs(steps) do
        if s.kind == "attack" and s.id then
            missed[s.id] = not s.hit or nil
        elseif s.kind == "spell" and s.id then
            missed[s.id] = nil
        end
        local t = s.id and f.by_ref[s.id]
        -- What a rules question can be about (F14: "that's not how grappling works" when nobody
        -- grappled): a Bless cast, a grapple, a fighter toe to toe with something, a condition worth
        -- looking up.
        if s.kind == "spell" and s.name == "Bless" and t and t.pc then
            f.happened.bless = f.happened.bless or { who = s.id }
        elseif s.kind == "condition" and s.name == "Grappled" and t then
            f.happened.grapple = f.happened.grapple or { who = t.pc and s.id or (who and who.pc and who.mini) or nil }
        elseif s.kind == "attack" and t and t.pc and t.class == "fighter" and not s.ranged and s.target then
            f.happened.melee = { who = s.id, foe = f.by_ref[s.target] }
        end
        if s.kind == "condition" and t and t.pc and M.QUESTIONS[s.name] then
            night.rules_question = M.QUESTIONS[s.name]
        end
        if s.kind == "heal" and t and t.pc and s.by and s.by ~= s.id then
            local before = (s.hp or 0) - (s.amount or 0)
            if before <= 0 or before <= (t.hp_max or 1) * 0.25 then
                table.insert(rec.saves, { by = s.by, to = s.id })
            end
        elseif s.kind == "down" and t and t.pc then
            rec.close[s.id] = true
        elseif s.kind == "damage" and t then
            if t.pc and (s.hp or 0) > 0 and (s.hp or 0) <= (t.hp_max or 1) / 3 then
                rec.close[s.id] = true
            end
            local by = s.src and f.by_ref[s.src]
            if t.side == "foes" and by and by.pc and not missed[s.src] then
                rec.hits[s.id] = rec.hits[s.id] or {}
                rec.hits[s.id][s.src] = round
            end
        elseif s.kind == "death" and t and t.side == "foes" then
            local killer = who and who.pc and who.mini
            for other, r in util.sorted_pairs(rec.hits[s.id] or {}) do
                if killer and other ~= killer and round - r <= 1 then
                    table.insert(rec.combos, { a = killer, b = other })
                    break
                end
            end
        end
    end
end

-- A charmed hero with nobody they're willing to hit doesn't just stand there in silence (the
-- playtest, Nov 2; the second playtest review, F19: a charmed hero's turn passed with no word): every
-- turn of theirs that goes by charmed and idle gets a caption, the first one saying why. Called after
-- every turn, even one with nothing in it.
M.CHARMED_AGAIN = { "{char} is still under {charmer}'s spell, and lets the turn go by.",
                    "{char} can't bring {char_themselves} to raise a hand against {charmer}. Another turn goes by." }
function M.charmed_turn(night, f, who, steps)
    if not (who and who.pc and not who.dead and not who.down) then
        return
    end
    local charmer
    for _, e in ipairs(who.effects or {}) do
        if e.charmed_by then
            charmer = e.charmed_by
        end
    end
    if not charmer then
        return
    end
    for _, s in ipairs(steps or {}) do
        if (s.kind == "attack" or s.kind == "spell") and s.id == who.mini then
            return
        end
    end
    f.charm_said = f.charm_said or {}
    local v = barks.fills({ charmer = barks.foe_label(charmer) }, nil)
    v.char = who.name
    local again = f.charm_said[who.mini]
    f.charm_said[who.mini] = true
    night:say(util.fill(night:fresh(again and M.CHARMED_AGAIN or BARKS.charmed_captions, again and "charmed_again" or "charmed_caption"), v), "dm")
end

-- What the table hears of a fight's big moments (round three, A4, the third playtest: "the mirror,
-- Hyper Destroyer Mode and a natural-20 death save happen only on the mat"). One owner: every moment
-- the rules emit (game/rules/museum.lua's features) that the table can't miss is said here, once, in
-- the order it happened, from BARKS.told (three ways each). Returns what it said, by kind.
local TOLD = BARKS.told
local function told(night, key, vars)
    local line = night:fresh(TOLD[key], "told_" .. key)
    if line then
        night:say(util.fill(line, vars or {}), (key == "petrify" or key == "stone" or key == "veil" or key == "charmed" or key == "scarabs"
            or key == "overheat" or key == "power_down" or key == "friendly_down" or key == "friendly_fire") and "bad" or "good")
    end
    return line
end
M.told_line = told

local function names_list(list)
    return util.join_names(list)
end

function M.tell_moments(night, f, steps)
    local said = {}
    local st = night.campaign and night.campaign.adv
    local mech = st and st.mech_name or "The Mech"
    local function is_pc(c)
        return c and c.pc
    end
    for i, s in ipairs(steps) do
        local c = s.id and f.by_ref[s.id]
        local kind = s.museum
        if kind == "veil" and c and not said.veil then
            -- (The hood off: now the table knows what she is, as the book has it, p26. game/model/told.lua.)
            require("game.model.told").tell(night.campaign, { "gorgon", "hood_off" })
            require("game.model.secrets").event(night.campaign, "hood_off")
            said.veil = told(night, "veil")
        elseif kind == "scarabs" and c and not said.scarabs then
            -- (Said, so the table knows what it's fighting: Sam's veil keeps them off anyone, not out of the
            -- story. The knowledge playtest heard only "You keep the creepy-crawlies off screen".)
            said.scarabs = told(night, "scarabs", { name = barks.foe_label(c) or "the guardian" })
            require("game.model.secrets").event(night.campaign, "scarabs")
        elseif kind == "petrify" and c then
            -- (Who her stare caught this turn: everyone whose feet started to go grey, but her own.)
            local caught = {}
            for j = i + 1, #steps do
                local t = steps[j]
                local tc = t.id and f.by_ref[t.id]
                if t.museum == "petrifying" and tc and tc ~= c then
                    table.insert(caught, tc.name)
                elseif t.museum == "petrify" then
                    break
                end
            end
            if #caught > 0 then
                said.petrify = told(night, "petrify", { caught = names_list(caught), start = #caught == 1 and "starts" or "start" })
            else
                said.petrify = told(night, "petrify_missed")
            end
        elseif kind == "mirror" and c then
            local it, key = require("game.model.items").holding(night.campaign, "mirror")
            local hp = key and night.campaign:player(key)
            -- (Its holder down or gone: whoever's nearest grabs it. Round three, A1.)
            if hp and not able.can_fight(night, hp) then
                local here = night:at_hand(true)
                hp = here[1]
            end
            local holder = (hp and hp.char) or "Someone"
            told(night, "mirror", { holder = holder })
            -- (Did it take? Her own save, a step or two on.)
            local caught = false
            for j = i + 1, #steps do
                local t = steps[j]
                if t.museum == "petrifying" and t.id == s.id then
                    caught = true
                end
            end
            said.mirror = told(night, caught and "mirror_caught" or "mirror_missed")
        elseif kind == "petrified" and c then
            if is_pc(c) then
                said.stone = told(night, "stone", { char = c.name, stays = "stays" })
            elseif c.boss then
                said.self_stone = told(night, "self_stone")
            else
                said.stone = told(night, "stone_other", { char = barks.foe_label(c) and util.capitalize(barks.foe_label(c)) or c.name })
            end
        elseif kind == "freed" and is_pc(c) then
            said.freed = told(night, "freed", { char = c.name })
        elseif kind == "charmed" and is_pc(c) then
            local by = s.by and f.by_ref[s.by]
            local who = (by and barks.foe_label(by)) or "Euryale"
            said.charmed = told(night, "charmed", { char = c.name, charmer = who, Charmer = util.capitalize(who) })
        elseif kind == "hyper" and c then
            said.hyper = told(night, "hyper", { mech = c.name or mech })
        elseif kind == "overheat" and c then
            said.overheat = told(night, "overheat", { mech = c.name or mech })
        elseif kind == "power_down" and c then
            local t = type(s.target) == "string" and f.by_ref[s.target] or nil
            said.power_down = told(night, "power_down", { mech = c.name or mech, target = t and t.name or "its commander" })
        elseif s.kind == "death_save" and s.roll == 20 and is_pc(c) then
            said.nat20 = told(night, "nat20_save", { char = c.name })
            f.nat20_up = f.nat20_up or {}
            f.nat20_up[s.id] = true
        end
    end
    return said
end

-- Friendly fire (round three, A2, the third playtest: "Thessaly's own Shatter downs Oswin, the hit that
-- starts his death, and nobody at the table hears it"): a hero's spell or attack that catches their own
-- side is said aloud, the friend it hit says something to the one who did it, and they own it. In the
-- fight's record for the recap (night.fight_record.friendly).
function M.friendly_fire(night, f, steps, who)
    if not (who and who.pc) then
        return nil
    end
    local hit, downed, seen, spell = {}, {}, {}, nil
    local victims = {}
    for _, s in ipairs(steps) do
        if s.kind == "spell" and s.id == who.mini then
            spell = spell or s.name
        elseif s.kind == "damage" and s.src == who.mini and s.id ~= who.mini then
            local t = f.by_ref[s.id]
            if t and t.side == who.side and not seen[t] then
                seen[t] = true
                table.insert(hit, t.name)
                table.insert(victims, t)
                if (s.hp or 1) <= 0 then
                    table.insert(downed, t.name)
                end
            end
        end
    end
    if #hit == 0 then
        return nil
    end
    local caster = player_of(night, who)
    local v = { char = who.name, spell = spell or "attack", Spell = spell or "The attack", hit = names_list(hit),
                is = #hit == 1 and "is" or "are", downed = names_list(downed), goes = #downed == 1 and "goes" or "go" }
    if spell == nil then
        v.Spell = who.name .. "'s swing"
    end
    if #downed > 0 then
        v.is = #downed == 1 and "is" or "are"
        told(night, "friendly_down", v)
    else
        told(night, "friendly_fire", v)
    end
    -- The friend it hit (the one it dropped, first), to the one who did it; then them.
    local hurt
    for _, t in ipairs(victims) do
        local q = t.pc and player_of(night, t)
        if q and q ~= caster and (not hurt or (t.hp or 1) <= 0) then
            hurt = q
        end
    end
    if hurt and caster then
        night:emit({ kind = "say", who = hurt.key, ic = false, line = "told.friendly_hit",
                     text = util.fill(night:fresh(TOLD.friendly_hit, "told_friendly_hit"), { caster = caster.name, Caster = caster.name }) })
    end
    if caster then
        night:emit({ kind = "say", who = caster.key, ic = false, line = "told.friendly_sorry",
                     text = night:fresh(#downed > 0 and TOLD.friendly_sorry_down or TOLD.friendly_sorry,
                                        #downed > 0 and "told_friendly_sorry_down" or "told_friendly_sorry") })
        local poses = { [caster.key] = "gasp" }
        if hurt then
            poses[hurt.key] = "arms"
        end
        night:react(poses)
    end
    local rec = night.fight_record
    if rec then
        rec.friendly = rec.friendly or {}
        table.insert(rec.friendly, { by = who.mini, char = who.name, spell = spell, hit = hit, downed = downed })
    end
    f.friendly = f.friendly or {}
    table.insert(f.friendly, { by = who.mini, char = who.name, spell = spell, hit = hit, downed = downed })
    return #downed > 0 and "down" or "hit"
end

-- Barks and poses after a turn, from what happened in it.
local function react(night, f, steps, who)
    local P = player_of(night, who)
    local poses, line = M.museum_moments(night, f, steps), nil
    local said = M.tell_moments(night, f, steps)
    local ff = M.friendly_fire(night, f, steps, who)
    local crit, kill, downed, hurt, healed_up, boss_dead = false, false, nil, nil, nil, false
    local kill_name
    for _, s in ipairs(steps) do
        if s.kind == "attack" and s.crit and not s.dm then
            crit = true
        elseif s.kind == "death" then
            local c = f.by_ref[s.id]
            if c and c.side == "foes" then
                kill = true
                -- (Said at the table: "the briar beast", not "Briar Beast 1", the mat's label. The third playtest.)
                kill_name = c.name
                if string.find(c.name or "", "%s%d+$") then
                    kill_name = "the " .. string.lower((string.gsub(c.name, "%s+%d+$", "")))
                end
                if c.boss then
                    boss_dead = true
                end
            elseif c and c.ally and not c.pc then
                -- (An ally's fall is said, and someone reacts: companions.fell. The Mech venting
                -- itself to a stop already has its caption, the overheat moment: just the reaction.)
                require("game.model.companions").fell(night, c, c.shut_down and true or nil)
            end
        elseif s.kind == "down" then
            downed = f.by_ref[s.id]
        elseif s.kind == "damage" then
            local c = f.by_ref[s.id]
            if c and c.pc and s.amount >= c.hp_max * 0.35 and s.hp > 0 then
                hurt = c
            end
        elseif s.kind == "up" then
            healed_up = f.by_ref[s.id]
        elseif s.kind == "condition_end" and s.name == "Turning to stone" then
            -- (Turning to stone resolves out loud, either way: F19. Stone has its caption, the
            -- petrified moment; shaking it off had none.)
            local c = f.by_ref[s.id]
            if c and not c.dead and not (require("game.rules.museum").stone_effect(night.battle, c)) then
                -- (The DM's words for what the save did, not a move of the hero's: game/model/agency.lua.)
                night:say(util.fill("The grey drains out of {char}'s legs, and the stone lets go: {char_they} can move again.", { char = c.name }), "good")
            end
        end
    end
    if downed and downed.pc then
        local victim = player_of(night, downed)
        if victim then
            night:event("down", { who = victim.key, text = downed.name .. " goes down." })
            -- Said out loud, so the table (and the log) hears it: the death-save card is on the mat.
            -- (Three ways and more, fresh, and never "doesn't get up" of someone who might: the fourth playtest heard
            -- "Pip goes down, and doesn't get up. Death saves." five times in one fight, and up she got each time.)
            local bt = night.battle or {}
            local before = bt.downed_keys and bt.downed_keys[victim.key]
            local key = (downed.stable and not downed.dead and "knocked_out") or (before and "knocked_down_again") or "knocked_down"
            local said = night:fresh(TOLD[key], "told_" .. key)
            night:say(util.fill(said or "{char} goes down. Death saves.", { char = downed.name }), "bad")
            poses[victim.key] = "gasp"
            -- (No quip from the floor when it's going this badly: a hero already dead tonight, or this drop
            -- leaves one hero standing or none. The confirming playtest, 56 careful: "Down. Note for later:
            -- the Kruthik Huntling hits harder than it looks." as the whole party went down.)
            -- (Half the party or fewer still standing is going badly too: the final pass's merge, 51 careful
            -- week 5, "That was my good side!" with two of four up, and the other two down a few lines on.)
            -- (Nor when the foes are plainly winning: the party's hit points, all told, a long way behind
            -- theirs. 51 careful week 5: Pip's quip with Euryale at 96 of 127 and the rest down soon after.)
            local up, pcs = 0, 0
            local php, pmax, fhp, fmax = 0, 0, 0, 0
            local boss_fresh = false
            for _, c in ipairs((night.battle and night.battle.creatures) or {}) do
                if c.pc and not c.dead then
                    pcs = pcs + 1
                    php, pmax = php + math.max(0, c.hp or 0), pmax + (c.hp_max or c.hp or 0)
                    if (c.hp or 0) > 0 then
                        up = up + 1
                    end
                elseif not c.pc and c.side ~= "party" and not c.dead and (c.hp or 0) > 0 then
                    fhp, fmax = fhp + c.hp, fmax + (c.hp_max or c.hp)
                    -- (Nor going down to a boss who's barely been scratched: seed 52 careful week 4, "Pip is
                    -- taking a little nap" with Euryale at 86 of 104, and the party down a few minutes on.)
                    if (c.villain or (night.scene and night.scene.boss and c.boss)) and c.hp > 0.5 * (c.hp_max or c.hp) then
                        boss_fresh = true
                    end
                end
            end
            local losing = pmax > 0 and fmax > 0 and fhp / fmax > php / pmax + 0.25
            -- (Nor the second time down in one fight: 53 careful week 4, Pip back up and straight down again,
            -- and the rest down a few lines on.)
            local b = night.battle or {}
            b.downed_keys = b.downed_keys or {}
            local again = b.downed_keys[victim.key]
            b.downed_keys[victim.key] = true
            -- (Nor with someone else already down: it's no time for a quip. A wipe began that way.)
            if not (able.somber(night) == "death" or up <= 1 or 2 * up <= pcs or up <= pcs - 2 or losing or boss_fresh or again) then
                line = { victim, "down_self" }
            end
            score.add(victim, "fun", -2)
            score.add(victim, "challenge", 6)
        end
        for _, p in ipairs(night.players) do
            if not poses[p.key] then
                poses[p.key] = "gasp"
            end
        end
        local medic
        for _, p in ipairs(night.players) do
            if p.class == "cleric" and p ~= victim and able.can_fight(night, p) then
                medic = p          -- (a healer who's down or stone isn't coming: round three, A1)
            end
        end
        -- (Every medic's line is a promise, "I'm coming", "Healing Pip. Cover me.": said only when they can get them
        -- up on their next turn, and then their turn goes to it, ai.lua's c.heal_for. The fourth playtest, 81 careful:
        -- the promise, then five turns of Sacred Flame with no slot or potion left.)
        local mc = medic and night.pcs and night.pcs[medic.key]
        local bb = night.battle
        local can = mc and bb and ai.can_bring_up and ai.can_bring_up(bb, mc, downed)
        -- (One promise at a time: they've already said they're coming for someone still on the floor.)
        local owed = mc and mc.heal_for
        if owed and owed ~= downed and owed.down and not owed.dead then
            can = nil
        end
        if can and night.rng:chance(0.6) then
            mc.heal_for = downed
            line = { medic, "ally_down", { other_char = downed.name, other = victim and victim.name,
                                           other_key = victim and victim.key } }
        end
    elseif boss_dead then
        for _, p in ipairs(night.players) do
            poses[p.key] = "cheer"
        end
        -- The villain gets a last word, played for fun.
        -- (Only when it's them who fell: not when her collection's leader drops while she sleeps.)
        if night.scene and night.scene.comps.cast and not f.last_words and not night.scene.extras_only then
            night:npc_line("down")
        end
        if P then
            line = { P, "kill" }
            -- (When the killing blow was handed to someone, that's the moment: one hero gets the
            -- credit, October 15: "Thessaly brings down" and "Pip lands the killing blow" on one boss.)
            if not f.used.killing_blow then
                night:highlight(8, P.char .. " brings down " .. (f.boss_name or "the boss"), { P }, "villain_falls")
            else
                line = nil
            end
        end
    elseif crit and P then
        poses[P.key] = "cheer"
        line = { P, "crit" }
        night:highlight(6, P.char .. " lands a critical hit", { P }, "crit")
        score.add(P, "spotlight", 6)
        score.add(P, "fun", 3)
        for _, p in ipairs(night.players) do
            if p ~= P then
                poses[p.key] = "lean"
            end
        end
    elseif kill and P then
        poses[P.key] = "cheer"
        if night.rng:chance(0.45) then
            line = { P, "kill", { target = kill_name } }
        end
        score.add(P, "spotlight", 3)
    elseif healed_up and healed_up.pc then
        local back = player_of(night, healed_up)
        if back then
            poses[back.key] = "cheer"
            -- (Up on their own natural 20: nobody to thank.)
            local own = f.nat20_up and f.nat20_up[healed_up.mini]
            line = { back, (own or night.rng:chance(0.5)) and "up_again" or "thanks" }
        end
    elseif hurt then
        local owch = player_of(night, hurt)
        if owch and night.rng:chance(0.5) then
            poses[owch.key] = "gasp"
            line = { owch, "ouch" }
        end
    end
    if next(poses) then
        night:emit({ kind = "react", poses = poses })
    end
    -- A long fight plays briskly: the small stuff (a kill, a scratch, a thank-you) gets said
    -- less, the big moments (a crit, someone dropping, the boss falling) always.
    if line and night:idle() > 60 and not crit and not downed and not boss_dead and night.rng:chance(0.5) then
        line = nil
    end
    if line then
        -- (The line is about this moment: who fell, to what, how many are left. game/model/barks.lua)
        local extra = line[3] or {}
        extra.moment = barks.from_steps(night, steps, who, line[1])
        if line[2] == "ally_down" and downed then
            extra.moment.ally = downed.name
        end
        night:bark(line[1], line[2], extra)
    end
    if crit and P and not boss_dead then
        night:table_behavior("after_crit", P)
    end
end

-- How bad it could get, said on the call that decides it (the newcomer playtest, October 16: a
-- tactics card with no idea whether "go for the squishy one" could kill someone): what every
-- standing monster's turn adds up to when it all hits, against the hero's hit points.
function M.danger_line(bb, hero)
    local together = 0
    for _, e in ipairs(bb.creatures) do
        -- (Asleep or otherwise out of it, a monster isn't hitting anyone this round.)
        if e.side == "foes" and not e.dead and not e.removed and not e.down and e.monster_id
            and not (bb.incapacitated and bb:incapacitated(e)) then
            together = together + require("game.model.matchup").round_damage(e.monster_id)
        end
    end
    together = math.floor(together + 0.5)
    if together <= 0 or not hero then
        return nil
    end
    local hp = util.int(math.max(0, hero.hp or 0))
    if hero.down or (hero.hp or 0) <= 0 then
        return util.fill("{char} is down already: every hit on {char_them} counts as a failed death save.", { char = hero.name })
    end
    if together >= (hero.hp or 0) then
        return "Careful: if they all go for " .. hero.name .. " and hit, that's about " .. util.int(together)
            .. " damage, and " .. hero.name .. " has " .. hp .. " hit points left. " .. hero.name .. " could go down this round."
    end
    return "If they all go for " .. hero.name .. " and hit, that's about " .. util.int(together) .. " damage. "
        .. hero.name .. " has " .. hp .. " hit points left."
end

-- What the "they run for it" call says, counting who's actually still standing (F3, the second
-- playtest review): the boss alone, the boss and her last one or two, or the last of the rest; and
-- whether she's really losing (at half her hit points or less) or just done with it.
local NUMBER_WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
function M.flee_words(f, minions, standing)
    local out = {}
    local boss = f.boss and not f.boss.dead and not f.boss.removed and f.boss or nil
    local name = f.boss_name or (boss and boss.name) or "their leader"
    local Name = util.capitalize(name)
    if standing <= 1 then
        out.label = "It breaks and runs."
        out.log = "The last one turns tail and runs."
    else
        out.label = "The enemies break and flee."
        out.log = "The last " .. (NUMBER_WORDS[standing] or tostring(standing)) .. " turn tail and run."
    end
    local losing = boss and (boss.hp or 0) <= (boss.hp_max or 1) * 0.5
    local why = losing and (Name .. " sees the fight turning, and runs.")
        or (Name .. " has seen enough. She steps back into the smoke, and is gone.")
    if minions == 0 then
        out.boss_label = Name .. " runs for it. (She escapes, and that's how it ends.)"
        out.boss_log = why
        out.villain_label = Name .. " breaks and flees. (They get away.)"
    else
        local rest = minions == 1 and "Her last one goes with her." or "Her last " .. (NUMBER_WORDS[minions] or tostring(minions)) .. " go with her."
        out.boss_label = "Everyone left on her side runs, " .. name .. " too. (She escapes, and that's how it ends.)"
        out.boss_log = why .. " " .. rest
        out.villain_label = "They break and flee, " .. name .. " too. (They get away.)"
    end
    return out
end

-- The DM's call on a moment the fight created. Returns the chosen option.
local MAX_CARDS_PER_FIGHT = 3
-- The nice-to-have calls wait for room under the night's decisions (B8: the boss's turn and the
-- killing blow come first).
local STORY_MOMENT = { escape_earned = true, last_save = true }
local OPTIONAL_CAP = { cornered = 13, tactics = 13, dragging = 13, potion = 13, killing_blow = 13, boss_crit = 13,
                       death_roll = 13 }

-- adjust: { drop = { [battle] = true }, label = { [battle] = text } }: options that would do
-- nothing here go, and options whose effect differs here say so (the playtest, Nov 2: "minions
-- drop" against a lone Sentinel, and "the enemies break and flee" deciding Euryale's ending).
local function moment(night, f, trigger, vars, actor_c, other_c, adjust)
    local card = content.triggered[trigger]
    if not card or f.used[trigger] then
        return nil
    end
    if adjust then
        local copy = {}
        for k, v in pairs(card) do
            copy[k] = v
        end
        copy.text = adjust.text or copy.text
        copy.options = {}
        for _, o in ipairs(card.options or {}) do
            if not (adjust.drop and o.battle and adjust.drop[o.battle]) then
                local lab = adjust.label and o.battle and adjust.label[o.battle]
                if lab then
                    local oc = {}
                    for k, v in pairs(o) do
                        oc[k] = v
                    end
                    oc.label = lab
                    oc.log = (adjust.log and adjust.log[o.battle]) or oc.log
                    -- (What it costs, said on the card: R5, the boss who gets away.)
                    oc.sub = (adjust.sub and adjust.sub[o.battle]) or oc.sub
                    oc.cost = (adjust.cost and adjust.cost[o.battle]) or oc.cost
                    oc.sub_tone = oc.cost and "orange" or oc.sub_tone
                    table.insert(copy.options, oc)
                else
                    table.insert(copy.options, o)
                end
            end
        end
        if #copy.options < 2 then
            return nil          -- (a call with one way to go isn't a call)
        end
        card = copy
    end
    f.cards = f.cards or 0
    -- The story's big turns (a villain getting away, a hero's last save) aren't squeezed out by
    -- the fight's other calls.
    local key = STORY_MOMENT[trigger]
    if (f.cards >= MAX_CARDS_PER_FIGHT and not key) or night:decision_count() >= (key and 15 or 14) then
        return nil
    end
    if OPTIONAL_CAP[trigger] and not night:room(OPTIONAL_CAP[trigger]) and night:idle() < 90 then
        return nil
    end
    -- (The first night's fights play themselves, but for a hero's last save: R6.)
    if night.gentle and trigger ~= "last_save" then
        return nil
    end
    f.cards = f.cards + 1
    f.used[trigger] = true
    -- (What the turn did before the card goes on the mat now; the turn's reactions still see it all.)
    local early = night:flush_turn()
    if early and #early > 0 then
        night.turn_early = night.turn_early or {}
        for _, st in ipairs(early) do
            table.insert(night.turn_early, st)
            -- (An ally who fell in those steps is said now, before the card: F4.)
            local c = st.kind == "death" and f.by_ref[st.id]
            if c and c.ally and not c.pc then
                require("game.model.companions").fell(night, c, c.shut_down and true or nil)
            end
        end
    end
    night.actor = player_of(night, actor_c) or night:pick_actor(card.actor)
    night.other = player_of(night, other_c)
    if not night.other then
        night.other = night:pick_actor(card.other, night.actor)
    end
    return night:decision(card, vars)
end

M.SWITCH_LINES = { "{char} reaches into {mech}'s chest panel and flips the red switch, saved for her all week.",
                   "\"For the Gorgon,\" says {char}, and flips {mech}'s red switch.",
                   "{char} has been waiting all week for this. The red switch goes over, and {mech} starts to shake." }
function M.saved_switch(night, f, bb, r)
    local st = night.mus and night.campaign.adv
    if not (st and st.flags and st.flags.hyper_saved) or f.switch_flipped or r < 1 or bb.no_hyper then
        return
    end
    if not (night.scene and night.scene.room == "lair") then
        return
    end
    for _, c in ipairs(bb.creatures) do
        if c.ally and c.data and c.data.hyper and not c.hyper_spent and not c.dead and not c.removed
            and not c.powered_down and not c.shut_down then
            local cmd = type(c.commander) == "table" and c.commander or (c.commander and f.by_ref[c.commander]) or nil
            local p = cmd and cmd.pc and not cmd.dead and not cmd.down and player_of(night, cmd)
            -- (A commander who's stone or charmed can't reach the panel: round three, A1.)
            if p and able.can_fight(night, p) then
                f.switch_flipped = true
                st.flags.hyper_saved = nil           -- (spent: it's been flipped, as they planned)
                night:flush_turn()
                night:say(util.fill(night:fresh(M.SWITCH_LINES, "saved_switch"), { char = p.char, mech = st.mech_name or "the Mech" }), "good")
                museum.go_hyper(bb, c)
                -- (The switch is this line's; the mode it sets off is tell_moments', after it.)
                local steps = night:flush_turn()
                if steps and #steps > 0 then
                    M.tell_moments(night, f, steps)
                end
            end
            return
        end
    end
end

-- Who comes as "more of them" in this room, when anyone fits (an adventure's `reinforcements`: the
-- room's own kind, said by name, and kept softer or out under Session Zero's lines and veils). Nil:
-- nothing fits here, and the card doesn't offer it (the second playtest review: "more of them come
-- crashing out of the exhibits" in the lecture theatre, never said what they were).
function M.reinforcement(night, sc)
    local adv = night.mus and util.lazy("game.model.adventure")
    local list = adv and adv.data.reinforcements
    if not list then
        return true      -- (outside an adventure: the shared card as it is)
    end
    local r = sc and list[sc.room]
    if not r then
        return nil
    end
    local t = night.campaign.table or {}
    if r.tag and t.lines and t.lines[r.tag] then
        return nil       -- (a line drawn under it at Session Zero: it never happens)
    end
    local soft = r.tag and t.veils and t.veils[r.tag]
    return { id = r.id, n = r.n or 1, label = r.label, log = soft and r.soft or r.line }
end

local function spawn_reinforcements(night, f, b, rf)
    local fam = f.plan_fam
    local id = (type(rf) == "table" and rf.id) or (fam and fam.minion and fam.minion[1])
    if not id then
        -- More of what's already here (more huntlings from the dioramas), not goblins from nowhere.
        local count, best, bn = {}, nil, 0
        for _, c in ipairs(b.creatures) do
            if c.side == "foes" and c ~= f.boss and c.monster_id and not c.ally then
                count[c.monster_id] = (count[c.monster_id] or 0) + 1
                if count[c.monster_id] > bn then
                    best, bn = c.monster_id, count[c.monster_id]
                end
            end
        end
        id = best or "giant_scarab_swarm"
    end
    local taken = {}
    for _, c in ipairs(b.creatures) do
        if not c.dead and not c.removed then
            taken[c.x * 1000 + c.y] = true
        end
    end
    local spots = M.squares_near(f.blocked, taken, f.layout.foes[1] + 2, f.layout.foes[2], (type(rf) == "table" and rf.n) or 3, 1, b.W, b.H)
    for _, sq in ipairs(spots) do
        f.count = f.count + 1
        local m = creature.new_monster(id, " " .. f.count)
        m.mini = "f" .. f.count
        f.by_ref[m.mini] = m
        b:join(m, sq[1], sq[2])
    end
end

-- The hazard a fight has (A10): the encounter builder's, else the complication's (a floor giving
-- way on a bridge is the bridge coming apart).
function M.hazard_of(sc)
    if sc.hazard ~= nil then
        return sc.hazard or nil
    end
    if sc.encounter and sc.encounter.hazard then
        return sc.encounter.hazard
    end
    local comp = sc.comps and sc.comps.complication
    local hz = comp and comp.hazard
    if hz == "falling_rubble" then
        local loc = sc.comps.location
        if loc and util.contains(loc.setting or {}, "bridge") then
            hz = "crumbling_bridge"
        end
    end
    return hz
end

-- Run the fight for a combat or set-piece scene.
function M.run(night, sc, plan)
    local pcs = M.party(night)
    local set_name = sc.terrain
    local map = night:map_for(sc)
    local blocked, layout, extras = M.blocked_set(set_name, map)
    local f = { used = {}, by_ref = {}, count = 0, blocked = blocked, layout = layout, boss_name = plan.boss_name,
                cards = sc.talked and 1 or 0 }     -- a word before the fight (B8) was this fight's first call
    local enc = content.encounters
    -- Who comes as "more of them": the scene's own kind, else more of what's already on the mat
    -- (spawn_reinforcements), never the old story's default goblins.
    f.plan_fam = (sc.comps.cast and enc.by_cast[sc.comps.cast.id]) or (sc.comps.location and enc.by_location[sc.comps.location.id])
        or nil
    -- Doors aren't scenery in a fight: a shut one opens as someone walks through (Set the stage).
    local fight_blocked = blocked
    local doors
    if extras and extras.doors and #extras.doors > 0 then
        fight_blocked, doors = {}, {}
        for k in pairs(blocked) do
            fight_blocked[k] = true
        end
        for _, d in ipairs(extras.doors) do
            doors[d.x .. "," .. d.y] = { state = d.state, x = d.x, y = d.y, fid = d.fid }
            fight_blocked[d.x * 1000 + d.y] = nil
        end
    end
    local b = battle.new({ seed = night.rng:int(1, 2147483000), ai = ai, width = content.terrain_layout.W,
                           height = content.terrain_layout.H, blocked = fight_blocked })
    night.battle = b
    -- The board's cover and rough ground, and the DM's map (B9) on top: its own cover, rough
    -- ground and traps.
    if extras then
        b.doors = doors
        b.deg = extras.deg
        b.opaque = extras.opaque and next(extras.opaque) and extras.opaque or nil
        if extras.slippery and next(extras.slippery) then
            require("game.rules.hazards").slip_zone(b, extras.slippery)
        end
        -- The dark (SRD 5.2.1 "Light"): only the map's lights, the board's fires and the heroes'
        -- torches show anyone; Darkvision sees past them.
        if extras.light == "dark" then
            b.light = { ambient = "dark", sources = extras.lights or {} }
        end
        b.cover = extras.cover
        b.planks = extras.planks or layout.planks     -- a bridge's planks: where a crumbling bridge gives way
        b.sources = extras.sources or layout.sources  -- where a fire, a flood or the ice starts (hazards.lua)
        if next(extras.rough) then
            table.insert(b.zones, { kind = "rough", difficult = true, cells = extras.rough })
        end
        if map and map.template == set_name then
            require("game.rules.hazards").place_traps(b, extras.traps, map.trap or maps.TRAP)
            f.map = map
        end
    end
    local taken = {}
    -- Each hero starts the fight where their mini was standing (the playtest, November 3: "characters
    -- stay where they were instead of resetting to a cluster"): the nearest open square to it. A hero
    -- the table hasn't moved yet starts at the board's own start.
    -- (The nearest one where every mini shows: squares_shown.)
    local party_spots = {}
    local placed = {}
    -- (Not straight behind a piece that's about to wake into a foe: the garden's hedges.)
    if sc.wake and sc.wake.feature then
        local ok, bc = pcall(require("game.model.board").compile, (extras and extras.board) or set_name)
        local feat = ok and bc and bc.by_id and bc.by_id[sc.wake.feature]
        for _, pi in ipairs(feat and feat.pieces or {}) do
            table.insert(placed, { bc.pieces[pi].x, bc.pieces[pi].y })
        end
    end
    for i, c in ipairs(night.pc_list) do
        local at = night.mini_pos and night.mini_pos[c.mini]
        local sq = at and M.squares_shown(blocked, taken, at[1], at[2], 1, b.W, b.H, placed, layout.occ)[1]
        party_spots[i] = sq or M.squares_shown(blocked, taken, layout.party[1], layout.party[2], 1, b.W, b.H, placed, layout.occ)[1]
        if party_spots[i] then
            table.insert(placed, party_spots[i])
        end
    end
    local party_out = {}
    -- Split up this scene (night.lua, "Splitting the party"): whoever wandered off isn't here yet.
    local split = sc.split and sc.split.away or nil
    f.away = {}
    for _, c in ipairs(night.pc_list) do
        if split and split[c.player_key] and not c.dead then
            table.insert(f.away, c)
        end
    end
    -- (Never the whole party: someone has to be there for the fight to start.)
    if #f.away >= #night.pc_list then
        f.away = {}
    end
    local away_set = {}
    for _, c in ipairs(f.away) do
        away_set[c] = true
    end
    for i, c in ipairs(night.pc_list) do
        if not c.dead and not away_set[c] then
            ready_for_battle(c)
            c.torch = (b.light and not c.darkvision) or nil   -- a Torch in the dark (Bright 20 ft, Dim 20 ft more)
            local sq = party_spots[i] or { 2, i + 3 }
            b:add(c, sq[1], sq[2])
            f.by_ref[c.mini] = c
            table.insert(party_out, { id = c.mini, x = sq[1], y = sq[2], class = c.class, hp = c.hp, hp_max = c.hp_max })
        end
    end
    -- (Where the camera sees them too: not behind a wall or a hero. The confirming playtest.)
    local foe_spots = M.squares_shown(blocked, taken, layout.foes[1], layout.foes[2], #plan.ids, b.W, b.H, party_spots, layout.occ)
    -- The room's own figure who starts the fight (the Sentinel on its plinth, the knight out of his
    -- frame) steps off its spot, not in from the edge: the playtest, November 3, saw a second one.
    if sc.npc_at and plan.ids[1] then
        local nx, ny = sc.npc_at[1], sc.npc_at[2]
        local free = not blocked[nx * 1000 + ny]
        for _, ps in ipairs(party_spots) do
            free = free and not (ps[1] == nx and ps[2] == ny)
        end
        if free then
            for i, fs in ipairs(foe_spots) do
                if fs[1] == nx and fs[2] == ny then
                    foe_spots[i] = foe_spots[1]
                end
            end
            foe_spots[1] = { nx, ny }
        end
    end
    -- A foe the adventure puts somewhere of its own (`foes_at`: Noke on the platform above the yard), when that square's
    -- free.
    local room_def = util.lazy("game.model.adventure").data.rooms[sc.room]
    for i, id in ipairs(plan.ids) do
        local want = room_def and room_def.foes_at and room_def.foes_at[id]
        if want and not blocked[want[1] * 1000 + want[2]] then
            local clash = false
            for _, ps in ipairs(party_spots) do
                clash = clash or (ps[1] == want[1] and ps[2] == want[2])
            end
            if not clash then
                for j, fs in ipairs(foe_spots) do
                    if j ~= i and fs[1] == want[1] and fs[2] == want[2] then
                        foe_spots[j] = foe_spots[i]
                    end
                end
                foe_spots[i] = { want[1], want[2] }
            end
        end
    end
    -- The room's own pieces that come alive (the garden's topiary: module.lua `wake`). Each foe
    -- steps off the hedge it was, and that hedge is gone from the mat: its square opens and its
    -- cover goes with it (the playtest, November 3: the hedges were still there after they woke).
    -- A hedge nobody became stays a hedge. A DM's map without the feature wakes nothing.
    local wake_out
    if sc.wake and sc.wake.feature then
        local board = require "game.model.board"
        local ok, c = pcall(board.compile, (extras and extras.board) or set_name)
        local feat = ok and c and c.by_id and c.by_id[sc.wake.feature]
        if feat then
            local free = {}
            for _, pi in ipairs(feat.pieces) do
                local pc = c.pieces[pi]
                table.insert(free, { pc.x, pc.y })
            end
            local function take(i)
                local cell = table.remove(free, i)
                local k = cell[1] * 1000 + cell[2]
                blocked[k], fight_blocked[k] = nil, nil
                local ck = cell[1] .. "," .. cell[2]
                if b.cover then
                    b.cover[ck] = nil
                end
                if b.deg then
                    b.deg[ck] = nil
                end
                return cell
            end
            wake_out = {}
            local placed = {}
            -- Each foe's own hedge first (the horned one is the triceratops), then whatever's left.
            for pass = 1, 2 do
                for i, id in ipairs(plan.ids) do
                    if not placed[i] and #free > 0 then
                        local want = sc.wake.at and sc.wake.at[id]
                        local pick = pass == 2 and 1 or nil
                        if want then
                            for j, cell in ipairs(free) do
                                if cell[1] == want[1] and cell[2] == want[2] then
                                    pick = j
                                end
                            end
                        end
                        if pick then
                            local cell = take(pick)
                            foe_spots[i], placed[i] = cell, true
                            table.insert(wake_out, { cell[1], cell[2] })
                        end
                    end
                end
            end
        end
    end
    f.wake = wake_out
    local foes_out = {}
    local counts = {}
    for i, id in ipairs(plan.ids) do
        counts[id] = (counts[id] or 0) + 1
        local m = creature.new_monster(id, " " .. counts[id])
        f.count = f.count + 1
        m.mini = "f" .. f.count
        if i == 1 then
            m.boss = true
            m.name = util.capitalize(plan.boss_name)
            -- A cast villain leading the fight (B6), for the killing blow and the escape card. (Not
            -- when she's gone and only her collection fights: the knight leading them isn't Euryale.)
            local cast = sc.comps.cast
            if cast and (cast.villain or cast.foe) and not night:muted(cast) and not sc.extras_only then
                m.villain = true
            end
        end
        local sq = foe_spots[i] or { b.W - 1, i }
        b:add(m, sq[1], sq[2])
        f.by_ref[m.mini] = m
        table.insert(foes_out, { id = m.mini, monster = id, x = sq[1], y = sq[2], name = m.name, boss = m.boss,
                                 hp = m.hp, hp_max = m.hp_max, cast = m.villain and sc.comps.cast and sc.comps.cast.id or nil })
    end
    f.boss = b.creatures[#party_out + 1]
    -- The Museum of Nightmares (v2): allies on the party's side (a Steam Mech the heroes woke), next
    -- to them, and the battle's options (game/rules/museum.lua).
    local mo = plan.museum or M.museum_options(sc) or {}
    museum.setup(b, mo)
    -- A hero who drank her wine and failed starts the fight charmed by her (the drink card).
    if mo.charmed and f.boss and f.by_ref[mo.charmed] then
        museum.charm_start(b, f.boss, f.by_ref[mo.charmed])
    end
    local allies_out = {}
    -- Whoever's with the party fights with them (companions.lua): Telpur in initiative, with a mini,
    -- played by whoever asked for him (the playtest, November 3).
    local ally_list = {}
    for _, a in ipairs(mo.allies or {}) do
        table.insert(ally_list, a)
    end
    local companions = require "game.model.companions"
    for _, a in ipairs(companions.fighters(night)) do
        -- Played by their owner; or by a friend whose hero fell tonight (then they answer to no hero).
        local pc = night.pcs and night.pcs[a.pilot]
        if pc and not pc.dead then
            table.insert(ally_list, { id = a.id, name = a.name, commander = pc.class, pilot = a.pilot })
        elseif night.watching and night.watching[a.pilot] then
            table.insert(ally_list, { id = a.id, name = a.name, commander = false, pilot = a.pilot })
        end
    end
    companions.fight_start(night)
    local allies = encounter.make_allies(ally_list, night.pc_list, mo.commander)
    for i, m in ipairs(allies) do
        local a = ally_list[i]
        m.pilot = type(a) == "table" and a.pilot or nil
    end
    local stood = {}
    for _, list in ipairs({ party_spots, foe_spots }) do
        for _, sq in ipairs(list) do
            table.insert(stood, sq)
        end
    end
    local ally_spots = M.squares_shown(blocked, taken, layout.party[1], layout.party[2], #allies, b.W, b.H, stood, layout.occ)
    for i, m in ipairs(allies) do
        m.mini = "a" .. i
        local sq = ally_spots[i] or { 2, b.H - i }
        b:add(m, sq[1], sq[2])
        f.by_ref[m.mini] = m
        table.insert(allies_out, { id = m.mini, monster = m.monster_id, x = sq[1], y = sq[2], name = m.name, ally = true,
                                   hp = m.hp, hp_max = m.hp_max, commander = m.commander and m.commander.mini or nil, pilot = m.pilot,
                                   rides_with = m.pilot })       -- (a companion: back with them after the fight)
    end
    f.allies = allies
    -- Someone joining mid-fight (the bone construct's scarabs) gets a mini on the mat.
    b.hooks.before_join = function(bb, c)
        if not c.mini then
            f.count = f.count + 1
            c.mini = "f" .. f.count
            f.by_ref[c.mini] = c
        end
    end
    -- Surprise from the scouting roll: Disadvantage on Initiative (p. 13).
    for _, c in ipairs(b.creatures) do
        c.surprised = (sc.surprise == "foes" and c.side == "foes") or (sc.surprise == "party" and c.side == "party") or nil
    end
    -- Hedges that were never hedges, huntlings in the exhibits: unless the party spotted them first,
    -- they're surprised (The Museum of Nightmares).
    if not sc.surprise and not sc.ready and museum.false_appearance(b) then
        f.ambushed = true
    end
    night:emit({ kind = "battle", phase = "start", party = party_out, foes = foes_out, terrain = set_name,
                 pieces = f.map and maps.cells(f.map) or nil, allies = #allies_out > 0 and allies_out or nil,
                 ambushed = f.ambushed, danger = plan.meter.danger, srd = plan.meter.srd, wake = f.wake })

    -- Engine events collect into the current turn's steps.
    night.turn_steps, night.turn_who = {}, nil
    b.on_event = function(_, ev)
        if ev.kind == "turn" then
            night.turn_who = ev.who
            return
        end
        if ev.kind == "round" then
            night.turn_who = nil
            return
        end
        table.insert(night.turn_steps, M.step(night, ev))
        -- Who's been hurting the boss (for the boss's turn, B8).
        if ev.kind == "damage" and f.boss and ev.tgt == f.boss and ev.src and ev.src ~= f.boss then
            f.hurt_by = f.hurt_by or {}
            f.hurt_by[ev.src] = (f.hurt_by[ev.src] or 0) + (ev.amount or 0)
        end
        -- Someone drinks a potion: the potion question can come up now (A7), never before.
        if ev.kind == "feature" and ev.name == "Potion of Healing" and ev.who and ev.who.pc and not f.potion_by then
            f.potion_by = ev.who
            f.potion_to = ev.target ~= ev.who and ev.target or nil     -- (fed to someone else: who drank it)
        end
        if ev.kind == "attack" and ev.att.side ~= "party" and ev.roll then
            if night.dm_rolls == "hidden" then
                night.hidden_dm_rolls = night.hidden_dm_rolls + 1
            else
                night.open_dm_rolls = night.open_dm_rolls + 1
            end
        end
    end

    -- A hazard (A10): the one built into the fight, else one the scene's complication brings. Set
    -- up once the table is listening, so "Hazard: ..." and its fire or ice reach the mat.
    local hz = M.hazard_of(sc)
    if hz then
        require("game.rules.hazards").setup(b, hz)
        sc.hazard = hz
    end

    -- Damage the DM can still overrule.
    b.hooks.before_damage = function(bb, src, tgt, total, info)
        if not src or info.bond then
            return total
        end
        -- The scar's deal holds them up through the rest of that turn (F12: "stay up, but with a
        -- scar" was undone by the next attack in the same turn).
        local sc_ = f.scar
        if sc_ and sc_.tgt == tgt and bb.round == sc_.round and bb.active == sc_.turn and not tgt.dead then
            return math.min(total, math.max(0, (tgt.hp or 0) + (tgt.temp or 0) - 1))
        end
        -- (Who's about to land it: a hero, or an ally fighting with them, Telpur or the Mech, told by its
        -- own name and played by its friend. Round three, B9: "Brannoc is about to drop the biggest
        -- huntling", then Telpur's Pointy Toe did.)
        local ally = src.side == "party" and not src.pc and src or nil
        local lander = ally and M.ally_player(night, ally) or nil
        -- The boss is about to go down early.
        if tgt.boss and not (tgt.data and tgt.data.escapes) and src.side == "party" and bb.round <= 2 and total >= tgt.hp and not tgt.dead and not f.used.boss_crit then
            local rf = M.reinforcement(night, night.scene)
            local adjust = (rf == nil and { drop = { reinforce = true } })
                or (type(rf) == "table" and { label = { reinforce = rf.label }, log = { reinforce = rf.log } }) or nil
            local o = moment(night, f, "boss_crit", { boss = f.boss_name, round = bb.round, actor_char = ally and ally.name or nil },
                ally and (lander and night.pcs and night.pcs[lander.key]) or src, nil, adjust)
            if o and o.battle == "second_phase" then
                tgt.hp = total + math.floor(tgt.hp_max * 0.5)
                tgt.phase2 = true
                table.insert(night.turn_steps, { kind = "feature", id = tgt.mini, name = "Second phase" })
            elseif o and o.battle == "reinforce" then
                spawn_reinforcements(night, f, bb, rf)
            end
            return total
        end
        -- The killing blow (B4): a boss or a villain is about to fall. Who describes it?
        -- (An ally the DM runs lands it: the DM describes it, no card.)
        if (tgt.boss or tgt.villain) and src.side == "party" and total >= tgt.hp + (tgt.temp or 0) and not tgt.dead
            and not tgt.phase2_pending and not f.used.killing_blow and night:room(15) and not (ally and not lander) then
            local actor = (ally and lander) or player_of(night, src)
            local other = night:killing_blow_other(actor)
            local o = moment(night, f, "killing_blow", { boss = f.boss_name or tgt.name, kb_target = tgt, actor_char = ally and ally.name or nil },
                (ally and night.pcs and night.pcs[actor.key]) or src, other and night.pcs and night.pcs[other.key] or nil)
            if o and o.kb then
                -- (You hand it to the table; who tells it is theirs to settle: night:kb_share.)
                local teller = o.kb == "actor" and night:kb_share(actor, other, tgt, f.boss_name or tgt.name, ally and ally.name or nil) or nil
                night:killing_blow(teller, tgt, f.boss_name or tgt.name, actor, ally and ally.name or nil)
            end
            return total
        end
        -- A hidden monster hit would drop a hero.
        -- (Not for a hero whose player asked at Session Zero for their death in the open, and you
        -- agreed: saving them behind the screen would break it. The playtest, Nov 2.)
        local promised = night.campaign.table and night.campaign.table.promises
            and night.campaign.table.promises.open_death
        local tp = tgt.pc and player_of(night, tgt)
        if src.side == "foes" and tgt.pc and not tgt.down and total >= tgt.hp + tgt.temp and night.dm_rolls == "hidden"
            and not f.used.death_roll and not (promised and tp and promised == tp.key) then
            local o = moment(night, f, "death_roll", { target = src.name, damage = util.int(total) }, tgt)
            if o and o.battle == "fudge_miss" then
                table.insert(night.turn_steps, { kind = "feature", id = tgt.mini, name = "It glances off" })
                return 0
            elseif o and o.battle == "deal" then
                f.scar = { tgt = tgt, round = bb.round, turn = bb.active }
                return math.max(0, tgt.hp + tgt.temp - 1)
            end
        end
        return total
    end

    -- The boss's key turn is the DM's to run (B8).
    f.max_cards = MAX_CARDS_PER_FIGHT
    b.hooks.before_turn = function(bb, c)
        -- (Not while it's stared down: the stare-down said who it wants for the next few rounds, and it goes for them.
        -- The card comes on a turn after it wears off. The fourth playtest, carry 86 random: "it's Brannoc it wants",
        -- then the boss's turn card sent it after Pip.)
        if c == f.boss and not c.dead and not c.removed and not c.down and not ai.taunted_by(bb, c) then
            takeover.boss_turn(night, f, bb, c)
        end
        -- (Picked on this very turn, by the DM running it: that beats a stare-down from before.)
        c.dm_ran = c.dm_target ~= nil or nil
        -- The DM's call on who they go after (the tactics card) holds for every foe's turn, unless
        -- the DM ran this one themselves.
        local k = c.dm_keep
        if k and not c.dm_target and not k.dead and not k.removed and not k.down then
            c.dm_target = k
        end
        local t = f.focus_on
        if t and c.side == "foes" and not c.dm_target and not t.dead and not t.removed and not t.down then
            c.dm_target = t
        end
    end
    -- The last death save.
    -- No hero dies without a run of bad dice and the DM's say-so (October 17): a hero at 0 Hit
    -- Points always gets their death saves (no one-hit deaths), every death comes to the DM as this
    -- card, and if the card can't come up, the hero is stable instead.
    b.gentle_deaths = true
    b.hooks.before_pc_death = function(bb, c, why)
        f.used.last_save = nil
        local o = moment(night, f, "last_save", { location = sc.comps.location and sc.comps.location.name or "the table" }, c)
        if not o then
            return "stable"
        end
        if o then
            night.last_save_for = c.mini     -- what happens next is the same moment (B3), not another card
        end
        if o and o.battle == "fudge_save" then
            require("game.model.death").fudged(night)   -- B3: fudging deaths again and again costs stakes
            return "stable"
        elseif o and o.battle == "miracle" then
            return "revive"
        end
        return nil
    end

    local opts = {}
    opts.before_round = function(bb, r)
        -- (What happened between turns, a charm from her wine among it, is told too: round three, A4.)
        local between = night:flush_turn()
        if between and #between > 0 then
            M.tell_moments(night, f, between)
        end
        night:emit({ kind = "round", round = r })
        -- The ones who split off: a cut to them, then they come running (round 3).
        if #(f.away or {}) > 0 then
            if r == 2 then
                for _, c in ipairs(f.away) do
                    night:say("Meanwhile, " .. c.name .. " is on the far side of the room's doors, and hears the crash.", "aside")
                end
            elseif r >= 3 then
                local edge = M.squares_near(f.blocked or {}, {}, layout.party[1], layout.party[2], #f.away, 1, bb.W, bb.H)
                for i, c in ipairs(f.away) do
                    if not c.dead then
                        ready_for_battle(c)
                        local sq = edge[i] or { 1, i }
                        bb:join(c, sq[1], sq[2])
                        night:say(util.fill("{char} comes running back. Cut to the fight: {char_they're} in it now.", { char = c.name }), "dm")
                    end
                end
                f.away = {}
                night:flush_turn()
            end
        end
        -- A round of nothing but walking on a big board gets the DM's word on where things stand
        -- (the playtest, Nov 2: rounds passed in silence). Twice a fight at most.
        if r >= 2 and f.round_busy == false and (f.walk_said or 0) < 2 then
            local near
            for _, c in ipairs(bb.creatures) do
                if c.pc and not c.dead and not c.removed then
                    for _, e in ipairs(bb.creatures) do
                        if e.side == "foes" and not e.dead and not e.removed then
                            local d = bb:dist(c, e)
                            if d and (not near or d < near.d) then
                                near = { d = d, foe = e }
                            end
                        end
                    end
                end
            end
            if near and near.d > 5 then
                f.walk_said = (f.walk_said or 0) + 1
                local v = barks.fills({ round = r, foe = barks.foe_label(near.foe), dist = math.floor(near.d / 5 + 0.5),
                                        room = sc.comps and sc.comps.location and sc.comps.location.name or "room" }, nil)
                night:say(util.fill(night:fresh(BARKS.walk_captions, "walk_caption"), v), "dm")
            end
        end
        f.round_busy = false
        -- A long fight loses the story lovers (v2: what they think and don't say).
        if r >= 4 then
            require("game.model.thoughts").brew(night, true)
        end
        -- The red switch they saved for her all week (the Mech's "Save it for the Gorgon"): its
        -- commander flips it in her lair, once the fight is on (round three: "saved for the Gorgon",
        -- and in two runs never flipped). The Mech's own rules then run the mode.
        M.saved_switch(night, f, bb, r)
        -- Table chatter and the villain's taunts between rounds.
        if r >= 2 and night.rng:chance(night:idle() > 60 and 0.12 or 0.3) then
            -- Sometimes it's a habit of theirs (A12): backseat tactics, HP fishing, the spell lookup.
            if not (night.rng:chance(0.5) and night:table_behavior("combat", nil, true)) then
                -- (Only a friend whose hero is in the fight: round three, A1, "I'm moving my mini"
                -- while Brannoc was on the floor.)
                local here = night:at_hand(true)
                local q = #here > 0 and night.rng:pick(here) or nil
                if q then
                    night:bark(q, "fight_chat", { moment = barks.from_fight(night, q) })
                end
            end
        end
        if r >= 2 and r % 2 == 0 and f.boss and not f.boss.dead and plan.cast then
            night:npc_line("taunt")
        end
        -- The potion question, the round after someone drinks one, once a campaign.
        local camp = night.campaign
        if f.potion_by and not f.used.potion and not (camp.house_rules and camp.house_rules.potion_action)
            and not night.used_cards.potion_action and night:decision_count() < 14 then
            local card = content.triggered.potion
            local to = f.potion_to and f.potion_to.pc and player_of(night, f.potion_to)
            moment(night, f, "potion", {}, f.potion_by, to and f.potion_to or nil, to and card and card.text_given and { text = card.text_given } or nil)
        end
        -- A rules question comes up mid-fight, once what it's about has happened in this fight (F14:
        -- a card's `fight_needs`: a Bless, a grapple, a fighter in melee), asked by whoever it
        -- happened to, about a foe still standing.
        local rc = sc.rules_card
        local need = rc and rc.fight_needs
        local did = need and (f.happened or {})[need]
        local by = did and did.who and f.by_ref[did.who]
        local byp = by and by.pc and player_of(night, by)
        -- (Who it happened to asks, once they're back in the fight: a charmed Brannoc didn't ask
        -- about flanking the Lecturer he wouldn't fight. Round three, A1.)
        local stuck = (byp and not able.can_fight(night, byp))
            or (rc and rc.actor_class and night:by_class(rc.actor_class) and not able.can_fight(night, night:by_class(rc.actor_class)))
        if r >= 2 and rc and (not need or did) and not stuck and night:decision_count() < 14 and alive_foes(bb) > 0 then
            if need == "bless" then
                -- (Someone it blessed asks, not the one who cast it.)
                night.actor = night:pick_actor(rc.actor, byp)
            else
                night.actor = byp or night:pick_actor(rc.actor)
            end
            local target
            local foe = did and did.foe
            if foe and not foe.dead and not foe.removed then
                target = (foe == f.boss and f.boss_name) or barks.foe_label(foe)
            elseif f.boss and not f.boss.dead and not f.boss.removed then
                target = f.boss_name
            else
                for _, c in ipairs(bb.creatures) do
                    if not target and c.side == "foes" and not c.dead and not c.removed then
                        target = barks.foe_label(c)
                    end
                end
            end
            if not (need == "melee" and not (foe and not foe.dead and not foe.removed)) then
                night:decision(rc, target and { boss = target } or nil)
                sc.rules_card = nil
            end
        -- Or the DM picks the monsters' tactics, if nothing has come up for a while (right at the
        -- start, if the walk into the fight was long).
        elseif not f.used.tactics and alive_foes(bb) >= 2
            and ((r >= 2 and ((f.cards or 0) == 0 or night:idle() > 70)) or (r == 1 and night:idle() > 60)) then
            local squishy, big
            for _, c in ipairs(night.pc_list) do
                if not c.dead then
                    if not squishy or bb:ac(c) < bb:ac(squishy) then squishy = c end
                    if not big or c.hp_max > big.hp_max then big = c end
                end
            end
            if squishy and big then
                local bigp = player_of(night, big)
                local o = moment(night, f, "tactics", { boss = f.boss_name, squishy_char = squishy.name,
                    big_char = big.name, big = bigp and bigp.name or big.name, danger = M.danger_line(bb, squishy) })
                if o and o.battle then
                    bb.focus = o.battle
                    -- Every call shows (A11): the hero the monsters turn on wears a tag on the mat.
                    local marked = (o.battle == "squishy" and squishy) or (o.battle == "big" and big) or nil
                    -- (And they really do: each of them goes for that hero while they're standing,
                    -- however far, not whoever's nearest. F12: "Everyone on Brannoc", and the boss
                    -- went elsewhere.)
                    f.focus_on = marked
                    -- (The latest call wins: a pick from an earlier boss turn the boss was keeping to gives way.
                    -- Seed 531, round four's gate: "Everyone on Brannoc", and Euryale kept on at Pip.)
                    for _, x in ipairs(bb.creatures) do
                        if x.side == "foes" then
                            x.dm_keep = nil
                        end
                    end
                    if marked then
                        bb:add_effect(marked, { name = "Targeted", conds = {}, tag = true })
                    elseif o.battle == "spread" then
                        table.insert(night.turn_steps, { kind = "feature", id = f.boss and f.boss.mini, name = "Spreads the hits" })
                    end
                end
            end
        end
        -- The villain is beaten and looking for a way out (B6): let them escape, or finish it. (In an
        -- adventure's rooms there's always somewhere to run: deeper into the exhibits.)
        local vb = f.boss
        -- (Some never run: a guardian bound to its chamber, a ghost to its lecture hall. And a boss
        -- the DM prepped to yield or to fight to the last doesn't take a way out instead: that's
        -- the boss card's call, M.yield_check.)
        local stays = (sc.comps and sc.comps.cast and sc.comps.cast.stays) or sc.boss_style ~= nil
        -- (Only where a foe who runs comes back, `escapes_return`: the museum's are on Euryale's card. Anywhere else the
        -- card's "they'll be back" is a promise nothing keeps: the playtest, November 6, the bed dragon "got away" and then
        -- fell apart. A foe the story has run, like Noke, runs on its own: escapes in its stat block.)
        local adv_data = require("game.model.adventure").data
        stays = stays or not (adv_data and adv_data.escapes_return)
        if vb and vb.villain and not stays and not vb.dead and not vb.removed and r >= 2 and vb.hp <= vb.hp_max * 0.45
            and not f.escape_asked and not bb.force_end and night:room(15) and night.rng:chance(0.8) then
            f.escape_asked = true      -- (asked once a fight, whether or not the card could come up)
            local o = moment(night, f, "escape_earned", { boss = f.boss_name })
            if o and o.battle == "escape" then
                bb:remove(vb, "flee")
                for _, c in ipairs(bb.creatures) do
                    if c.side == "foes" and not c.dead and not c.removed then
                        bb:remove(c, "flee")
                    end
                end
                bb.force_end = "party"
                f.fled = true
                night:event("escape", { who = "party", text = util.capitalize(f.boss_name or vb.name) .. " got away." })
            end
        end
        -- Round six and counting (or a long stretch with nothing for the DM to do).
        if (r >= 6 or (r >= 4 and night:idle() > 70)) and alive_foes(bb) >= 1 and not f.used.dragging and not bb.force_end then
            -- (No minions, no "minions drop". And in a boss fight that's the ending, the card says
            -- so: the boss who runs is gone for good.)
            local minions = 0
            for _, c in ipairs(bb.creatures) do
                if c.side == "foes" and not c.boss and not c.dead and not c.removed then
                    minions = minions + 1
                end
            end
            local boss_alive = f.boss and not f.boss.dead and not f.boss.removed
            -- (Some never run: a guardian bound to its chamber. The third round's review: the bone guardian "ran
            -- for it", and the rack of bones still crumbled.)
            local bound = sc.comps and sc.comps.cast and sc.comps.cast.stays and not sc.boss_style
            local adjust = { drop = { minions = minions == 0 or nil, flee = (bound and boss_alive) or nil }, label = {}, log = {} }
            -- (Who runs is who's still standing: "everyone on her side breaks and runs" was said with
            -- all three of her minions dead, and "the fight turning" with her at 78 of 104. The second
            -- playtest review.)
            local M_ = M.flee_words(f, minions, alive_foes(bb))
            adjust.label.flee, adjust.log.flee = M_.label, M_.log
            if sc.boss_style and boss_alive and not sc.extras_only then
                adjust.label.flee = M_.boss_label
                adjust.log.flee = M_.boss_log
                -- Letting her run costs half the reward (R5, D2): the card says so, as the board did.
                local _, esc_sub = util.lazy("game.model.adventure").escape_cost(night.campaign)
                if esc_sub then
                    adjust.sub, adjust.cost = { flee = esc_sub }, { flee = "escape" }
                end
            elseif boss_alive and f.boss.villain then
                adjust.label.flee = M_.villain_label
            end
            local o = moment(night, f, "dragging", { round = r }, nil, nil, adjust)
            if o and o.battle == "flee" then
                for _, c in ipairs(bb.creatures) do
                    if c.side == "foes" and not c.dead and not c.removed then
                        bb:remove(c, "flee")
                    end
                end
                bb.force_end = "party"
                f.fled = true
            elseif o and o.battle == "minions" then
                for _, c in ipairs(bb.creatures) do
                    if c.side == "foes" and not c.boss and not c.dead then
                        c.hp = 1
                    end
                end
            end
        end
        night:flush_turn()
    end
    -- The fight as it went, a frame a turn, for the report's Look to play back (the playtest,
    -- November 3: "the look button should quickly replay the combat"). Compact: "mini:x:y:down".
    night.fight_frames = {}
    night.fight_wake = f.wake       -- (the hedges that got up: the report's replay lifts them too)
    night.fight_kinds = {}
    night.fight_acts = {}
    -- Each turn's frame: where everyone is, down or not, and their hit points (the report's replay
    -- shows the bars: the playtest, November 3).
    local function frame(bb)
        local fr = {}
        for _, cr in ipairs(bb.creatures) do
            if cr.x and not cr.removed and cr.mini then
                table.insert(fr, cr.mini .. ":" .. cr.x .. ":" .. cr.y .. ":" .. ((cr.dead or cr.down) and 1 or 0) .. ":"
                    .. math.max(0, math.floor(cr.hp or 0)))
                if not night.fight_kinds[cr.mini] then
                    night.fight_kinds[cr.mini] = { side = cr.side == "party" and "party" or "foe", class = cr.class, monster = cr.monster_id,
                                                   name = cr.name, hp_max = cr.hp_max }
                end
            end
        end
        table.insert(night.fight_frames, table.concat(fr, ";"))
        if #night.fight_frames > 60 then
            table.remove(night.fight_frames, 1)
            table.remove(night.fight_acts, 1)
        end
    end
    -- What happened in a turn, in a few words each, for the replay: attacks, spells, damage, healing.
    local function acts_of(steps)
        local out = {}
        for _, st in ipairs(steps or {}) do
            if st.kind == "attack" and st.id and st.target then
                table.insert(out, { k = "a", a = st.id, t = st.target, hit = st.hit and true or nil, crit = st.crit or nil,
                                    w = st.weapon or st.spell, ranged = st.ranged or nil })
            elseif st.kind == "spell" and st.id then
                table.insert(out, { k = "s", a = st.id, t = type(st.target) == "string" and st.target or nil, w = st.name })
            elseif st.kind == "damage" and st.id then
                table.insert(out, { k = "d", t = st.id, n = st.amount, crit = st.crit or nil })
            elseif st.kind == "heal" and st.id then
                table.insert(out, { k = "h", t = st.id, n = st.amount })
            end
            if #out >= 8 then
                break
            end
        end
        return out
    end
    frame(b)
    opts.after_turn = function(bb, c)
        frame(bb)
        local steps = night:flush_turn()
        -- (A card in the middle of the turn put its first steps on the mat early: the reactions,
        -- an ally's fall among them, read the whole turn.)
        if night.turn_early then
            local all = night.turn_early
            night.turn_early = nil
            for _, st in ipairs(steps or {}) do
                table.insert(all, st)
            end
            steps = all
        end
        night.fight_acts[#night.fight_frames] = acts_of(steps)
        -- (The DM's pick held until it went at them: done now.)
        if c.dm_keep then
            for _, st in ipairs(steps or {}) do
                if (st.kind == "attack" or st.kind == "spell" or st.kind == "feature") and st.id == c.mini
                    and st.target == c.dm_keep.mini then
                    c.dm_keep = nil
                    break
                end
            end
        end
        M.charmed_turn(night, f, c, steps)
        if steps and #steps > 0 then
            M.record(night, f, bb, steps, c)
            react(night, f, steps, c)
            for _, s in ipairs(steps) do
                if s.kind ~= "move" then
                    f.round_busy = true
                end
            end
        end
        -- A boss the DM prepped to yield ("She yields near the end"), beaten badly enough, asks to
        -- stop, and everything on her side stops with her; the yield card plays after the fight.
        -- A blow that kills her first has killed her: the dead don't yield (the combat audit, Nov 2).
        local yb = f.boss
        if sc.boss_style == "yields" and not sc.extras_only and not f.yielded and not bb.force_end and yb and not yb.dead and not yb.removed
            and yb.hp > 0 and yb.hp <= yb.hp_max * M.YIELD_AT then
            f.yielded = true
            for _, e in ipairs(bb.creatures) do
                if e.side == "foes" and not e.dead and not e.removed then
                    bb:remove(e, "yield")        -- (they stand down with her: not "ran", not "threw down their weapon")
                end
            end
            bb.force_end = "party"
            night:flush_turn()
            if sc.yield_line then
                night:say(sc.yield_line, "good")
            end
            return
        end
        -- Someone pinned down by a crowd.
        if not f.used.cornered and c.side == "foes" then
            for _, pc in ipairs(night.pc_list) do
                if not pc.dead and not pc.down and pc.battle == bb and pc.hp <= pc.hp_max * 0.3 then
                    local n = 0
                    for _, e in ipairs(bb.creatures) do
                        if e.side == "foes" and not e.dead and not e.removed and not e.down and bb:dist(e, pc) <= 5 then
                            n = n + 1
                        end
                    end
                    if n >= 2 then
                        local helper
                        for _, o2 in ipairs(night.pc_list) do
                            if o2 ~= pc and not o2.dead and not o2.down then
                                helper = helper or o2
                            end
                        end
                        local o = moment(night, f, "cornered", { target_count = n, hp = util.int(pc.hp) }, pc, helper)
                        if o and o.battle == "distract" then
                            for _, e in ipairs(bb.creatures) do
                                if e.side == "foes" and not e.dead and bb:dist(e, pc) <= 5 then
                                    bb:add_effect(e, { name = "Distracted", conds = { incapacitated = true },
                                                       expires = bb:next_turn(e, "end") })
                                end
                            end
                        elseif o and o.battle == "rescue" and helper then
                            bb:give_temp(pc, 5 + (night.campaign.level or 2))
                            local prof = ai.melee_profile and ai.melee_profile(bb, helper)
                            local adj
                            for _, e in ipairs(bb.creatures) do
                                if e.side == "foes" and not e.dead and bb:dist(e, pc) <= 5 then
                                    adj = adj or e
                                end
                            end
                            if prof and adj then
                                bb.active = helper
                                helper.turn = helper.turn or {}
                                bb:attack(helper, adj, prof, { no_sneak = true })
                                bb.active = nil
                            end
                        end
                        night:flush_turn()
                        break
                    end
                end
            end
        end
    end

    -- Stared down before the fight (night.lua: a won Intimidation check in this room): the one in
    -- charge goes for whoever did it, for the first few rounds (the playtest, November 3).
    local tz = night.scene and night.scene.taunt
    if tz and not tz.used then
        tz.used = true
        local pc = night.pcs and night.pcs[tz.key]
        local lead = f.boss
        if not lead then
            for _, e in ipairs(b.creatures) do
                if e.side == "foes" and not e.dead and not e.removed and (not lead or (e.hp_max or 0) > (lead.hp_max or 0)) then
                    lead = e
                end
            end
        end
        if pc and lead and not pc.dead and not pc.down then
            b:add_effect(lead, { name = "Taunted", taunt_by = pc, conds = { taunted = true },
                                 expires = { who = lead, at = "end", n = tz.rounds or 3 } })
            night:say(M.stare_line(night, lead, pc, lead == f.boss), "aside")
        end
    end
    -- Heroic Inspiration (B4): a hero holding the token can spend it in the fight.
    for _, c in ipairs(night.pc_list or {}) do
        local p = player_of(night, c)
        c.heroic = p and p.heroic or nil
    end
    local result = b:run(opts)
    local last = night:flush_turn()
    if last and #last > 0 then
        M.tell_moments(night, f, last)
    end
    -- (What they used up in it leaves their packs now: a potion drunk is gone. items.lua)
    for _, c in ipairs(night.pc_list or {}) do
        require("game.model.items").settle(c, night.campaign)
    end
    for _, c in ipairs(night.pc_list or {}) do
        local p = player_of(night, c)
        if p and p.heroic and not c.heroic then
            p.heroic = nil
            night:event("inspiration", { who = p.key, text = c.name .. " spent Heroic Inspiration in the fight.", spent = true })
            night:emit({ kind = "token", who = p.key, what = "inspiration", spent = true })
        end
    end
    if f.fled then
        result.winner = "party"
    end
    night.battle = nil
    night.fights = night.fights + 1
    -- (Where everyone ended up is where they stand when the room goes on.)
    night.mini_pos = night.mini_pos or {}
    for _, c in ipairs(night.pc_list or {}) do
        if c.x and not c.dead then
            night.mini_pos[c.mini] = { c.x, c.y }
        end
    end
    night:emit({ kind = "battle", phase = "end", winner = result.winner, rounds = result.rounds,
                 summary = M.summary(b, f, result) })
    return result, f
end

-- How the fight went, for the card when it's over (the newcomer playtest, October 16: no fight
-- summary, and "runs for it" with "the last one falls" left it unclear whether they'd won).
--   how     won, fled (the foes ran), yielded, escaped (the villain got away), lost
--   heroes  { id, name, hp, hp_max, hits, swings, dealt, beaten, downs, dead }
--   beaten, ran: the foes' names; boss: the boss's name, and how it ended for them
function M.summary(b, f, result)
    local how = "won"
    if result.winner ~= "party" then
        how = "lost"
    elseif f.yielded then
        how = "yielded"
    elseif f.fled then
        how = (f.boss and f.boss.villain and f.boss.removed) and "escaped" or "fled"
    end
    local out = { how = how, rounds = result.rounds or b.round or 0, heroes = {}, beaten = {}, ran = {} }
    for _, c in ipairs(b.creatures) do
        local st = c.stats or {}
        if c.ally then
            -- (The Museum of Nightmares: a Steam Mech on their side, and how it ended for it.)
            out.allies = out.allies or {}
            table.insert(out.allies, { id = c.mini, name = c.name, monster = c.monster_id, hp = math.max(0, c.hp or 0),
                                       hp_max = c.hp_max, dealt = st.dealt or 0,
                                       state = (c.shut_down and "shut_down") or (c.powered_down and "powered_down")
                                           or (c.dead and "wrecked") or "standing" })
        elseif c.side == "party" then
            table.insert(out.heroes, { id = c.mini, name = c.name, hp = math.max(0, c.hp or 0), hp_max = c.hp_max,
                                       hits = st.hits or 0, swings = (st.hits or 0) + (st.misses or 0),
                                       dealt = st.dealt or 0, beaten = st.kills or 0, downs = st.downs or 0,
                                       dead = c.dead or nil })
        elseif c.dead then
            table.insert(out.beaten, c.name)
        elseif c.removed then
            table.insert(out.ran, c.name)
            out.ran_said = out.ran_said or {}
            table.insert(out.ran_said, util.capitalize(require("game.model.barks").foe_label(c) or c.name))
        end
        if c == f.boss then
            out.boss = { name = c.name, state = c.dead and "beaten" or (c.removed and "gone") or "standing",
                         hp = math.max(0, c.hp or 0), hp_max = c.hp_max }
        end
        -- Still stone when it ended (Euryale won): who.
        if c.side == "party" and not c.dead and b.any_effect and b:any_effect(c, "stone") then
            out.stone = out.stone or {}
            table.insert(out.stone, { id = c.mini, name = c.name })
        end
        if c.removed and c.removed_why == "morale" then
            out.fled = out.fled or {}
            table.insert(out.fled, c.name)
        end
    end
    if f.moments then
        out.moments = f.moments
    end
    return out
end

-- A foe stared down before the fight goes for whoever did it (fight.run): said by the foe's own pronoun
-- and the name the table calls it (the room's boss_name for its boss, never the mat's label). Round
-- three's merge heard "The Lecturer can't take its eyes off Oswin", and "it's Oswin it wants" of Euryale.
-- util.pronoun_of, MODULE.foe_pronouns.
function M.stare_line(night, lead, pc, is_boss)
    local sc = night and night.scene
    local foe = util.capitalize((is_boss and sc and sc.boss_name) or barks.foe_label(lead) or "It")
    -- (One foe with no pronoun of its own is "it", as barks.lua has it: the fourth playtest heard "The bed dragon can't
    -- take their eyes off Brannoc... it's Brannoc they want". A person keeps theirs: "his eyes", "her eyes".)
    local pr = util.pronoun_of(foe)
    if pr.they == "they" then
        pr = util.PRONOUNS.it or { they = "it", their = "its" }
    end
    return util.fill("{Foe} can't take {foe_their} eyes off {char}. For the next few rounds, it's {char} {foe_they} wants.",
        { foe = foe, Foe = foe, char = pc.name, foe_their = pr.their, foe_they = pr.they })
end

return M
