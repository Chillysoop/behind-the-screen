-- The Wild Sheep Chase's creatures' own turns (the book's stat blocks, page 5): the bed dragon's Splinter Breath and
-- its rider, Ahmed Noke's spells in the yard (Enlarge, Haste, Ray of Frost, Thunderwave, Expeditious Retreat), and his
-- men's hasted blows. A stat block names its turn: `rules = "sheep"`, `rules_turn` (the
-- adventure's creatures in game/data/sheep/module.lua, through game/model/standard.lua). Our words for what happens.
-- Engine-free, like the rest of game/rules/.

local M = {}

-- (The foes in a cone in front of it: within its length, and no more than 45 degrees off the line to the one it aims at.)
local function in_cone(b, c, aim, length)
    local ax, ay = aim.x - c.x, aim.y - c.y
    local al = math.sqrt(ax * ax + ay * ay)
    local out = {}
    for _, o in ipairs(b:enemies_of(c)) do
        if b:dist(c, o) <= length + 5 then
            local ox, oy = o.x - c.x, o.y - c.y
            local ol = math.sqrt(ox * ox + oy * oy)
            if al == 0 or ol == 0 or (ax * ox + ay * oy) / (al * ol) >= 0.70 then
                table.insert(out, o)
            end
        end
    end
    return out
end

-- An area that calls for a save: half on a success when `half`. Returns how many it caught.
local function area(b, c, targets, p, label)
    b:log("%s: %s!", c.name, label)
    b:emit({ kind = "feature", who = c, name = label })
    for _, o in ipairs(targets) do
        local ok = b:save(o, p.save, p.dc, { kind = p.kind or "area" })
        local parts = b:roll_parts(p.damage)
        if ok and p.half then
            for _, part in ipairs(parts) do
                part[1] = math.floor(part[1] / 2)
            end
        end
        if not ok or p.half then
            b:deal(c, o, parts, { spell = p.id })
        end
    end
    return #targets
end

-- Its rider (p5: Noke on its back): a Ray of Frost each turn at whoever's furthest off within range, the one backing away.
local function rider(b, c, H)
    local rd = c.data.rider
    if not (rd and rd.attack) or c.dead or c.down then
        return
    end
    local best, bd
    for _, e in ipairs(H.enemies(b, c)) do
        local d = b:dist(c, e)
        if d <= rd.attack.range[1] and H.in_shot(b, c.x, c.y, e, rd.attack.range[1]) and (not bd or d > bd) then
            best, bd = e, d
        end
    end
    if best then
        b:log("  %s, on its back, points a finger.", rd.name)
        H.attack_with(b, c, best, rd.attack, true)
    end
end

-- The bed dragon (p5): Splinter Breath when it's ready (back on a 5 or 6 at the start of its turn), at whoever it can
-- catch two of if it can; otherwise it bites like anything else. Then its rider's ray.
function M.bed_dragon(b, c, H)
    if not M.breathe(b, c, H) then
        H.standard(b, c)
    end
    rider(b, c, H)
    return true
end
function M.breathe(b, c, H)
    local br = c.data.breath
    if not br then
        return false
    end
    if c.breath_spent then
        local r = b.dice:d(6)
        if r >= ((br.recharge and br.recharge[1]) or 5) then
            c.breath_spent = nil
            b:log("  %s's breath is back (%d).", c.name, r)
        end
    end
    if c.breath_spent then
        return false
    end
    local best, bn
    for _, e in ipairs(H.by_distance(b, c, H.enemies(b, c))) do
        local n = #in_cone(b, c, e, br.cone or 15)
        if b:dist(c, e) <= (br.cone or 15) + 5 and (not bn or n > bn) then
            best, bn = e, n
        end
    end
    if not best then
        return false
    end
    c.breath_spent = true
    c.turn.action = false
    area(b, c, in_cone(b, c, best, br.cone or 15), br, br.name or "Breath")
    return true
end

-- Noke (p5): offensively weak, he buffs his men. Up on the platform above the yard he keeps one spell going
-- (concentration): Enlarge on the bear once it's out, else Haste on an ape. Otherwise Ray of Frost, which slows whoever
-- it hits. Someone right up close gets a Thunderwave, once; after that, close again, or with nobody left fighting
-- for him, he casts Expeditious Retreat and runs into the hall (escapes: never killed here, his bed is waiting).
local function standing(b, o)
    return not o.dead and not o.down and not o.removed
end
local function run(b, c)
    c.turn.disengaged = true
    b:log(c.data.flee_line or "%s runs.", c.name)
    b:emit({ kind = "feature", who = c, name = "Expeditious Retreat" })
    b:remove(c, "morale")
end
local function buff(b, c, H)
    local bf = c.data.buffs
    if not bf then
        return false
    end
    -- (Still holding one on someone standing: he keeps it. Held on nobody now, the bear down: he lets it go.)
    if c.conc then
        for _, eff in ipairs(c.conc.effects or {}) do
            if eff.holder and standing(b, eff.holder) then
                return false
            end
        end
        b:end_concentration(c, "nobody left to hold it on")
    end
    c.buff_slots = c.buff_slots or {}
    local function left(k)
        local def = bf[k]
        if not def then
            return 0
        end
        c.buff_slots[k] = c.buff_slots[k] or def.slots or 1
        return c.buff_slots[k]
    end
    local bear, ape
    for _, o in ipairs(b:allies_of(c)) do
        if standing(b, o) and o.monster_id then
            if bf.enlarge and string.find(o.monster_id, bf.enlarge.on .. "$") and not bear then
                bear = o
            elseif bf.haste and string.find(o.monster_id, bf.haste.on .. "$") and (not ape or o.hp > ape.hp) then
                ape = o
            end
        end
    end
    local target, which = nil, nil
    if bear and left("enlarge") > 0 and b:dist(c, bear) <= 30 then
        target, which = bear, "enlarge"
    elseif ape and left("haste") > 0 and b:dist(c, ape) <= 30 then
        target, which = ape, "haste"
    end
    if not target then
        return false
    end
    c.buff_slots[which] = c.buff_slots[which] - 1
    c.turn.action = false
    b:start_concentration(c, which == "enlarge" and "enlarge_reduce" or "haste")
    if which == "enlarge" then
        b:log("%s casts Enlarge on %s: it swells to twice its size.", c.name, target.name)
        b:emit({ kind = "feature", who = c, name = "Enlarge", target = target })
        b:add_effect(target, { name = "Enlarged", hit_dice = bf.enlarge.dice or { 1, 4, 0 }, str_adv = true, conc_of = c })
    else
        b:log("%s casts Haste on %s.", c.name, target.name)
        b:emit({ kind = "feature", who = c, name = "Haste", target = target })
        b:add_effect(target, { name = "Hasted", ac = 2, speed_bonus = target.speed or 30, hasted = true, conc_of = c })
    end
    return true
end
local function ray(b, c, H)
    local a
    for _, at in ipairs(c.data.attacks or {}) do
        if at.id == "ray_of_frost" then
            a = at
        end
    end
    if not a then
        return false
    end
    local best, bd
    for _, e in ipairs(H.by_distance(b, c, H.enemies(b, c))) do
        local d = b:dist(c, e)
        if d <= a.range[1] and H.in_shot(b, c.x, c.y, e, a.range[1]) and (not best or e.hp < best.hp) then
            best, bd = e, d
        end
    end
    if not best then
        return false
    end
    local creature = require "game.rules.creature"
    local prof = creature.monster_attack(c, a, true)
    local r = b:attack(c, best, prof)
    c.turn.action = false
    -- (A hit slows them: 10 feet less, until the start of his next turn. SRD 5.2.1, Ray of Frost.)
    if r and r.hit and not best.dead and not best.down then
        b:add_effect(best, { name = "Ray of Frost", speed_minus = 10, expires = b:next_turn(c, "start") })
    end
    return true
end
function M.noke(b, c, H)
    local tw = c.data.thunderwave
    c.slots1 = c.slots1 or (tw and tw.slots) or 0
    local foes = H.enemies(b, c)
    if #foes == 0 then
        return false
    end
    local friends = 0
    for _, o in ipairs(b:allies_of(c)) do
        if standing(b, o) then
            friends = friends + 1
        end
    end
    local close = {}
    for _, e in ipairs(foes) do
        if b:dist(c, e) <= 10 then
            table.insert(close, e)
        end
    end
    -- The fight's lost: nobody left fighting for him.
    if friends == 0 and c.data.escapes and c.had_friends then
        run(b, c)
        return true
    end
    c.had_friends = c.had_friends or friends > 0
    if #close > 0 then
        if tw and c.slots1 > 0 and not c.thundered then
            c.thundered = true
            c.slots1 = c.slots1 - 1
            c.turn.action = false
            area(b, c, close, tw, "Thunderwave")
            H.back_off(b, c, 15)
            return true
        end
        if c.data.escapes then
            run(b, c)
            return true
        end
    end
    if buff(b, c, H) or ray(b, c, H) then
        if #close == 0 then
            -- (He stays up on his platform: a step back from anyone coming.)
            for _, e in ipairs(foes) do
                if b:dist(c, e) <= 20 then
                    H.back_off(b, c, 10)
                    break
                end
            end
        end
        return true
    end
    return false
end

-- Noke's men (p5): a hasted one gets a second blow, after its usual turn.
function M.guard(b, c, H)
    if not (c.data and c.data.attacks) then
        return false
    end
    H.standard(b, c)
    if b:any_effect(c, "hasted") and standing(b, c) then
        for _, e in ipairs(H.enemies(b, c)) do
            if b:dist(c, e) <= 5 and standing(b, e) then
                local a
                for _, at in ipairs(c.data.attacks) do
                    if at.kind == "melee" and not a then
                        a = at
                    end
                end
                if a then
                    b:log("  %s, hasted, swings again.", c.name)
                    H.attack_with(b, c, e, a, false)
                end
                break
            end
        end
    end
    return true
end

local TURNS = { bed_dragon = M.bed_dragon, noke = M.noke, guard = M.guard }

-- A Sheep Chase creature's turn. Returns true when the turn is done, false for the usual monster turn.
function M.turn(b, c, H)
    local f = c.data and TURNS[c.data.rules_turn]
    if not f then
        return false
    end
    return f(b, c, H)
end

return M
