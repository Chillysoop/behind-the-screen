-- Death in Space's fights on game night: the party's numbers from their sheets, the room's foes from the adventure's
-- creatures, where everyone stands on the room's board, and the fight itself (game/rules/dis/battle.lua) told to the
-- table step by step, the way game night tells any grid fight (turns of steps: moves, attacks, damage, downs). The
-- shared game reaches it as the set's "fight" part (game/model/ruleset.lua): party, plan, run, and what carries
-- between nights (save_state, load_state). Pure Lua.

local battle = require "game.rules.dis.battle"

local M = {}

local function lazy(name)
    return package.loaded[name] or require(name)
end

local function set()
    return lazy("game.model.ruleset").current()
end

-- The hero record for a player: the adventure's crew member, or the one who took their place.
local function hero_of(campaign, key)
    return set().hero_of(campaign, key)
end

-- A gun reaches; anything else is a hand weapon.
local function weapons_of(list)
    local out = {}
    for _, w in ipairs(list or {}) do
        table.insert(out, { name = w.name, damage = w.damage or "1d4", ranged = w.ranged and true or false, uses = w.uses })
    end
    if #out == 0 then
        out[1] = { name = "bare hands", damage = "1d2", ranged = false }
    end
    return out
end

-- (How keen a player is to take a risky attack: the ones here for the fight, more.)
local RISKY = { butt_kicker = 0.35, instigator = 0.3, power_gamer = 0.2, tactician = 0.1 }

function M.party(night)
    if night.pcs then
        return night.pcs
    end
    local camp = night.campaign
    night.pcs, night.pc_list = {}, {}
    for _, p in ipairs(night.players) do
        local h = hero_of(camp, p.key)
        local s = h and h.sheet
        if s then
            local c = { side = "party", pc = true, player_key = p.key, mini = p.key, name = p.char, class = p.class,
                        hp = s.hp, hp_max = s.hp, dr = s.dr, bdy = s.bdy, dex = s.dex, svy = s.svy, tec = s.tec,
                        weapons = weapons_of(h.weapons), risky = RISKY[p.primary] or 0.05 }
            night.pcs[p.key] = c
            table.insert(night.pc_list, c)
        end
    end
    M.load_state(night)
    return night.pcs
end

-- Where they left off: hurt stays hurt between nights until they rest.
function M.load_state(night)
    local st = night.campaign.party_state
    if not st or st.rested or st.rules ~= "dis" then
        return false
    end
    for _, c in ipairs(night.pc_list or {}) do
        local s = st.pcs and st.pcs[c.player_key]
        if s and s.hp then
            c.hp = math.min(c.hp_max, math.max(1, s.hp))
        end
    end
    return true
end

function M.save_state(night, rested)
    local camp = night.campaign
    local st = { rules = "dis", rested = rested and true or false, week = camp.week, pcs = {} }
    for _, c in ipairs(night.pc_list or {}) do
        st.pcs[c.player_key] = { hp = math.max(1, c.hp or 1), hp_max = c.hp_max }
    end
    camp.party_state = st
end

function M.prebuff()
end

function M.buff_line()
    return ""
end

-- A rest (p. 54): a full night's sleep with food heals 1d8 plus Body; in the hub, everything. A breather heals nothing.
function M.rest(night, long, in_hub)
    local healed = 0
    if not long then
        return 0
    end
    for _, c in ipairs(night.pc_list or {}) do
        if not c.dead then
            local before = c.hp
            if in_hub then
                c.hp = c.hp_max
            else
                c.hp = math.min(c.hp_max, math.max(1, c.hp) + math.max(1, night.rng:int(1, 8) + (c.bdy or 0)))
            end
            c.down, c.stable = false, nil
            healed = healed + (c.hp - before)
        end
    end
    return healed
end

function M.lift(s)
    return (string.gsub(s or "They", "^%l", string.upper))
end

