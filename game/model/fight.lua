-- Fights on game night: builds the encounter from the scene card, runs it on the
-- M3 rules engine turn by turn, and turns the engine's events into beats for the
-- table (minis moving, dice in the strip, speech bubbles). The DM's decision cards
-- arrive at the moments the fight creates: a crit about to end the boss in round
-- one, a hidden roll that would drop a hero, a fight dragging on. Pure Lua.

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

local M = {}

local HUMANOID_BOSS = { bandit_captain = true, tough = true, goblin_boss = true, cultist = true, bandit = true }

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

function M.blocked_set(set_name)
    local layout = content.terrain_layout.sets[set_name] or content.terrain_layout.sets.blank
    local blocked = {}
    for _, sq in ipairs(layout.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    return blocked, layout
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
    local built = party_mod.build(camp.level or 2, camp.subclasses)
    night.pcs, night.pc_list = {}, {}
    for _, c in ipairs(built) do
        for _, p in ipairs(night.players) do
            if p.class == c.class then
                c.player_key = p.key
                c.mini = p.key
                night.pcs[p.key] = c
                table.insert(night.pc_list, c)
            end
        end
    end
    -- Eight-hour buffs go up before the night starts (Mage Armor, Aid).
    local b = battle.new({ seed = night.rng:int(1, 2147483000), ai = ai })
    if #night.pc_list > 0 then
        local filler = {}
        for i = 1, 4 do
            filler[i] = night.pc_list[((i - 1) % #night.pc_list) + 1]
        end
        encounter.prebuff(b, filler)
    end
    return night.pcs
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
end

-- After a fight: a short rest. Everyone gets back half of what they lost.
function M.short_rest(night)
    for _, c in ipairs(night.pc_list or {}) do
        if not c.dead then
            c.down = false
            c.hp = math.max(1, c.hp)
            c.hp = c.hp + math.ceil((c.hp_max - c.hp) / 2)
        end
    end
end

-- The encounter ------------------------------------------------------------------------------

-- Build the fight with the difficulty meter (M3): add monsters until the meter's
-- "someone drops" forecast reaches what the scene asks for. Cozy by default:
-- an easy scene aims low, a hard one or a set piece aims for real danger.
M.AIM = { 0.3, 0.5, 0.68 }

-- Which monsters a scene brings: its cast's, else its location's, else the default.
function M.family(sc)
    local enc = content.encounters
    local cast = sc.comps and sc.comps.cast
    local loc = sc.comps and sc.comps.location
    return (cast and enc.by_cast[cast.id]) or (loc and enc.by_location[loc.id]) or enc.default
end

-- The fight a scene suggests (what game night builds if the DM doesn't build their own):
-- add monsters until the meter's "someone drops" forecast reaches what the scene asks for.
-- scene: { comps, type, difficulty }; level, n: the party's level and size.
function M.suggest(sc, level, n)
    local enc = content.encounters
    local fam = M.family(sc)
    local step = util.clamp(sc.difficulty or 2, 1, 3) + ((sc.type == "set_piece") and 1 or 0)
    local aim = M.AIM[util.clamp(step, 1, 3)]
    local ids = { fam.boss }
    local k = 0
    while #ids < enc.max_monsters do
        local id = fam.minion[(k % #fam.minion) + 1]
        local try = {}
        for _, x in ipairs(ids) do
            table.insert(try, x)
        end
        table.insert(try, id)
        local m = encounter.meter(level, n, try)
        if not m.someone_drops or m.someone_drops > aim then
            break
        end
        ids = try
        k = k + 1
    end
    return ids, fam, aim
end

function M.plan(night, sc)
    local enc = content.encounters
    local cast = sc.comps.cast
    local loc = sc.comps.location
    local fam = M.family(sc)
    local level = night.campaign.level or 2
    local n = math.max(1, #night.pc_list)
    -- The DM built this fight in prep (the encounter builder): use it as built.
    if sc.encounter and sc.encounter.ids and #sc.encounter.ids > 0 then
        local ids = {}
        for _, id in ipairs(sc.encounter.ids) do
            table.insert(ids, id)
        end
        local meter = encounter.meter(level, n, ids)
        return { ids = ids, boss_name = sc.encounter.boss_name or fam.name, aim = 0, meter = meter,
                 cast = cast and enc.by_cast[cast.id] and cast.id, built = true }
    end
    local ids, _, aim = M.suggest(sc, level, n)
    local meter = encounter.meter(level, n, ids)
    return { ids = ids, boss_name = fam.name, aim = aim, meter = meter, cast = cast and enc.by_cast[cast.id] and cast.id }
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
        s.dmg, s.to_hit = ev.dmg, ev.to_hit
        s.dm = ev.att.side ~= "party"
        s.hidden = s.dm and night.dm_rolls == "hidden"
        s.mode = ev.mode
    elseif k == "damage" then
        s.id, s.amount, s.hp, s.hp_max, s.crit = ref(ev.tgt), ev.amount, ev.hp, ev.hp_max, ev.crit
    elseif k == "heal" then
        s.id, s.amount, s.hp, s.hp_max = ref(ev.tgt), ev.amount, ev.hp, ev.hp_max
        s.by = ev.src and ref(ev.src)
    elseif k == "spell" then
        s.id, s.name, s.spell, s.target = ref(ev.caster), ev.name, ev.id, target_ref(ev.target)
        s.reaction = ev.reaction
        s.level = ev.slot
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
    elseif k == "save" then
        s.id, s.ok, s.roll, s.dc, s.total, s.ab = ref(ev.who), ev.ok, ev.roll, ev.dc, ev.total, ev.ab
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

-- Barks and poses after a turn, from what happened in it.
local function react(night, f, steps, who)
    local P = player_of(night, who)
    local poses, line = {}, nil
    local crit, kill, downed, hurt, healed_up, boss_dead = false, false, nil, nil, nil, false
    local kill_name
    for _, s in ipairs(steps) do
        if s.kind == "attack" and s.crit and not s.dm then
            crit = true
        elseif s.kind == "death" then
            local c = f.by_ref[s.id]
            if c and c.side == "foes" then
                kill = true
                kill_name = c.name
                if c.boss then
                    boss_dead = true
                end
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
        end
    end
    if downed and downed.pc then
        local victim = player_of(night, downed)
        if victim then
            poses[victim.key] = "gasp"
            line = { victim, "down_self" }
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
            if p.class == "cleric" and p ~= victim then
                medic = p
            end
        end
        if medic and night.rng:chance(0.6) then
            line = { medic, "ally_down", { other_char = downed.name, other = victim and victim.name,
                                           other_key = victim and victim.key } }
        end
    elseif boss_dead then
        for _, p in ipairs(night.players) do
            poses[p.key] = "cheer"
        end
        -- The villain gets a last word, played for fun.
        if night.scene and night.scene.comps.cast then
            night:npc_line("down")
        end
        if P then
            line = { P, "kill" }
            night:highlight(8, P.char .. " brings down " .. (f.boss_name or "the boss"), { P })
        end
    elseif crit and P then
        poses[P.key] = "cheer"
        line = { P, "crit" }
        night:highlight(6, P.char .. " lands a critical hit", { P })
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
            line = { back, night.rng:chance(0.5) and "up_again" or "thanks" }
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
        night:bark(line[1], line[2], line[3])
    end
    if crit and P and not boss_dead then
        night:table_behavior("after_crit", P)
    end
end

-- The DM's call on a moment the fight created. Returns the chosen option.
local MAX_CARDS_PER_FIGHT = 3

local function moment(night, f, trigger, vars, actor_c, other_c)
    local card = content.triggered[trigger]
    if not card or f.used[trigger] then
        return nil
    end
    f.cards = f.cards or 0
    if f.cards >= MAX_CARDS_PER_FIGHT or night:decision_count() >= 15 then
        return nil
    end
    f.cards = f.cards + 1
    f.used[trigger] = true
    night:flush_turn()
    night.actor = player_of(night, actor_c) or night:pick_actor(card.actor)
    night.other = player_of(night, other_c)
    if not night.other then
        night.other = night:pick_actor(card.other, night.actor)
    end
    return night:decision(card, vars)
end

local function spawn_reinforcements(night, f, b)
    local fam = f.plan_fam
    local id = fam and fam.minion and fam.minion[1] or "goblin_warrior"
    local taken = {}
    for _, c in ipairs(b.creatures) do
        if not c.dead and not c.removed then
            taken[c.x * 1000 + c.y] = true
        end
    end
    local spots = M.squares_near(f.blocked, taken, f.layout.foes[1] + 2, f.layout.foes[2], 3, 1, b.W, b.H)
    for _, sq in ipairs(spots) do
        f.count = f.count + 1
        local m = creature.new_monster(id, " " .. f.count)
        m.mini = "f" .. f.count
        f.by_ref[m.mini] = m
        b:join(m, sq[1], sq[2])
    end
end

-- Run the fight for a combat or set-piece scene.
function M.run(night, sc, plan)
    local pcs = M.party(night)
    local set_name = sc.terrain
    local blocked, layout = M.blocked_set(set_name)
    local f = { used = {}, by_ref = {}, count = 0, blocked = blocked, layout = layout, boss_name = plan.boss_name }
    local enc = content.encounters
    f.plan_fam = (sc.comps.cast and enc.by_cast[sc.comps.cast.id]) or (sc.comps.location and enc.by_location[sc.comps.location.id])
        or enc.default
    local b = battle.new({ seed = night.rng:int(1, 2147483000), ai = ai, width = content.terrain_layout.W,
                           height = content.terrain_layout.H, blocked = blocked })
    night.battle = b
    local taken = {}
    local party_spots = M.squares_near(blocked, taken, layout.party[1], layout.party[2], #night.pc_list, 1, b.W, b.H)
    local party_out = {}
    for i, c in ipairs(night.pc_list) do
        if not c.dead then
            ready_for_battle(c)
            local sq = party_spots[i] or { 2, i + 3 }
            b:add(c, sq[1], sq[2])
            f.by_ref[c.mini] = c
            table.insert(party_out, { id = c.mini, x = sq[1], y = sq[2], class = c.class, hp = c.hp, hp_max = c.hp_max })
        end
    end
    local foe_spots = M.squares_near(blocked, taken, layout.foes[1], layout.foes[2], #plan.ids, 2, b.W, b.H)
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
        end
        local sq = foe_spots[i] or { b.W - 1, i }
        b:add(m, sq[1], sq[2])
        f.by_ref[m.mini] = m
        table.insert(foes_out, { id = m.mini, monster = id, x = sq[1], y = sq[2], name = m.name, boss = m.boss,
                                 hp = m.hp, hp_max = m.hp_max })
    end
    f.boss = b.creatures[#party_out + 1]
    -- Surprise from the scouting roll: Disadvantage on Initiative (p. 13).
    for _, c in ipairs(b.creatures) do
        c.surprised = (sc.surprise == "foes" and c.side == "foes") or (sc.surprise == "party" and c.side == "party") or nil
    end
    night:emit({ kind = "battle", phase = "start", party = party_out, foes = foes_out, terrain = set_name,
                 danger = plan.meter.danger, srd = plan.meter.srd })

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
        if ev.kind == "attack" and ev.att.side ~= "party" and ev.roll then
            if night.dm_rolls == "hidden" then
                night.hidden_dm_rolls = night.hidden_dm_rolls + 1
            else
                night.open_dm_rolls = night.open_dm_rolls + 1
            end
        end
    end

    -- Damage the DM can still overrule.
    b.hooks.before_damage = function(bb, src, tgt, total, info)
        if not src or info.bond then
            return total
        end
        -- The boss is about to go down early.
        if tgt.boss and src.side == "party" and bb.round <= 2 and total >= tgt.hp and not tgt.dead and not f.used.boss_crit then
            local o = moment(night, f, "boss_crit", { boss = f.boss_name, round = bb.round }, src)
            if o and o.battle == "second_phase" then
                tgt.hp = total + math.floor(tgt.hp_max * 0.5)
                tgt.phase2 = true
                table.insert(night.turn_steps, { kind = "feature", id = tgt.mini, name = "Second phase" })
            elseif o and o.battle == "reinforce" then
                spawn_reinforcements(night, f, bb)
            end
            return total
        end
        -- A hidden monster hit would drop a hero.
        if src.side == "foes" and tgt.pc and not tgt.down and total >= tgt.hp + tgt.temp and night.dm_rolls == "hidden"
            and not f.used.death_roll then
            local o = moment(night, f, "death_roll", { target = src.name, damage = util.int(total) }, tgt)
            if o and o.battle == "fudge_miss" then
                table.insert(night.turn_steps, { kind = "feature", id = tgt.mini, name = "It glances off" })
                return 0
            elseif o and o.battle == "deal" then
                return math.max(0, tgt.hp + tgt.temp - 1)
            end
        end
        return total
    end

    -- The last death save.
    b.hooks.before_pc_death = function(bb, c, why)
        if f.used.last_save then
            return nil
        end
        local o = moment(night, f, "last_save", { location = sc.comps.location and sc.comps.location.name or "the table" }, c)
        if o and o.battle == "fudge_save" then
            return "stable"
        elseif o and o.battle == "miracle" then
            return "revive"
        end
        return nil
    end

    local opts = {}
    opts.before_round = function(bb, r)
        night:flush_turn()
        night:emit({ kind = "round", round = r })
        -- Table chatter and the villain's taunts between rounds.
        if r >= 2 and night.rng:chance(night:idle() > 60 and 0.12 or 0.3) then
            -- Sometimes it's a habit of theirs (A12): backseat tactics, HP fishing, the spell lookup.
            if not (night.rng:chance(0.5) and night:table_behavior("combat", nil, true)) then
                night:bark(night.rng:pick(night.players), "fight_chat")
            end
        end
        if r >= 2 and r % 2 == 0 and f.boss and not f.boss.dead and plan.cast then
            night:npc_line("taunt")
        end
        -- A rules question comes up mid-fight.
        if r == 2 and sc.rules_card and night:decision_count() < 14 then
            night.actor = night:pick_actor(sc.rules_card.actor)
            night:decision(sc.rules_card)
            sc.rules_card = nil
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
                    big_char = big.name, big = bigp and bigp.name or big.name })
                if o and o.battle then
                    bb.focus = o.battle
                end
            end
        end
        -- The boss is beaten and backed into a corner: talk?
        local boss = f.boss
        if boss and not boss.dead and not boss.removed and HUMANOID_BOSS[boss.monster_id] and boss.hp <= boss.hp_max * 0.4
            and alive_foes(bb) >= 1 and not f.used.parley and night.rng:chance(0.6) and night:decision_count() < 14 then
            local o = moment(night, f, "parley", { boss = f.boss_name })
            if o and o.battle == "surrender" then
                for _, c in ipairs(bb.creatures) do
                    if c.side == "foes" and not c.dead and not c.removed then
                        bb:remove(c, "surrender")
                    end
                end
                bb.force_end = "party"
                f.surrendered = true
            end
        end
        -- Round six and counting (or a long stretch with nothing for the DM to do).
        if (r >= 6 or (r >= 4 and night:idle() > 70)) and alive_foes(bb) >= 1 and not f.used.dragging and not bb.force_end then
            local o = moment(night, f, "dragging", { round = r })
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
    opts.after_turn = function(bb, c)
        local steps = night:flush_turn()
        if steps and #steps > 0 then
            react(night, f, steps, c)
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

    local result = b:run(opts)
    night:flush_turn()
    if f.surrendered or f.fled then
        result.winner = "party"
    end
    night.battle = nil
    night.fights = night.fights + 1
    night:emit({ kind = "battle", phase = "end", winner = result.winner, rounds = result.rounds })
    return result, f
end

return M
