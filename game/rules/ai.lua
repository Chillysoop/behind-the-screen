-- Tactics for both sides of the table. Players play their characters the way
-- a reasonable person at the table would; monsters fight like their stat block
-- suggests (goblins skirmish, wolves gang up, the ogre swings at whoever's close).
-- Kept deliberately simple and readable: this drives balance numbers, not drama.

local creature = require "game.rules.creature"
local spells = require "game.rules.spells"
local equipment = require "game.rules.data.equipment"

local AI = {}

local abmod = creature.abmod
local S = spells.list

-- Profiles ---------------------------------------------------------------------------------

local function unarmed(c)
    return { id = "unarmed", name = "Unarmed Strike", is_weapon = true, kind = "melee",
             to_hit = abmod(c, "str") + c.pb, damage = { { 0, 0, 1 + abmod(c, "str"), "bludgeoning" } },
             reach = 5, crit_range = c.crit_range or 20 }
end

function AI.melee_profile(b, c)
    if c.pc then
        local main = c.weapons.main
        if main then
            local p = creature.weapon_attack(c, main, { two_handed = c.weapons.two_handed })
            if p.kind == "melee" then
                return p
            end
        end
        return unarmed(c)
    end
    for _, a in ipairs(c.attacks or {}) do
        if a.kind == "melee" or a.kind == "both" then
            return creature.monster_attack(c, a)
        end
    end
    return nil
end

-- Targets and positions ---------------------------------------------------------------------

local function by_distance(b, c, list)
    table.sort(list, function(x, y)
        local dx, dy = b:dist(c, x), b:dist(c, y)
        if dx ~= dy then return dx < dy end
        if x.hp ~= y.hp then return x.hp < y.hp end
        return x.uid < y.uid
    end)
    return list
end

local function enemies(b, c)
    return b:enemies_of(c)
end

local function adjacent_enemies(b, c, x, y, list)
    local n = 0
    for _, e in ipairs(list or enemies(b, c)) do
        if b:dist_xy(e.x, e.y, x or c.x, y or c.y) <= 5 and not b:incapacitated(e) then
            n = n + 1
        end
    end
    return n
end

-- Move next to a target, picking a square that's reachable now and keeps us out of
-- extra enemies' reach. Returns true if we end within `reach` of the target.
local function approach(b, c, t, reach)
    reach = reach or 5
    if b:dist(c, t) <= reach then
        return true
    end
    if c.turn.move <= 0 then
        return false
    end
    local foes = enemies(b, c)
    local x, y = b:best_square(c, c.turn.move, function(x, y)
        local d = b:dist_xy(x, y, t.x, t.y)
        local s = -d
        if d <= reach then
            s = 1000 - adjacent_enemies(b, c, x, y, foes) * 3
        end
        return s
    end)
    if x then
        b:move_to(c, x, y)
    end
    return not c.dead and not c.down and b:dist(c, t) <= reach
end

-- Step away from enemies to a square at least `want` feet from all of them, if possible.
local function back_off(b, c, want, keep_in_range_of, range)
    if c.turn.move <= 0 then
        return
    end
    local foes = enemies(b, c)
    local x, y = b:best_square(c, c.turn.move, function(x, y)
        local nearest = math.huge
        for _, e in ipairs(foes) do
            nearest = math.min(nearest, b:dist_xy(x, y, e.x, e.y))
        end
        local s = math.min(nearest, want)
        if keep_in_range_of and b:dist_xy(x, y, keep_in_range_of.x, keep_in_range_of.y) > range then
            s = s - 100
        end
        return s
    end)
    if x then
        b:move_to(c, x, y)
    end
end

-- Get within range of a target without walking into melee.
local function get_in_range(b, c, t, range)
    if b:dist(c, t) <= range then
        return true
    end
    local foes = enemies(b, c)
    local x, y = b:best_square(c, c.turn.move, function(x, y)
        local d = b:dist_xy(x, y, t.x, t.y)
        local s = (d <= range) and 100 or -d
        s = s - adjacent_enemies(b, c, x, y, foes) * 20
        return s
    end)
    if x then
        b:move_to(c, x, y)
    end
    return not c.dead and b:dist(c, t) <= range
end

local function stand_if_prone(b, c)
    if b:has(c, "prone") and not c.down and c.turn.move >= math.floor(c.speed / 2) then
        b:stand_up(c)
        c.turn.move = c.turn.move - math.floor(c.speed / 2)
    end
end

-- Potions: drink or administer as a Bonus Action (p. 99).
local function potion_help(b, c)
    if not c.turn.bonus or (c.res.potions or 0) <= 0 then
        return false
    end
    -- A downed ally within reach first.
    for _, a in ipairs(b:allies_of(c, false, true)) do
        if a.down and not a.dead and b:dist(c, a) <= 5 + c.turn.move then
            if b:dist(c, a) > 5 then
                approach(b, c, a, 5)
            end
            if b:dist(c, a) <= 5 then
                c.res.potions = c.res.potions - 1
                c.turn.bonus = false
                b:log("%s pours a Potion of Healing into %s.", c.name, a.name)
                b:emit({ kind = "feature", who = c, name = "Potion of Healing", target = a })
                b:heal(c, a, b.dice:roll(2, 4) + 2)
                return true
            end
        end
    end
    if c.hp <= c.hp_max * 0.3 then
        c.res.potions = c.res.potions - 1
        c.turn.bonus = false
        b:log("%s drinks a Potion of Healing.", c.name)
        b:emit({ kind = "feature", who = c, name = "Potion of Healing", target = c })
        b:heal(c, c, b.dice:roll(2, 4) + 2)
        return true
    end
    return false
end

-- Spellcasting helpers ----------------------------------------------------------------------

-- One spell slot per turn (p. 105): free casts don't count against it.
local function slot_used_this_turn(c)
    local b = c.battle
    return b and b.turn_counter and c.slot_turn == b.turn_counter
end

-- Mirror Mage: one Quick Reflection per Long Rest needs no slot.
local function free_reflection(c, id)
    return id == "mirror_image" and c.sub and c.sub.quick_reflection and (c.res.qr_free or 0) > 0
end

local function can_cast(c, id)
    local s = S[id]
    if not s or not spells.has_spell(c, id) then
        return false
    end
    if s.level == 0 then
        return true
    end
    if c.mi_spell == id and (c.res.mi_free or 0) > 0 then
        return true
    end
    if free_reflection(c, id) then
        return true
    end
    if slot_used_this_turn(c) then
        return false
    end
    return spells.find_slot(c, s.level) ~= nil
end

-- Pay for a spell (free use first) and return the slot level it was cast at.
local function pay(c, id, prefer_level)
    local s = S[id]
    if s.level == 0 then
        return 0
    end
    if c.mi_spell == id and (c.res.mi_free or 0) > 0 then
        c.res.mi_free = c.res.mi_free - 1
        return s.level
    end
    if free_reflection(c, id) then
        c.res.qr_free = c.res.qr_free - 1
        return s.level
    end
    local slot = spells.find_slot(c, prefer_level or s.level)
    if not slot then
        slot = spells.find_slot(c, s.level)
    end
    spells.spend_slot(c, slot)
    if c.battle then
        c.slot_turn = c.battle.turn_counter
    end
    return slot
end

local function cast(b, c, id, target, prefer_level)
    local s = S[id]
    local slot = pay(c, id, prefer_level)
    if s.casting == "bonus" then
        c.turn.bonus = false
        c.turn.cast_bonus_spell = true
    elseif s.casting == "action" then
        c.turn.action = false
    end
    b:log("%s casts %s%s.", c.name, s.name, slot > 0 and (" (level " .. slot .. ")") or "")
    b:emit({ kind = "spell", caster = c, id = id, name = s.name, slot = slot, target = target })
    c.stats.spells = (c.stats.spells or 0) + 1
    local sanct = b:any_effect(c, "sanctuary_dc")
    if sanct then
        b:remove_effect(c, sanct, "cast")
    end
    s.cast(b, c, slot, target)
end

function AI.try_shield(b, tgt, att)
    if not tgt.pc or tgt.reaction_used or b:incapacitated(tgt) or not can_cast(tgt, "shield") then
        return false
    end
    tgt.reaction_used = true
    local slot = pay(tgt, "shield")
    b:log("%s casts Shield!", tgt.name)
    b:emit({ kind = "spell", caster = tgt, id = "shield", name = "Shield", slot = slot, target = tgt, reaction = true })
    S.shield.cast(b, tgt, slot)
    return true
end

function AI.try_shield_mm()
    return false
end

-- Save Shimmer for attacks that matter: a real threat, or when we're already hurt.
function AI.want_shimmer(b, tgt, att, prof)
    return (att.xp or 0) >= 100 or tgt.hp <= tgt.hp_max * 0.5
end

-- Area targeting: best point for an area spell. Returns point and (enemies, allies) hit.
local function best_area(b, c, id)
    local s = S[id]
    local kind, size = s.area[1], s.area[2]
    local best, be, ba = nil, 0, 0
    local function score(list)
        local e, a = 0, 0
        for _, o in ipairs(list) do
            if o.side == c.side then
                if o ~= c then a = a + 1 end
            elseif not o.down then
                e = e + 1
            end
        end
        return e, a
    end
    local candidates = {}
    if kind == "cone" or kind == "cube" then
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
            if kind == "cone" then
                table.insert(candidates, { x = c.x + d[1] * 3, y = c.y + d[2] * 3, list = spells.cone(b, c, c.x + d[1] * 3, c.y + d[2] * 3, size) })
            else
                local list = spells.cube_from(b, c, d[1], d[2], size)
                table.insert(candidates, { x = d[1], y = d[2], list = list })
            end
        end
    else
        for _, e in ipairs(enemies(b, c)) do
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local px, py = e.x + dx, e.y + dy
                    if b:dist_xy(c.x, c.y, px, py) <= s.range then
                        local list
                        if kind == "sphere" then
                            list = spells.sphere(b, px, py, size)
                        else
                            local n = math.floor(size / 5)
                            local cells = spells.square_cells(px, py, n)
                            list = {}
                            for _, o in ipairs(b.creatures) do
                                if not o.dead and cells[o.x .. "," .. o.y] then table.insert(list, o) end
                            end
                        end
                        table.insert(candidates, { x = px, y = py, list = list })
                    end
                end
            end
        end
    end
    for _, cand in ipairs(candidates) do
        local e, a = score(cand.list)
        if e - 2 * a > be - 2 * ba or (best == nil and e > 0) then
            best, be, ba = { x = cand.x, y = cand.y }, e, a
        end
    end
    return best, be, ba
end

-- Pick the enemy most worth hitting: can it drop? is it dangerous?
local function pick_target(b, c, list, expected)
    local best, bs = nil, -math.huge
    for _, e in ipairs(list) do
        local s = 0
        if e.hp <= (expected or 7) then s = s + 20 end
        s = s + (e.xp or 25) / 25
        s = s - e.hp / 10
        if b:has(e, "paralyzed") or b:has(e, "unconscious") then s = s - 5 end
        if s > bs then
            best, bs = e, s
        end
    end
    return best
end

-- Game night: the DM can tell the monsters who to go after (b.focus = "squishy" | "big" | "spread").
local function focus_target(b, c, foes, reach)
    local f = b.focus
    if not f then
        return nil
    end
    local best, bs
    for _, e in ipairs(foes) do
        if b:dist(c, e) <= (c.turn.move or 0) + reach then
            local s
            if f == "squishy" then
                s = -b:ac(e) * 2 - e.hp_max / 10
            elseif f == "big" then
                s = e.hp_max
            elseif f == "spread" then
                s = e.hp / math.max(1, e.hp_max) * 10
            end
            if s and (not bs or s > bs) then
                best, bs = e, s
            end
        end
    end
    return best
end

-- Monster turns --------------------------------------------------------------------------------

local function monster_attack_with(b, c, t, a, ranged)
    local prof = creature.monster_attack(c, a, ranged)
    if a.ammo then
        if (c.res.ammo[a.id] or 0) <= 0 and ranged then
            return false
        end
        if ranged then
            c.res.ammo[a.id] = c.res.ammo[a.id] - 1
        end
    end
    b:attack(c, t, prof)
    return true
end

local function find_attack(c, kind)
    for _, a in ipairs(c.attacks) do
        if kind == "melee" and (a.kind == "melee" or a.kind == "both") then return a end
        if kind == "ranged" and (a.kind == "ranged" or (a.kind == "both" and (c.res.ammo[a.id] or 0) > 0)) then return a end
    end
    return nil
end

local function monster_turn(b, c)
    -- Turned Undead flee and do nothing else.
    if b:find_effect(c, "Turned") then
        back_off(b, c, 60)
        return
    end
    -- Webbed: try to break free.
    local web = b:find_effect(c, "Webbed")
    if web then
        local total = b:check(c, "str", 0)
        c.turn.action = false
        if total >= web.web_dc then
            b:remove_effect(c, web, "escaped")
            b:log("%s tears free of the webs.", c.name)
            b:emit({ kind = "feature", who = c, name = "Breaks free" })
        else
            b:log("%s struggles in the webs.", c.name)
        end
        return
    end
    stand_if_prone(b, c)
    -- Wake a sleeping friend (smart humanoids).
    if c.type == "humanoid" or (c.tags and c.tags.goblinoid) then
        for _, a in ipairs(b:allies_of(c)) do
            local asleep = b:find_effect(a, "Asleep")
            if asleep and b:dist(c, a) <= 5 then
                b:remove_effect(a, asleep, "woken")
                b:log("%s shakes %s awake.", c.name, a.name)
                b:emit({ kind = "feature", who = c, name = "Wake up", target = a })
                return
            end
        end
    end
    local foes = enemies(b, c)
    if #foes == 0 then
        return
    end
    by_distance(b, c, foes)
    local melee = find_attack(c, "melee")
    local ranged = find_attack(c, "ranged")
    local nearest = foes[1]
    local count = c.multiattack and c.multiattack.count or 1
    local engaged = adjacent_enemies(b, c) > 0
    -- Skirmishers (goblins): Nimble Escape to disengage and shoot.
    if c.bonus_actions and c.bonus_actions.nimble_escape and ranged then
        if engaged then
            c.turn.disengaged = true
            c.turn.bonus = false
            back_off(b, c, 30)
        elseif b:dist(c, nearest) > ranged.range[1] then
            get_in_range(b, c, nearest, ranged.range[1])
        end
        foes = by_distance(b, c, enemies(b, c))
        local t = focus_target(b, c, foes, ranged.range[1]) or pick_target(b, c, foes, 6)
        for _ = 1, count do
            if not t or t.down or t.dead then
                foes = enemies(b, c)
                if #foes == 0 then return end
                t = pick_target(b, c, foes, 6)
            end
            if b:dist(c, t) <= 5 and melee and adjacent_enemies(b, c) > 0 then
                monster_attack_with(b, c, t, melee, false)
            else
                monster_attack_with(b, c, t, ranged, true)
            end
        end
        return
    end
    -- Everyone else: close in and hit; shoot if the target is out of reach.
    local t = focus_target(b, c, foes, (melee and melee.reach) or 5) or nearest
    -- Pack hunters prefer a target an ally is already on.
    if c.traits.pack_tactics then
        for _, f in ipairs(foes) do
            for _, a in ipairs(b:allies_of(c)) do
                if b:dist(a, f) <= 5 and b:dist(c, f) <= c.turn.move + 5 then
                    t = f
                    break
                end
            end
            if t ~= nearest then break end
        end
    end
    local reach = (melee and melee.reach) or 5
    local in_reach = melee and approach(b, c, t, reach)
    if c.dead or c.down then return end
    if not in_reach then
        -- Nothing in reach: shoot if possible, or Dash to close the gap.
        local near = by_distance(b, c, enemies(b, c))[1]
        if near and b:dist(c, near) <= reach and melee then
            t, in_reach = near, true
        elseif ranged and near and b:dist(c, near) <= ranged.range[2] then
            for _ = 1, count do
                if near.dead or near.down then break end
                if not monster_attack_with(b, c, near, ranged, true) then break end
            end
            return
        else
            c.turn.move = b:speed(c)       -- Dash
            if near then approach(b, c, near, reach) end
            return
        end
    end
    for i = 1, count do
        if t.dead or t.down then
            local near = by_distance(b, c, enemies(b, c))
            t = near[1]
            if not t or b:dist(c, t) > reach then
                return
            end
        end
        local a = melee
        -- Ghouls sometimes go for the paralysing claw when a friend can follow up.
        if c.monster_id == "ghoul" and i == 1 then
            local friend = false
            for _, o in ipairs(b:allies_of(c)) do
                if b:dist(o, t) <= 5 then friend = true end
            end
            if friend and not b:has(t, "paralyzed") and b.dice:chance(0.5) then
                for _, x in ipairs(c.attacks) do
                    if x.id == "claw" then a = x end
                end
                b:attack(c, t, creature.monster_attack(c, a))
                return
            end
        end
        monster_attack_with(b, c, t, a, false)
    end
end

-- Player turns -------------------------------------------------------------------------------

local function weapon_profile(c, kind)
    if kind == "melee" then
        return creature.weapon_attack(c, c.weapons.main, { two_handed = c.weapons.two_handed })
    elseif kind == "offhand" and c.weapons.offhand then
        return creature.weapon_attack(c, c.weapons.offhand, { offhand = true })
    elseif kind == "ranged" and c.weapons.ranged then
        return creature.weapon_attack(c, c.weapons.ranged)
    elseif kind == "thrown" and c.weapons.thrown and (c.res.thrown or 0) > 0 then
        return creature.weapon_attack(c, c.weapons.thrown, { thrown = true })
    end
    return nil
end

local function melee_target(b, c, foes, reach)
    -- Prefer something already in reach, then whatever is closest.
    local best, bs = nil, -math.huge
    for _, e in ipairs(foes) do
        local d = b:dist(c, e)
        local s = -d
        if d <= reach then s = s + 100 end
        if d <= reach + c.turn.move then s = s + 50 end
        if e.hp <= 8 then s = s + 5 end
        -- Protect squishy friends.
        for _, a in ipairs(b:allies_of(c)) do
            if (a.class == "wizard" or a.class == "cleric") and b:dist(a, e) <= 5 then s = s + 8 end
        end
        if s > bs then best, bs = e, s end
    end
    return best
end

local function attack_action(b, c, prof, t)
    b:attack(c, t, prof)
    c.turn.attacks = c.turn.attacks + 1
end

-- Fighter.
local function fighter_turn(b, c)
    stand_if_prone(b, c)
    -- Second Wind when hurt (Banner Captains keep one for orders).
    local keep = (c.sub and c.sub.battle_orders) and 1 or 0
    if c.turn.bonus and (c.res.second_wind or 0) > keep and c.hp <= c.hp_max * 0.5 then
        c.res.second_wind = c.res.second_wind - 1
        c.turn.bonus = false
        b:log("%s catches a Second Wind.", c.name)
        b:emit({ kind = "feature", who = c, name = "Second Wind", target = c })
        b:heal(c, c, b.dice:d(10) + c.level)
    end
    potion_help(b, c)
    local actions = 1
    while actions > 0 and not c.dead and not c.down do
        actions = actions - 1
        local foes = enemies(b, c)
        if #foes == 0 then return end
        local prof = weapon_profile(c, "melee")
        local t = melee_target(b, c, foes, prof.reach)
        local reached = approach(b, c, t, prof.reach)
        if reached then
            attack_action(b, c, prof, t)
        else
            -- Out of reach: Magic Missile (Spellguard), a thrown weapon, or the bow.
            do
                local r = weapon_profile(c, "thrown") or weapon_profile(c, "ranged")
                if r and b:dist(c, t) <= r.range[2] then
                    if r.id == c.weapons.thrown then c.res.thrown = c.res.thrown - 1 end
                    attack_action(b, c, r, t)
                else
                    c.turn.move = b:speed(c)
                    approach(b, c, t, prof.reach)
                end
            end
        end
        -- Champion: free half move after a crit (toward the next foe).
        if c.turn.free_move and c.turn.free_move > 0 then
            local nf = enemies(b, c)
            if #nf > 0 then
                by_distance(b, c, nf)
                if b:dist(c, nf[1]) > 5 then
                    local saved = c.turn.move
                    c.turn.move = c.turn.free_move
                    approach(b, c, nf[1], 5)
                    c.turn.move = saved
                end
            end
            c.turn.free_move = 0
        end
        -- Action Surge: use it early or when it can finish someone.
        if actions == 0 and (c.res.action_surge or 0) > 0 and #enemies(b, c) > 0
            and (b.round <= 2 or #enemies(b, c) >= 2) then
            c.res.action_surge = c.res.action_surge - 1
            b:log("%s surges into another action!", c.name)
            b:emit({ kind = "feature", who = c, name = "Action Surge" })
            actions = 1
        end
    end
    -- Banner Captain: Battle Orders with the Bonus Action.
    if c.sub and c.sub.battle_orders and c.turn.bonus and (c.res.second_wind or 0) > 0 then
        local best, bv = nil, 0
        for _, a in ipairs(b:allies_of(c)) do
            if not a.reaction_used and not b:incapacitated(a) and b:dist(a, c) <= 30 then
                local v = AI.order_value(b, a)
                if v > bv then best, bv = a, v end
            end
        end
        if best then
            c.res.second_wind = c.res.second_wind - 1
            c.turn.bonus = false
            best.reaction_used = true
            b:log("%s barks an order to %s!", c.name, best.name)
            b:emit({ kind = "feature", who = c, name = "Battle Orders", target = best })
            AI.ordered_attack(b, best)
        end
    end
end

-- What an ally would get out of an ordered reaction attack.
function AI.order_value(b, a)
    local foes = enemies(b, a)
    if #foes == 0 then return 0 end
    by_distance(b, a, foes)
    if a.class == "rogue" or a.class == "fighter" then
        local p = weapon_profile(a, "melee")
        if b:dist(a, foes[1]) <= p.reach then return a.class == "rogue" and 10 or 7 end
        local r = weapon_profile(a, "ranged")
        if r and b:dist(a, foes[1]) <= r.range[1] then return a.class == "rogue" and 8 or 5 end
        return 0
    end
    -- Casters: a damaging single-target cantrip.
    if spells.has_spell(a, "fire_bolt") or spells.has_spell(a, "sacred_flame") then return 4 end
    return 0
end

function AI.ordered_attack(b, a)
    local foes = by_distance(b, a, enemies(b, a))
    local t = foes[1]
    if not t then return end
    -- An ordered attack happens on someone else's turn, so Sneak Attack is available again.
    local saved_turn = a.turn
    a.turn = { sneak_used = false, savage_used = false, move = 0 }
    if a.class == "rogue" or a.class == "fighter" then
        local p = weapon_profile(a, "melee")
        if b:dist(a, t) <= p.reach then
            b:attack(a, t, p)
        else
            local r = weapon_profile(a, "ranged")
            if r then b:attack(a, t, r) end
        end
    elseif spells.has_spell(a, "fire_bolt") and b:dist(a, t) <= 120 then
        b:emit({ kind = "spell", caster = a, id = "fire_bolt", name = "Fire Bolt", slot = 0, target = t })
        S.fire_bolt.cast(b, a, 0, t)
    elseif spells.has_spell(a, "sacred_flame") and b:dist(a, t) <= 60 then
        b:emit({ kind = "spell", caster = a, id = "sacred_flame", name = "Sacred Flame", slot = 0, target = t })
        S.sacred_flame.cast(b, a, 0, t)
    end
    a.turn = saved_turn
end

-- Rogue.
local function rogue_turn(b, c)
    stand_if_prone(b, c)
    potion_help(b, c)
    local foes = enemies(b, c)
    if #foes == 0 then return end
    local melee = weapon_profile(c, "melee")
    local ranged = weapon_profile(c, "ranged")
    -- Look for a melee target with a friend next to it (Sneak Attack without Advantage).
    local best, bs = nil, -math.huge
    for _, e in ipairs(foes) do
        local friend = false
        for _, a in ipairs(b:allies_of(c)) do
            if b:dist(a, e) <= 5 and not b:incapacitated(a) then friend = true end
        end
        local d = b:dist(c, e)
        if friend and d <= 5 + c.turn.move then
            local s = 50 - d - e.hp * 0.5
            if s > bs then best, bs = e, s end
        end
    end
    local engaged = adjacent_enemies(b, c) > 0
    local function melee_round(t)
        if c.sub and c.sub.feint and c.turn.bonus and not c.turn.feinted then
            AI.feint(b, c, t)
        end
        attack_action(b, c, melee, t)
        -- Nick: the Light extra attack rides along with the Attack action.
        local off = weapon_profile(c, "offhand")
        if off and not t.dead and not t.down and c.masteries[c.weapons.offhand] and equipment.weapons[c.weapons.offhand].mastery == "nick" then
            b:attack(c, t, off)
        elseif off and c.turn.bonus and not t.dead and not t.down then
            c.turn.bonus = false
            b:attack(c, t, off)
        end
        -- Cunning Action: Disengage and slip back out.
        if c.turn.bonus and c.turn.move > 0 and adjacent_enemies(b, c) > 0 and c.hp < c.hp_max * 0.6 then
            c.turn.bonus = false
            c.turn.disengaged = true
            back_off(b, c, 15)
        end
    end
    -- Already in someone's face: fight them rather than walk through Opportunity Attacks.
    local adj = {}
    for _, e in ipairs(enemies(b, c)) do
        if b:dist(c, e) <= 5 then table.insert(adj, e) end
    end
    if #adj > 0 then
        melee_round(pick_target(b, c, adj, 8))
        return
    end
    if best then
        if approach(b, c, best, 5) then
            melee_round(best)
            return
        end
    end
    -- Ranged: Steady Aim (no movement) or Feint, then shoot.
    if ranged then
        local t = pick_target(b, c, foes, 9)
        if b:dist(c, t) > ranged.range[1] then
            get_in_range(b, c, t, ranged.range[1])
        end
        if c.sub and c.sub.feint and c.turn.bonus then
            AI.feint(b, c, t)
        elseif c.level >= 3 and c.turn.bonus and not c.turn.moved then
            c.turn.bonus = false
            c.turn.move = 0
            b:add_effect(c, { name = "Steady Aim", steady_aim = true, expires = b:next_turn(c, "end") })
        end
        if b:dist(c, t) <= ranged.range[2] then
            attack_action(b, c, ranged, t)
        end
        return
    end
    local t = by_distance(b, c, foes)[1]
    if approach(b, c, t, 5) then
        melee_round(t)
    end
end

-- Silvertongue Feint: Charisma (Deception) vs Wisdom (Insight).
function AI.feint(b, c, t)
    if b:dist(c, t) > 30 then return end
    c.turn.bonus = false
    c.turn.feinted = true
    local mine = b:check(c, "cha", c.deception_bonus or 0)
    local theirs = b:check(t, "wis", 0)
    if mine > theirs then
        b:log("%s feints and %s bites (%d vs %d).", c.name, t.name, mine, theirs)
        b:emit({ kind = "feature", who = c, name = "Feint", target = t, ok = true })
        b:add_effect(c, { name = "Feint", feint_vs = t, expires = b:next_turn(c, "end") })
    else
        b:log("%s's feint doesn't fool %s (%d vs %d).", c.name, t.name, mine, theirs)
    end
end

-- Keep a caster within range of the fight but out of reach.
local function caster_position(b, c, range)
    local foes = enemies(b, c)
    if #foes == 0 then return end
    by_distance(b, c, foes)
    if adjacent_enemies(b, c) > 0 then
        return
    end
    get_in_range(b, c, foes[1], range)
end

-- Cleric.
local function cleric_turn(b, c)
    stand_if_prone(b, c)
    local allies = b:allies_of(c, true, true)
    local foes = enemies(b, c)
    if #foes == 0 then return end
    -- 1. Pick a friend up off the floor.
    local downed
    for _, a in ipairs(allies) do
        if a.down and not a.dead and b:dist(c, a) <= 60 then downed = a end
    end
    local bloodied = 0
    for _, a in ipairs(allies) do
        if not a.dead and a.hp <= a.hp_max / 2 and b:dist(c, a) <= 30 then bloodied = bloodied + 1 end
    end
    if c.sub and c.sub.preserve_life and (c.res.channel or 0) > 0 and c.turn.action and (bloodied >= 2 or (downed and bloodied >= 1)) then
        AI.preserve_life(b, c)
    end
    if downed and downed.down and c.turn.bonus and can_cast(c, "healing_word") then
        cast(b, c, "healing_word", downed)
    end
    if downed and downed.down and c.turn.action and can_cast(c, "cure_wounds") and b:dist(c, downed) <= 5 + c.turn.move then
        approach(b, c, downed, 5)
        if b:dist(c, downed) <= 5 then cast(b, c, "cure_wounds", downed) end
    end
    potion_help(b, c)
    if not c.turn.action then return end
    -- 2. Open with the domain's trick or Bless.
    local undead_near = 0
    for _, e in ipairs(foes) do
        if e.type == "undead" and b:dist(c, e) <= 30 + c.turn.move then undead_near = undead_near + 1 end
    end
    if undead_near >= 2 and (c.res.channel or 0) > 0 and c.level >= 2 then
        caster_position(b, c, 30)
        AI.turn_undead(b, c)
        return
    end
    if c.sub and c.sub.warm_welcome and (c.res.channel or 0) > 0 and c.turn.bonus and (b.round == 1 or bloodied >= 2) then
        AI.warm_welcome(b, c)
    end
    if c.sub and c.sub.tricky_decoy then
        AI.mischief_bonus(b, c)
    end
    if not c.conc and can_cast(c, "bless") then
        local targets = {}
        for _, a in ipairs(b:allies_of(c, true)) do
            if b:dist(c, a) <= 30 + c.turn.move then table.insert(targets, a) end
        end
        table.sort(targets, function(x, y)
            local rank = { fighter = 1, rogue = 2, wizard = 3, cleric = 4 }
            return (rank[x.class] or 5) < (rank[y.class] or 5)
        end)
        if #targets >= 2 then
            local center = targets[1]
            if b:dist(c, center) > 30 then get_in_range(b, c, center, 30) end
            local inrange = {}
            for _, a in ipairs(targets) do
                if b:dist(c, a) <= 30 then table.insert(inrange, a) end
            end
            if #inrange >= 2 then
                cast(b, c, "bless", inrange)
                return
            end
        end
    end
    -- 3. Hold the most dangerous humanoid.
    if not c.conc and can_cast(c, "hold_person") then
        for _, e in ipairs(foes) do
            if e.type == "humanoid" and e.hp >= 25 and b:dist(c, e) <= 60 + c.turn.move then
                get_in_range(b, c, e, 60)
                cast(b, c, "hold_person", e)
                return
            end
        end
    end
    -- 4. Spiritual Weapon if not concentrating on anything better.
    if not c.conc and c.turn.bonus and can_cast(c, "spiritual_weapon") then
        local t = by_distance(b, c, foes)[1]
        if b:dist(c, t) <= 60 then cast(b, c, "spiritual_weapon", t) end
    elseif c.conc and c.conc.extra.spiritual_weapon and c.turn.bonus then
        local w = c.conc.extra.spiritual_weapon
        local near
        for _, e in ipairs(foes) do
            if b:dist_xy(w.x, w.y, e.x, e.y) <= 25 and b:dist(c, e) <= 60 then near = e break end
        end
        if near then
            c.turn.bonus = false
            spells.spiritual_weapon_strike(b, c, w, near)
        end
    end
    -- 5. Hit something.
    foes = enemies(b, c)
    if #foes == 0 then return end
    by_distance(b, c, foes)
    local t = foes[1]
    if b:dist(c, t) <= 5 then
        if can_cast(c, "inflict_wounds") and t.hp >= 12 and spells.find_slot(c, 1) and (c.res.slots[1] or 0) >= 2 then
            cast(b, c, "inflict_wounds", t)
        else
            attack_action(b, c, weapon_profile(c, "melee"), t)
        end
        return
    end
    local big = pick_target(b, c, foes, 9)
    if can_cast(c, "guiding_bolt") and big.hp >= 14 and (c.res.slots[1] or 0) >= 2 and b:dist(c, big) <= 120 then
        cast(b, c, "guiding_bolt", big)
        return
    end
    if c.c_divine_spark ~= false and (c.res.channel or 0) > 1 and big.hp >= 10 and b:dist(c, big) <= 30 + c.turn.move then
        get_in_range(b, c, big, 30)
        AI.divine_spark(b, c, big)
        return
    end
    caster_position(b, c, 60)
    if b:dist(c, big) <= 60 and spells.has_spell(c, "sacred_flame") then
        cast(b, c, "sacred_flame", big)
    elseif b:dist(c, t) <= 60 and spells.has_spell(c, "sacred_flame") then
        cast(b, c, "sacred_flame", t)
    end
end

function AI.preserve_life(b, c)
    c.res.channel = c.res.channel - 1
    c.turn.action = false
    local pool = 5 * c.level
    b:log("%s channels Preserve Life (%d HP to share).", c.name, pool)
    b:emit({ kind = "feature", who = c, name = "Preserve Life" })
    local list = {}
    for _, a in ipairs(b:allies_of(c, true, true)) do
        if not a.dead and a.hp <= a.hp_max / 2 and b:dist(c, a) <= 30 then table.insert(list, a) end
    end
    table.sort(list, function(x, y) return x.hp < y.hp end)
    for _, a in ipairs(list) do
        local cap = math.floor(a.hp_max / 2) - a.hp
        local give = math.min(pool, math.max(0, cap))
        if give > 0 then
            b:heal(c, a, give)
            pool = pool - give
        end
    end
end

function AI.turn_undead(b, c)
    c.res.channel = c.res.channel - 1
    c.turn.action = false
    local dc = creature.spell_dc(c)
    b:log("%s presents the holy symbol: Turn Undead!", c.name)
    b:emit({ kind = "feature", who = c, name = "Turn Undead" })
    for _, e in ipairs(enemies(b, c)) do
        if e.type == "undead" and b:dist(c, e) <= 30 then
            if not b:save(e, "wis", dc, { kind = "frightened" }) then
                b:add_effect(e, { name = "Turned", conds = { frightened = true, incapacitated = true },
                                  ends_on_damage = true, expires = { who = c, at = "start", n = 10 } })
            end
        end
    end
end

function AI.divine_spark(b, c, t)
    c.res.channel = c.res.channel - 1
    c.turn.action = false
    local amount = b.dice:d(8) + abmod(c, "wis")
    b:log("%s hurls a Divine Spark at %s.", c.name, t.name)
    b:emit({ kind = "feature", who = c, name = "Divine Spark", target = t })
    local ok = b:save(t, "con", creature.spell_dc(c), { kind = "divine_spark" })
    local dtype = (t.type == "undead") and "radiant" or "radiant"
    b:deal(c, t, { { ok and math.floor(amount / 2) or amount, dtype } }, { spell = "divine_spark" })
end

function AI.warm_welcome(b, c)
    c.res.channel = c.res.channel - 1
    c.turn.bonus = false
    local n = math.max(1, abmod(c, "wis"))
    local amount = math.max(1, abmod(c, "wis") + c.level)
    local list = {}
    for _, a in ipairs(b:allies_of(c, true)) do
        if b:dist(c, a) <= 30 then table.insert(list, a) end
    end
    -- The most hurt first, then whoever stands in front.
    local rank = { fighter = 1, rogue = 2, cleric = 3, wizard = 4 }
    table.sort(list, function(x, y)
        local dx, dy = x.hp_max - x.hp, y.hp_max - y.hp
        if dx ~= dy then return dx > dy end
        return (rank[x.class] or 5) < (rank[y.class] or 5)
    end)
    b:log("%s calls out a Warm Welcome (%d Temporary Hit Points each).", c.name, amount)
    b:emit({ kind = "feature", who = c, name = "Warm Welcome" })
    for i = 1, math.min(n, #list) do
        b:give_temp(list[i], amount)
    end
end

-- Where the decoy does the most good: beside the ally with the most enemies close by
-- (or, before the lines meet, the one nearest the enemy).
function AI.decoy_anchor(b, c)
    local foes = enemies(b, c)
    local anchor, best = nil, -math.huge
    for _, a in ipairs(b:allies_of(c, true)) do
        if not a.dead then
            local near, closest = 0, math.huge
            for _, e in ipairs(foes) do
                local d = b:dist(a, e)
                if d <= 10 then near = near + 1 end
                closest = math.min(closest, d)
            end
            local v = near * 1000 - closest
            if v > best then best, anchor = v, a end
        end
    end
    return anchor
end

function AI.tricky_decoy(b, c, anchor)
    anchor = anchor or AI.decoy_anchor(b, c) or c
    c.res.channel = c.res.channel - 1
    c.turn.bonus = false
    c.decoy = { x = anchor.x, y = anchor.y, last_round = (b.round or 1) + 9 }   -- 1 minute = 10 rounds
    b:log("%s conjures a Tricky Decoy next to %s.", c.name, anchor.name)
    b:emit({ kind = "feature", who = c, name = "Tricky Decoy", target = anchor })
end

-- Mischief: conjure the decoy once the fighting is close, and keep it where the trouble is.
function AI.mischief_bonus(b, c)
    if not c.turn.bonus then return end
    local anchor = AI.decoy_anchor(b, c)
    if not anchor then return end
    if not c.decoy then
        if (c.res.channel or 0) > 0 and b:dist(c, anchor) <= 30 + (c.turn.move or 0) then
            if b:dist(c, anchor) > 30 then get_in_range(b, c, anchor, 30) end
            if b:dist(c, anchor) <= 30 then AI.tricky_decoy(b, c, anchor) end
        end
    elseif b:dist_xy(c.decoy.x, c.decoy.y, anchor.x, anchor.y) > 10
        and b:dist_xy(c.decoy.x, c.decoy.y, anchor.x, anchor.y) <= 30 then
        c.turn.bonus = false
        c.decoy.x, c.decoy.y = anchor.x, anchor.y
        b:log("%s sends the decoy over to %s.", c.name, anchor.name)
        b:emit({ kind = "feature", who = c, name = "Decoy moves", target = anchor })
    end
end

-- Wizard.
local AREA_SPELLS = { "web", "sleep", "shatter", "burning_hands", "thunderwave", "color_spray" }
local function wizard_turn(b, c)
    stand_if_prone(b, c)
    local foes = enemies(b, c)
    if #foes == 0 then return end
    -- Escape when cornered.
    if adjacent_enemies(b, c) > 0 and c.hp <= c.hp_max * 0.6 and c.turn.bonus and can_cast(c, "misty_step") then
        local x, y = b:best_square(c, 30, function(x, y)
            local nearest = math.huge
            for _, e in ipairs(foes) do nearest = math.min(nearest, b:dist_xy(x, y, e.x, e.y)) end
            return math.min(nearest, 40)
        end)
        if x then
            local p = { x = x, y = y }
            cast(b, c, "misty_step", p)
        end
    end
    -- Mirror Mage: Quick Reflection puts the images up with a Bonus Action.
    if c.sub and c.sub.quick_reflection and c.turn.bonus and can_cast(c, "mirror_image") and not b:find_effect(c, "Mirror Image")
        and by_distance(b, c, enemies(b, c))[1] and b:dist(c, by_distance(b, c, enemies(b, c))[1]) <= 40 then
        local slot = pay(c, "mirror_image")
        c.turn.bonus = false
        b:log("%s casts Mirror Image as a Bonus Action (level %d).", c.name, slot)
        b:emit({ kind = "spell", caster = c, id = "mirror_image", name = "Mirror Image", slot = slot, target = c })
        S.mirror_image.cast(b, c, slot)
    end
    -- Shocking Grasp then step away if someone's in our face.
    if adjacent_enemies(b, c) > 0 and spells.has_spell(c, "shocking_grasp") then
        local adj = {}
        for _, e in ipairs(enemies(b, c)) do
            if b:dist(c, e) <= 5 then table.insert(adj, e) end
        end
        if #adj == 1 then
            cast(b, c, "shocking_grasp", adj[1])
            back_off(b, c, 20)
            return
        end
    end
    -- Area spells when they're worth it.
    local best_id, best_p, best_v = nil, nil, 0
    for _, id in ipairs(AREA_SPELLS) do
        if can_cast(c, id) and not (S[id].conc and c.conc) then
            local p, e, a = best_area(b, c, id)
            if p and a == 0 then
                local v = e
                if id == "sleep" then
                    v = 0
                    for _, t in ipairs(spells.sphere(b, p.x, p.y, 5)) do
                        if t.side ~= c.side and not t.condition_immune.exhaustion then v = v + 1 end
                    end
                    v = v * 1.2
                elseif id == "web" then v = e * 1.3
                elseif S[id].level == 2 then v = e * 0.9 end
                if v > best_v then best_id, best_p, best_v = id, p, v end
            end
        end
    end
    local need = 2
    if best_id and best_v >= need then
        cast(b, c, best_id, best_p, S[best_id].level)
        if c.turn.move > 0 then back_off(b, c, 25) end
        return
    end
    -- Hold a dangerous humanoid.
    if not c.conc and can_cast(c, "hold_person") then
        for _, e in ipairs(foes) do
            if e.type == "humanoid" and e.hp >= 25 and b:dist(c, e) <= 60 then
                cast(b, c, "hold_person", e)
                return
            end
        end
    end
    -- Big single targets: Scorching Ray, then Magic Missile to finish.
    foes = enemies(b, c)
    local t = pick_target(b, c, foes, 6)
    if t.hp >= 20 and can_cast(c, "scorching_ray") and b:dist(c, t) <= 120 then
        cast(b, c, "scorching_ray", t)
        caster_position(b, c, 120)
        return
    end
    if t.hp <= 10 and t.hp >= 4 and can_cast(c, "magic_missile") and (c.res.slots[1] or 0) >= 2 then
        cast(b, c, "magic_missile", t)
        caster_position(b, c, 120)
        return
    end
    if t.hp >= 15 and can_cast(c, "chromatic_orb") and (c.res.slots[1] or 0) >= 2 then
        get_in_range(b, c, t, 90)
        if b:dist(c, t) <= 90 then
            cast(b, c, "chromatic_orb", t)
            return
        end
    end
    -- Fire Bolt from a safe distance.
    if adjacent_enemies(b, c) == 0 then
        caster_position(b, c, 120)
    end
    if spells.has_spell(c, "fire_bolt") and b:dist(c, t) <= 120 then
        cast(b, c, "fire_bolt", t)
    elseif spells.has_spell(c, "ray_of_frost") and b:dist(c, t) <= 60 then
        cast(b, c, "ray_of_frost", t)
    end
    if adjacent_enemies(b, c) > 0 and c.turn.move > 0 then
        back_off(b, c, 15)
    end
end

-- Wayfinder's Charted Step after Initiative.
function AI.on_initiative(b)
    for _, c in ipairs(b.creatures) do
        if c.sub and c.sub.charted_step and not c.dead then
            c.turn = { move = 10, disengaged = true }
            back_off(b, c, 40)
            local friends = b:allies_of(c)
            table.sort(friends, function(x, y) return (x.class == "fighter" and 0 or 1) < (y.class == "fighter" and 0 or 1) end)
            for i = 1, math.min(2, #friends) do
                local a = friends[i]
                if b:dist(a, c) <= 30 then
                    a.turn = { move = 10, disengaged = true }
                    local foes = by_distance(b, a, enemies(b, a))
                    if (a.class == "fighter") and foes[1] then approach(b, a, foes[1], 5) else back_off(b, a, 30) end
                    a.turn = {}
                end
            end
            c.turn = {}
        end
    end
end

function AI.take_turn(b, c)
    local cmd = b:find_effect(c, "Commanded")
    if cmd then
        b:knock_prone(c, "Command: Grovel")
        b:remove_effect(c, cmd, "obeyed")
        return
    end
    if not c.pc then
        return monster_turn(b, c)
    end
    if c.class == "fighter" then
        fighter_turn(b, c)
    elseif c.class == "rogue" then
        rogue_turn(b, c)
    elseif c.class == "cleric" then
        cleric_turn(b, c)
    elseif c.class == "wizard" then
        wizard_turn(b, c)
    end
    -- Flaming Sphere and Spiritual Weapon get their Bonus Action if still unused.
    if c.conc and c.conc.extra.sphere and c.turn.bonus then
        local sp = c.conc.extra.sphere
        for _, e in ipairs(enemies(b, c)) do
            if b:dist_xy(sp.x, sp.y, e.x, e.y) <= 30 then
                c.turn.bonus = false
                sp.ram(b, c, e)
                break
            end
        end
    end
end

AI.can_cast = can_cast
AI.cast = cast
return AI