function M.plan(night, sc)
    local e = sc.encounter or {}
    local ids = e.ids or {}
    -- (The leader's crew, as the table calls them, in their own capitals: "two UWA thugs".)
    local monsters = lazy("game.model.ruleset").engine("data.monsters")
    local crew = ids[2] and monsters[ids[2]] and monsters[ids[2]].name or nil
    for i = 3, #ids do
        if not (monsters[ids[i]] and monsters[ids[i]].name == crew) then
            crew = nil
        end
    end
    return { ids = ids, boss_name = e.boss_name or sc.boss_name, meter = {}, crew = crew }
end

local function fill_line(night, list, key, vars)
    return lazy("game.model.util").fill(night:fresh(list, key), vars)
end

-- The engine's events as the steps game night shows (the same shapes as any grid fight's).
local function step(night, ev)
    local k = ev.kind
    local function id(c)
        return c and c.mini
    end
    if k == "move" then
        local path = {}
        for _, sq in ipairs(ev.path) do
            table.insert(path, { sq[1], sq[2] })
        end
        return { kind = "move", id = id(ev.who), path = path }
    elseif k == "attack" then
        return { kind = "attack", id = id(ev.att), target = id(ev.tgt), roll = ev.roll, other = ev.other, bonus = ev.bonus,
                 total = ev.total, dr = ev.dr, hit = ev.hit, crit = ev.crit, risky = ev.risky, counter = ev.counter,
                 ranged = ev.ranged, weapon = ev.weapon, dmg = ev.dmg, cover_what = ev.cover ~= true and ev.cover or nil,
                 cover = ev.cover and true or nil, edge = ev.edge, dm = ev.att.side ~= "party" }
    elseif k == "damage" then
        return { kind = "damage", id = id(ev.tgt), amount = ev.amount, hp = ev.hp, hp_max = ev.hp_max, crit = ev.crit,
                 src = ev.src and id(ev.src) or nil }
    elseif k == "death_check" then
        return { kind = "death_check", id = id(ev.who), roll = ev.roll, other = ev.other, bonus = ev.bonus, total = ev.total,
                 ok = ev.ok }
    elseif k == "reload" then
        return { kind = "reload", id = id(ev.who), weapon = ev.weapon }
    elseif k == "yield" or k == "flee" then
        return { kind = k, id = id(ev.who), how = ev.how }
    elseif k == "morale" then
        return { kind = "morale", id = id(ev.who), roll = ev.roll, ml = ev.ml, broke = ev.broke, why = ev.why }
    elseif k == "void" then
        local W = set().words
        local text = fill_line(night, W[ev.say.kind], ev.say.kind, ev.say.vars)
        return { kind = "void", id = id(ev.who), text = text }
    end
    return { kind = k, id = id(ev.who) }
end

-- Where they stand: the room's board says where the party and the foes start.
local function stand(night, sc, b, party, foes)
    local placement = lazy("game.model.placement")
    local content = lazy("game.model.content")
    local blocked, layout = placement.blocked_set(sc.terrain, night:map_for(sc))
    local W, H = content.terrain_layout.W, content.terrain_layout.H
    local taken = {}
    local ps = placement.squares_shown(blocked, taken, layout.party[1], layout.party[2], #party, W, H, nil, layout.occ, nil, layout.doors)
    local fa = layout.foes or { W - 3, math.floor(H / 2) }
    local fs = placement.squares_shown(blocked, taken, fa[1], fa[2], #foes, W, H, ps, layout.occ, nil, layout.doors)
    for i, c in ipairs(party) do
        local sq = ps[i] or { 2, i + 2 }
        b:add(c, sq[1], sq[2])
    end
    for i, c in ipairs(foes) do
        local sq = fs[i] or { W - 2, i + 2 }
        b:add(c, sq[1], sq[2])
    end
end

function M.board_for(night, sc)
    local placement = lazy("game.model.placement")
    local content = lazy("game.model.content")
    local blocked, _, extras = placement.blocked_set(sc.terrain, night:map_for(sc))
    local doors = {}
    for _, d in ipairs(extras.doors or {}) do
        doors[d.x .. "," .. d.y] = { state = d.state, x = d.x, y = d.y, fid = d.fid }
    end
    return { W = content.terrain_layout.W, H = content.terrain_layout.H, solid = blocked, walls = extras.opaque or {},
             cover = extras.cover or {}, doors = doors }
end

function M.run(night, sc, plan)
    local monsters = lazy("game.model.ruleset").engine("data.monsters")
    local spec = M.board_for(night, sc)
    -- Who started it: an ambush, the foes; a party that crept up, the party; otherwise the dice (p. 52).
    local first = (sc.surprise == "party" and "foes") or (sc.surprise == "foes" and "party")
        or (night.rng:chance(0.5) and "party" or "foes")
    spec.rng, spec.set, spec.campaign, spec.first = night.rng, set(), night.campaign, first
    local b = battle.new(spec)
    -- Foes who break (p. 53): surrender, run, or ask to talk. The DM's call, on a card, while there's room for one
    -- (Conner, November 7); past the night's calls, as the moment says: a leader asks to talk, the rest run.
    b.on_morale = function(_, c)
        local auto = c.boss and "parley" or "flee"
        if not night:room(13) then
            return auto
        end
        night:flush_turn()
        local who = c.boss and plan.boss_name or c.name
        local card = { id = "dis_morale", type = "combat", title = M.lift(who) .. " breaks", trigger = "dis_morale",
                       text = M.lift(who) .. " has had enough: the morale roll went against them. What do they do?",
                       options = {
                           { label = "They surrender.", effects = { { "all", reward = 2 } }, outcome = "surrender" },
                           { label = "They run for it.", effects = { { "arch:butt_kicker", challenge = -1 } }, outcome = "flee" },
                           { label = "They want to talk.", effects = { { "arch:storyteller", story = 2 } }, outcome = "parley" },
                       } }
        local o = night:decision(card)
        return o and o.outcome or auto
    end
    local party = {}
    for _, p in ipairs(night.players) do
        local c = night.pcs and night.pcs[p.key]
        if c and not c.dead then
            c.down, c.stable, c.x, c.y = nil, nil, nil, nil
            c.stats = nil
            -- (A full clip for every fight: the ammo clips aren't counted yet.)
            for _, w in ipairs(c.weapons or {}) do
                w.left = nil
            end
            table.insert(party, c)
        end
    end
    local foes = {}
    for i, mid in ipairs(plan.ids or {}) do
        local m = monsters[mid] or {}
        local ab = m.abilities or {}
        table.insert(foes, { side = "foes", mini = "f" .. i, monster_id = mid, name = m.name or mid, short = m.short,
                             hp = m.hp or 4, hp_max = m.hp or 4, dr = m.dr or 12, bdy = ab.bdy or 0, dex = ab.dex or 0,
                             svy = ab.svy or 0, tec = ab.tec or 0, ml = m.morale, boss = i == 1 or nil,
                             weapons = weapons_of(m.weapon and { m.weapon } or m.weapons) })
    end
    stand(night, sc, b, party, foes)
    local f = { by_ref = {}, boss = foes[1], boss_name = plan.boss_name }
    for _, c in ipairs(b.creatures) do
        f.by_ref[c.mini] = c
    end
    local party_out, foes_out = {}, {}
    for _, c in ipairs(party) do
        table.insert(party_out, { id = c.mini, x = c.x, y = c.y, class = c.class, hp = c.hp, hp_max = c.hp_max })
    end
    for _, c in ipairs(foes) do
        table.insert(foes_out, { id = c.mini, monster = c.monster_id, name = c.name, x = c.x, y = c.y, boss = c.boss,
                                 hp = c.hp, hp_max = c.hp_max, cast = c.boss and sc.comps and sc.comps.cast and sc.comps.cast.id or nil })
    end
    night.battle = b
    night:emit({ kind = "battle", phase = "start", party = party_out, foes = foes_out, terrain = sc.terrain,
                 ambushed = sc.surprise == "party" or nil })
    -- (Every turn's steps go out together, as the next turn starts. First, who's in it, the side that started first.)
    local order = {}
    for _, side in ipairs(first == "party" and { party, foes } or { foes, party }) do
        for _, c in ipairs(side) do
            table.insert(order, { id = c.mini, name = c.name, side = c.side, pc = c.pc })
        end
    end
    night.turn_steps, night.turn_who = { { kind = "initiative", order = order } }, nil
    b.on_event = function(_, ev)
        if ev.kind == "turn" then
            night:flush_turn()
            night.turn_who = ev.who
        elseif ev.kind == "round" then
            night:flush_turn()
            night.turn_who = nil
            night:emit({ kind = "round", round = ev.round })
        else
            table.insert(night.turn_steps, step(night, ev))
        end
    end
    local result = b:run()
    night:flush_turn()
    f.yielded = b.yielded ~= nil
    if f.yielded then
        result.winner = "party"
    end
    local downs = 0
    for _, c in ipairs(party) do
        downs = downs + (c.stats.downs or 0)
    end
    result.pc_downs = downs
    night.battle = nil
    night.fights = (night.fights or 0) + 1
    night.mini_pos = night.mini_pos or {}
    for _, c in ipairs(party) do
        if c.x and not c.dead then
            night.mini_pos[c.mini] = { c.x, c.y }
        end
    end
    night:emit({ kind = "battle", phase = "end", winner = result.winner, rounds = result.rounds, summary = M.summary(b, f, result) })
    return result, f
end

-- How it went, for the card when it's over (the shape every grid fight's card reads).
function M.summary(b, f, result)
    local how = result.winner ~= "party" and "lost" or (f.yielded and "yielded") or "won"
    local out = { how = how, rounds = result.rounds or b.round, heroes = {}, beaten = {}, ran = {} }
    for _, c in ipairs(b.creatures) do
        local st = c.stats or {}
        if c.side == "party" then
            table.insert(out.heroes, { id = c.mini, name = c.name, hp = math.max(0, c.hp or 0), hp_max = c.hp_max,
                                       hits = st.hits or 0, swings = (st.hits or 0) + (st.misses or 0), dealt = st.dealt or 0,
                                       beaten = st.kills or 0, downs = st.downs or 0, dead = c.dead or nil })
        elseif c.dead then
            table.insert(out.beaten, c.name)
        elseif c.removed then
            table.insert(out.ran, c.name)
            if c.removed_why == "morale" then
                out.fled = out.fled or {}
                table.insert(out.fled, c.name)
            end
        end
        if c == f.boss then
            out.boss = { name = c.name, state = c.dead and "beaten" or (c.removed and "gone") or "standing",
                         hp = math.max(0, c.hp or 0), hp_max = c.hp_max }
        end
    end
    if #out.ran > 0 and how == "won" and #out.beaten == 0 then
        out.how = "fled"
    end
    return out
end

return M
