-- The Museum of Nightmares (v2): the rules its monsters need beyond the SRD engine, and how they
-- fight. The adventure's own appendix, not the SRD: Euryale's veil and Petrify, the bone
-- construct's scarabs, the briars' charge, the huntlings' nerve, the Lecturer's lecture, the
-- Sentinel's fists that only knock heroes out, and the Steam Mech fighting for the party. The
-- battle (game/rules/battle.lua) and the tactics (game/rules/ai.lua) call in here when a stat
-- block asks for it (game/rules/data/monsters.lua, its `museum` field). Pure Lua.
--
-- Battle options (museum.setup(b, opts), from the encounter):
--   paint     the heroes' weapon attacks count as magical, and the Knight of Shades is vulnerable to them
--   mirror    the party holds up a polished mirror: when Euryale uses Petrify, she saves against it too
--   averted   the heroes know to avert their eyes: Advantage on their saves against Petrify
--   drowsy    the Lecturer's drone carried upstairs: the heroes save against charms with Disadvantage
--   earplugs  the heroes stopped their ears: Advantage on their saves against the Lecturer's drone
-- Allies (a Steam Mech on the party's side) are built by encounter.make_allies and placed by
-- whoever builds the fight. Each answers to a commander (a hero; by default the cleverest one):
-- it powers down when that hero drops, as the book says, and Euryale goes for that hero.
--
-- Events for the table (b:emit): kind "feature" with `museum` naming the moment, `who` the
-- creature it happened to, and `by` / `target` where there is one:
--   veil (Euryale pulls her hood off), petrify (her gaze), petrifying (a creature starts turning
--   to stone), petrified (turned to stone), freed (back from stone when Euryale falls), mirror
--   (she meets her own reflection), charmed (Charm Person took), scarabs (the swarm bursts out),
--   hyper (Hyper Destroyer Mode), overheat (the mech vents and shuts down), power_down (its
--   commander dropped), lecture (Bored to Death), listening (a hero sits down to listen), woken
--   (a friend shakes them out of it), reckless (the Knight's first reckless swing), knocked_out
--   (the Sentinel's fists), sands (the bone construct's Dodge);
-- and kind "flee" with why = "morale" when a huntling loses its nerve and runs.

local creature = require "game.rules.creature"

local M = {}

M.OPTIONS = { "paint", "mirror", "averted", "drowsy", "earplugs" }

-- The battle's options, from an encounter table (unknown keys are ignored).
function M.setup(b, opts)
    for _, k in ipairs(M.OPTIONS) do
        b[k] = (opts and opts[k]) and true or nil
    end
end

local function feature(b, who, name, kind, extra)
    local ev = { kind = "feature", who = who, name = name, museum = kind }
    for k, v in pairs(extra or {}) do
        ev[k] = v
    end
    b:emit(ev)
end
M.feature = feature

-- False Appearance: a fight made only of creatures that look like garden topiary until they
-- move starts with the party surprised (Disadvantage on Initiative, p. 13). True if it did.
function M.false_appearance(b)
    local any = false
    for _, c in ipairs(b.creatures) do
        if c.side ~= "party" then
            if not (c.traits and (c.traits.false_appearance or c.traits.ambusher)) then
                return false
            end
            any = true
        end
    end
    if not any then
        return false
    end
    for _, c in ipairs(b.creatures) do
        if c.side == "party" then
            c.surprised = true
        end
    end
    b:log("The hedges were never hedges: the party is surprised.")
    return true
end

-- Saving throw modifiers from the battle's options. Returns adv, dis (either may be nil).
function M.save_mods(b, c, ab, info)
    if c.side ~= "party" then
        return nil, nil
    end
    local kind = info.kind
    local adv, dis
    if b.drowsy and kind == "charmed" then
        dis = true
    end
    if b.averted and kind == "petrify" then
        adv = true
    end
    if b.earplugs and info.hearing then
        adv = true
    end
    return adv, dis
end

-- Turns -----------------------------------------------------------------------------------------

-- At the start of a creature's turn (battle.start_turn): recharges.
function M.start_turn(b, c)
    local s = c.data and c.data.sands
    if s and c.sands_spent and b.dice:d(6) >= (s.recharge or 5) then
        c.sands_spent = nil
    end
end

-- After damage lands (battle.deal): the Sentinel remembers who hurt it, a charm from Euryale
-- breaks when she or her side hurts the one she charmed, and the bone construct splits open.
function M.on_damaged(b, src, tgt, total, info)
    for i = #tgt.effects, 1, -1 do
        local e = tgt.effects[i]
        if e and e.breaks_on_damage_from and src and src.side == e.breaks_on_damage_from and not tgt.dead then
            b:remove_effect(tgt, e, "hurt")
            b:log("  The hurt breaks %s's charm.", tgt.name)
        end
    end
    local d = tgt.data
    if not d then
        return
    end
    if d.nonlethal and src then
        tgt.hurt_by = tgt.hurt_by or {}
        tgt.hurt_by[src] = (tgt.hurt_by[src] or 0) + total
    end
    local sp = d.spawn
    if sp and not tgt.spawned and tgt.hp <= tgt.hp_max * (sp.at or 0.5) then
        M.spawn(b, tgt)
    end
end

-- A free square near (x, y): nobody on it, not scenery.
function M.free_square(b, x, y, max_r)
    for r = 1, max_r or 4 do
        for dy = -r, r do
            for dx = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local nx, ny = x + dx, y + dy
                    if b:in_bounds(nx, ny) and not (b.blocked and b.blocked[nx * 1000 + ny]) and not b:occupant(nx, ny)
                        and not b:opaque_at(nx, ny) then
                        return nx, ny
                    end
                end
            end
        end
    end
    return nil
end

-- Crypt Scarabs: what's inside the bone construct pours out and joins the fight.
function M.spawn(b, parent)
    local sp = parent.data.spawn
    parent.spawned = true
    local out = {}
    for i = 1, sp.n or 1 do
        local x, y = M.free_square(b, parent.x, parent.y, 4)
        if not x then
            break
        end
        local m = creature.new_monster(sp.id, (sp.n or 1) > 1 and (" " .. i) or "")
        m.side = parent.side
        m.spawned_by = parent
        b:join(m, x, y)
        table.insert(out, m)
    end
    if #out > 0 then
        b:log("%s splits open, and %s pours out!", parent.name, out[1].name)
        feature(b, parent, sp.name or "Bursts open", "scarabs", { target = out[1], spawned = out })
    end
    return out
end

-- Someone fell: whatever they were holding up ends (Petrify, a charm, a lecture), and a mech
-- whose commander this was powers down.
function M.on_kill(b, c)
    for _, o in ipairs(b.creatures) do
        for i = #o.effects, 1, -1 do
            local e = o.effects[i]
            if e and e.ends_on_death_of == c then
                b:remove_effect(o, e, "freed")
            end
        end
    end
    M.on_drop(b, c)
end

function M.on_drop(b, c)
    for _, o in ipairs(b.creatures) do
        if o.commander == c and not o.dead and not o.powered_down then
            o.powered_down = true
            local hy = b:find_effect(o, "Hyper Destroyer Mode")
            if hy then
                b:remove_effect(o, hy, "powered down")
            end
            b:add_effect(o, { name = "Powered down", conds = { incapacitated = true }, out_of_fight = true })
            b:log("%s goes still: its commander is down.", o.name)
            feature(b, o, "Powers down", "power_down", { target = c })
        end
    end
end

-- Euryale --------------------------------------------------------------------------------------

local function stone_effect(b, c)
    for _, e in ipairs(c.effects) do
        if e.petrifying or e.stone then
            return e
        end
    end
    return nil
end
M.stone_effect = stone_effect

-- Turned to stone: out of the fight until whoever did it falls.
function M.turn_to_stone(b, who, e, src)
    b:remove_effect(who, e, "petrified")
    b:add_effect(who, { name = "Petrified", conds = { petrified = true, incapacitated = true }, out_of_fight = true,
                        stone = true, ends_on_death_of = (who ~= src) and src or nil,
                        on_end = function(bb, c2, why)
                            if why == "freed" then
                                bb:log("  The stone cracks and %s steps out of it.", c2.name)
                                feature(bb, c2, "Freed from stone", "freed", { by = src })
                            end
                        end })
    b:log("  %s turns to stone.", who.name)
    feature(b, who, "Turned to stone", "petrified", { by = src })
    if who == src then
        b:kill(who, nil, "turned to stone")      -- Euryale, caught by her own reflection
    end
end

-- One creature meets the gaze: a Constitution save or it starts turning to stone (Restrained),
-- and saves again at the end of its next turn or is Petrified.
function M.gaze(b, src, o)
    local p = src.data.petrify
    if b:save(o, p.save, p.dc, { kind = "petrify" }) then
        return false
    end
    local mine = o == b.active
    b:add_effect(o, { name = "Turning to stone", conds = { restrained = true }, petrifying = true,
                      save_end = { ab = p.save, dc = p.dc, kind = "petrify", skip_now = mine or nil },
                      on_fail_repeat = function(bb, who, e) M.turn_to_stone(bb, who, e, src) end,
                      ends_on_death_of = (o ~= src) and src or nil })
    b:log("  %s starts turning to stone.", o.name)
    feature(b, o, "Turning to stone", "petrifying", { by = src })
    return true
end

-- Who Petrify would catch: creatures within range that can see her eyes and can be turned.
local function caught(b, c)
    local p = c.data.petrify
    local foes, friends = 0, 0
    for _, o in ipairs(b.creatures) do
        if o ~= c and not o.dead and not o.removed and not o.down and b:dist(c, o) <= p.range and b:can_see(o, c)
            and not (o.condition_immune and o.condition_immune.petrified) and not stone_effect(b, o)
            and not b:any_effect(o, "out_of_fight") then
            if o.side == c.side then friends = friends + 1 else foes = foes + 1 end
        end
    end
    return foes, friends
end

function M.petrify_worth(b, c, standing)
    local foes, friends = caught(b, c)
    local v = foes - 0.5 * friends
    return v >= 2 or (v >= 1 and (standing <= 2 or c.hp <= c.hp_max * 0.3))
end

function M.petrify(b, c)
    local p = c.data.petrify
    c.petrify_used = true
    c.turn.action = false
    b:log("%s fixes them all with her eyes: Petrify!", c.name)
    feature(b, c, "Petrify", "petrify")
    for _, o in ipairs(b.creatures) do
        if o ~= c and not o.dead and not o.removed and b:dist(c, o) <= p.range and b:can_see(o, c)
            and not (o.condition_immune and o.condition_immune.petrified) and not stone_effect(b, o) then
            M.gaze(b, c, o)
        end
    end
    -- The polished mirror: she meets her own eyes too.
    if b.mirror and not c.dead then
        b:log("  Someone holds up the mirror, and %s meets her own reflection.", c.name)
        feature(b, c, "Meets her reflection", "mirror")
        M.gaze(b, c, c)
    end
end

-- Charm Person (Wisdom save with Advantage, since they're fighting her): the hero won't attack
-- her until she or her side hurts them, or they shake it off.
function M.charm_person(b, c, t)
    local sp = c.data.spells
    c.res.charm = (c.res.charm or sp.slots) - 1
    b:log("%s murmurs to %s: Charm Person.", c.name, t.name)
    b:emit({ kind = "spell", caster = c, id = "charm_person", name = "Charm Person", slot = 1, target = t })
    if b:save(t, "wis", sp.dc, { kind = "charmed", adv = true }) then
        return false
    end
    -- (Tuned: the charmed hero tries again at the end of each of their turns, so one bad roll
    -- doesn't sit a player out of the whole boss fight; the book's charm lasts the hour.)
    b:add_effect(t, { name = "Charmed", conds = { charmed = true }, charmed_by = c, breaks_on_damage_from = c.side,
                      ends_on_death_of = c, save_end = { ab = "wis", dc = sp.dc, kind = "charmed" } })
    b:log("  %s can't bring themselves to hurt %s.", t.name, c.name)
    feature(b, t, "Charmed", "charmed", { by = c })
    return true
end

function M.poison_spray(b, c, t)
    local sp = c.data.spells
    local prof = { id = "poison_spray", name = "Poison Spray", is_weapon = false, kind = "ranged", spell = "poison_spray",
                   to_hit = sp.to_hit, damage = sp.poison_spray.damage, range = { sp.poison_spray.range, sp.poison_spray.range },
                   reach = 5 }
    b:emit({ kind = "spell", caster = c, id = "poison_spray", name = "Poison Spray", slot = 0, target = t })
    b:attack(c, t, prof)
end

local function charmed_by(b, e, c)
    for _, x in ipairs(e.effects) do
        if x.charmed_by == c then
            return true
        end
    end
    return false
end

-- Poison does less to this one (a dwarf's Resilience, a construct's immunity).
local function shrugs_poison(t)
    return (t.immune and t.immune.poison) or (t.resist and t.resist.poison) or false
end

-- The softest target she can get at: easy to hit, nearly down, close enough.
local function soft_target(b, c, list, reach)
    local best, bv
    for _, e in ipairs(list) do
        local hit = math.min(0.95, math.max(0.05, (21 - (b:ac(e) - 5)) / 20))
        local v = hit * 10 - e.hp / 15
        if e.hp <= 12 then
            v = v + 4
        end
        if b:has(e, "restrained") then
            v = v + 2
        end
        if b:dist(c, e) > reach + (c.turn.move or 0) then
            v = v - 3
        end
        if not bv or v > bv or (v == bv and e.uid < best.uid) then
            best, bv = e, v
        end
    end
    return best
end

-- Who she goes for: the DM's pick, the mech's commander (the book: she knows who's giving the
-- orders), else whoever is easiest to hurt and most worth it.
local function euryale_target(b, c, list, H, reach)
    local t = H.focus_target(b, c, list, reach)
    if t then
        return t
    end
    for _, o in ipairs(b.creatures) do
        local cmd = o.commander
        if cmd and o.side ~= c.side and not o.dead and not o.powered_down then
            for _, e in ipairs(list) do
                if e == cmd and b:dist(c, e) <= (c.turn.move or 0) + 30 then
                    return e
                end
            end
        end
    end
    return soft_target(b, c, list, reach)
end

function M.euryale_turn(b, c, H)
    local d = c.data
    if c.veiled == nil then
        c.veiled = d.veil ~= nil
    end
    -- Lifting the Veil: her first turn at half her Hit Points or less.
    if c.veiled and c.hp <= c.hp_max * d.veil.at then
        c.veiled = false
        b:log("%s tears the hood away: a crown of snakes, and bronze eyes.", c.name)
        feature(b, c, "Lifts the veil", "veil")
    end
    H.stand_if_prone(b, c)
    local foes = H.enemies(b, c)
    if #foes == 0 then
        return true
    end
    -- Petrify, once, when it would catch enough of them.
    if not c.veiled and d.petrify and not c.petrify_used and M.petrify_worth(b, c, #foes) then
        M.petrify(b, c)
        return true
    end
    -- Someone she has charmed is no threat: leave them be (hitting them would break it).
    local open = {}
    for _, e in ipairs(foes) do
        if not charmed_by(b, e, c) then
            table.insert(open, e)
        end
    end
    if #open == 0 then
        open = foes
    end
    local claws = H.find_named(c, "claws")
    local bow = H.find_named(c, "poison_bow")
    local snakes = (not c.veiled) and H.find_named(c, "crown_of_snakes") or nil
    local sp = d.spells
    local n = (d.multiattack and d.multiattack.count or 1) + ((not c.veiled and d.veil and d.veil.extra_attacks) or 0)
    local t = euryale_target(b, c, open, H, c.veiled and bow.range[1] or 5)
    -- One attack can be a spell: Charm Person on a fighter or rogue while the hood is on, else
    -- Poison Spray at someone close who doesn't shrug off poison.
    local charm_t
    if c.veiled and sp and (c.res.charm or sp.slots) > 0 then
        local best, bv
        for _, e in ipairs(open) do
            if e.type == "humanoid" and not (e.condition_immune and e.condition_immune.charmed)
                and not b:find_effect(e, "Charmed") and b:dist(c, e) <= sp.charm_person.range + (c.turn.move or 0) then
                local v = ((e.class == "fighter" or e.class == "rogue") and 3 or 1) + (b:dist(c, e) <= 5 and 2 or 0)
                    - creature.save_bonus(e, "wis") * 0.3
                if not bv or v > bv then
                    best, bv = e, v
                end
            end
        end
        if best and bv >= 2 then
            charm_t = best
        end
    end
    local engaged = H.adjacent_enemies(b, c) > 0
    if c.veiled then
        -- While the hood is on she keeps her distance and shoots (the book: she weakens them with
        -- the bow and keeps moving), unless someone has already caught her up close.
        if not engaged then
            H.back_off(b, c, 20, t, bow.range[1])
        end
    else
        engaged = H.approach(b, c, t, 5)
        if c.dead or c.down then
            return true
        end
    end
    local function next_target(prefer_close)
        local live = {}
        for _, e in ipairs(H.enemies(b, c)) do
            if not charmed_by(b, e, c) then
                table.insert(live, e)
            end
        end
        if #live == 0 then
            live = H.enemies(b, c)
        end
        if #live == 0 then
            return nil
        end
        local close = {}
        for _, e in ipairs(live) do
            if b:dist(c, e) <= 5 then
                table.insert(close, e)
            end
        end
        if prefer_close and #close > 0 then
            return soft_target(b, c, close, 5)
        end
        return soft_target(b, c, live, bow.range[1])
    end
    for i = 1, n do
        if not t or t.dead or t.down or t.removed or b:any_effect(t, "out_of_fight")
            or (H.adjacent_enemies(b, c) > 0 and b:dist(c, t) > 5) then
            t = next_target(true)        -- (caught up close, she claws whoever is on her)
        end
        if not t then
            return true
        end
        local close = b:dist(c, t) <= 5
        if i == 1 and charm_t and b:dist(c, charm_t) <= sp.charm_person.range then
            local ct = charm_t
            charm_t = nil
            if M.charm_person(b, c, ct) and t == ct then
                t = nil
            end
        elseif close then
            H.attack_with(b, c, t, claws, false)
        elseif i == 1 and sp and b:dist(c, t) <= sp.poison_spray.range and not shrugs_poison(t) and not engaged then
            M.poison_spray(b, c, t)
        elseif H.in_shot(b, c.x, c.y, t, bow.range[2]) then
            H.attack_with(b, c, t, bow, true)
        end
        if c.dead or c.down then
            return true
        end
    end
    -- The Crown of Snakes: one more bite once the hood is off.
    if snakes then
        if not t or t.dead or t.down or b:dist(c, t) > 5 or b:any_effect(t, "out_of_fight") then
            t = next_target(true)
        end
        if t and b:dist(c, t) <= 5 then
            H.attack_with(b, c, t, snakes, false)
        end
    end
    return true
end

-- The Lecturer ---------------------------------------------------------------------------------

-- Bored to Death: a Wisdom save, or the target sits down to listen until someone tries to hurt
-- them (or the Lecturer is gone).
function M.lecture(b, c, t)
    local bored = c.data.bored
    c.turn.action = false
    b:log("%s drones at %s: Bored to Death.", c.name, t.name)
    feature(b, c, "Bored to Death", "lecture", { target = t })
    if b:save(t, bored.save, bored.dc, { kind = "charmed", hearing = true }) then
        return false
    end
    b:add_effect(t, { name = "Listening", conds = { charmed = true, incapacitated = true }, charmed_by = c,
                      out_of_fight = true, ends_on_damage = true, ends_on_death_of = c, listening = true })
    b:log("  %s sits down on a bench and listens.", t.name)
    feature(b, t, "Sits down to listen", "listening", { by = c })
    return true
end

local function fail_chance(b, t, ab, dc, info)
    local bonus = creature.save_bonus(t, ab)
    local p = math.min(0.95, math.max(0.05, (dc - 1 - bonus) / 20))
    local adv, dis = M.save_mods(b, t, ab, info)
    if info.kind == "charmed" and t.traits and t.traits.fey_ancestry then
        adv = true
    end
    if adv and not dis then
        p = p * p
    elseif dis and not adv then
        p = 1 - (1 - p) * (1 - p)
    end
    return p
end

function M.lecturer_turn(b, c, H)
    local bored = c.data.bored
    local foes = H.enemies(b, c)          -- (anyone listening is out of the fight already)
    if #foes == 0 then
        return true
    end
    local best, bv
    for _, e in ipairs(foes) do
        if (e.type == "humanoid" or e.type == "beast") and not (e.condition_immune and e.condition_immune.charmed)
            and b:dist(c, e) <= bored.range + (c.turn.move or 0) then
            local v = fail_chance(b, e, bored.save, bored.dc, { kind = "charmed", hearing = true })
                + (b:dist(c, e) <= 5 and 0.3 or 0) - b:dist(c, e) * 0.001
            if not bv or v > bv then
                best, bv = e, v
            end
        end
    end
    if best then
        if not H.in_shot(b, c.x, c.y, best, bored.range) then
            H.get_in_range(b, c, best, bored.range)
        end
        if H.in_shot(b, c.x, c.y, best, bored.range) then
            M.lecture(b, c, best)
        end
    else
        H.get_in_range(b, c, H.by_distance(b, c, foes)[1], bored.range)
    end
    return true
end

-- A hero shakes a friend out of the lecture (it counts as trying to hurt them, which breaks the
-- charm). Only when it's got a hold on the table: two or more listening. True if that was the turn.
function M.wake_friend(b, c, H)
    if not c.turn.action then
        return false
    end
    local sleepers = {}
    for _, a in ipairs(b:allies_of(c)) do
        if b:find_effect(a, "Listening") then
            table.insert(sleepers, a)
        end
    end
    if #sleepers < 2 then
        return false
    end
    H.by_distance(b, c, sleepers)
    local s = sleepers[1]
    if b:dist(c, s) > 5 + (c.turn.move or 0) then
        return false
    end
    H.approach(b, c, s, 5)
    if b:dist(c, s) > 5 or c.dead or c.down then
        return false
    end
    c.turn.action = false
    b:remove_effect(s, b:find_effect(s, "Listening"), "woken")
    b:log("%s shakes %s out of the lecture.", c.name, s.name)
    feature(b, c, "Shakes awake", "woken", { target = s })
    return true
end

-- The Steam Mech ----------------------------------------------------------------------------------

-- Hyper Destroyer Mode, when the fight is at its height: the boss is bloodied and close, the
-- mech is hurt, or it has dragged on.
local function want_hyper(b, c, foes)
    if c.hp <= c.hp_max * 0.5 or (b.round or 1) >= 4 then
        return true
    end
    for _, e in ipairs(foes) do
        if e.boss and e.hp <= e.hp_max * 0.5 and b:dist(c, e) <= 30 then
            return true
        end
    end
    return false
end

-- The end of each turn in the mode: a Constitution save (DC 10 + turns in it) or the mech vents
-- (Fire on everyone close who fails a Dexterity save) and shuts down at 0 Hit Points.
function M.overheat(b, c, e)
    local hy = c.data.hyper
    c.hyper_turns = (c.hyper_turns or 0) + 1
    if b:save(c, "con", hy.dc + c.hyper_turns, { kind = "overheat" }) then
        return
    end
    b:log("%s shrieks and vents scalding steam: thermal evacuation!", c.name)
    feature(b, c, "Overheats and shuts down", "overheat")
    b:remove_effect(c, e, "overheated")
    c.hyper_on = nil
    local v = hy.vent
    for _, o in ipairs(b.creatures) do
        if o ~= c and not o.dead and not o.removed and b:dist(c, o) <= v.radius then
            if not b:save(o, v.save, v.dc, { kind = "vent" }) then
                b:deal(c, o, b:roll_parts({ v.damage }), { spell = "thermal_evacuation" })
            end
        end
    end
    c.shut_down = true
    c.hp = 0
    b:kill(c, nil, "overheated")
end

function M.go_hyper(b, c)
    local hy = c.data.hyper
    c.hyper_on, c.hyper_spent, c.hyper_turns = true, true, 0
    b:add_effect(c, { name = "Hyper Destroyer Mode", ac = hy.ac, speed_bonus = hy.speed, tag = true, hyper = true,
                      on_end_turn = M.overheat })
    c.turn.move = (c.turn.move or 0) + hy.speed
    b:log("%s goes rigid, then unfolds: Hyper Destroyer Mode engaged.", c.name)
    feature(b, c, "Hyper Destroyer Mode", "hyper")
end

local function missiles(b, c, H)
    local m = c.data.missiles
    local list = {}
    for _, e in ipairs(H.by_distance(b, c, H.enemies(b, c))) do
        if #list < (m.targets or 3) and H.in_shot(b, c.x, c.y, e, m.range[2]) then
            table.insert(list, e)
        end
    end
    if #list == 0 then
        return
    end
    c.turn.bonus = false
    b:log("%s's shoulders open: Hyper Missiles.", c.name)
    for _, e in ipairs(list) do
        if not e.dead and not e.down then
            b:attack(c, e, creature.monster_attack(c, m, true))
        end
    end
end

function M.mech_turn(b, c, H)
    local foes = H.enemies(b, c)
    if #foes == 0 then
        return true
    end
    if c.data.hyper and not c.hyper_spent and want_hyper(b, c, foes) then
        M.go_hyper(b, c)
    end
    local fists = H.find_named(c, "steam_fists")
    local gun = H.find_named(c, "chain_gun")
    -- The boss if it can get there, else whoever is nearest.
    H.by_distance(b, c, foes)
    local t = foes[1]
    for _, e in ipairs(foes) do
        if e.boss and b:dist(c, e) <= (c.turn.move or 0) + 5 then
            t = e
        end
    end
    local extra = c.hyper_on and { c.data.hyper.melee_extra } or nil
    if H.approach(b, c, t, 5) then
        b:attack(c, t, creature.monster_attack(c, fists), { extra_parts = extra })
    elseif not c.dead then
        local near = H.by_distance(b, c, H.enemies(b, c))[1]
        if near and b:dist(c, near) <= 5 then
            b:attack(c, near, creature.monster_attack(c, fists), { extra_parts = extra })
        elseif near and H.in_shot(b, c.x, c.y, near, gun.range[2]) then
            b:attack(c, near, creature.monster_attack(c, gun, true))
        end
    end
    if c.hyper_on and c.turn.bonus and not c.dead and c.data.missiles then
        missiles(b, c, H)
    end
    return true
end

-- The rest ------------------------------------------------------------------------------------

-- Huntlings: once the pack has lost enough of itself (or one is hurt and they're outnumbered),
-- they don't stay to die.
function M.loses_nerve(b, c)
    local m = c.data and c.data.morale
    if not m then
        return false
    end
    local total, lost, standing = 0, 0, 0
    for _, o in ipairs(b.creatures) do
        if o.side == c.side and o.monster_id == c.monster_id then
            total = total + 1
            if o.dead or o.removed then
                lost = lost + 1
            else
                standing = standing + 1
            end
        end
    end
    if total == 0 or lost == 0 then
        return false
    end
    if lost / total >= (m.pack or 0.5) then
        return true
    end
    return c.hp <= c.hp_max / 2 and standing < #b:enemies_of(c)
end

function M.flee(b, c, H)
    c.turn.disengaged = true                 -- Nimble Survivor: Disengage as a Bonus Action
    c.turn.bonus = false
    c.turn.move = (c.turn.move or 0) + b:speed(c)   -- and Dash
    H.back_off(b, c, 200)
    b:log("%s loses its nerve and bolts.", c.name)
    b:remove(c, "morale")
end

local function kruthik_turn(b, c, H)
    if M.loses_nerve(b, c) then
        M.flee(b, c, H)
        return true
    end
    H.standard(b, c)
    -- Nimble Survivor: bite, then Disengage and slip back out of reach to strike again later.
    if not c.dead and not c.removed and c.turn.bonus and (c.turn.move or 0) > 0 and H.adjacent_enemies(b, c) > 0 then
        c.turn.bonus = false
        c.turn.disengaged = true
        H.back_off(b, c, 15)
    end
    return true
end

local function knight_turn(b, c, H)
    -- Reckless: Advantage on its attacks this turn; attacks against it have Advantage until its next turn.
    b:add_effect(c, { name = "Reckless", reckless = true, expires = b:next_turn(c, "start") })
    if not c.reckless_said then
        c.reckless_said = true
        b:log("%s throws itself forward, heedless (Reckless).", c.name)
        feature(b, c, "Reckless", "reckless")
    end
    return false                             -- the usual turn does the rest
end

local function bone_turn(b, c, H)
    H.standard(b, c)
    -- Sands of the Ancients: a Bonus Action Dodge when it's in the thick of it.
    if not c.dead and c.data.sands and not c.sands_spent and c.turn.bonus and H.adjacent_enemies(b, c) >= 2 then
        c.sands_spent = true
        c.turn.bonus = false
        b:add_effect(c, { name = "Dodge", dodge = true, expires = b:next_turn(c, "start") })
        b:log("%s whirls in a cloud of sand (Sands of the Ancients).", c.name)
        feature(b, c, "Sands of the Ancients", "sands")
    end
    return true
end

-- The Sentinel: it goes for whoever has been hurting it (whoever went for the box).
local function sentinel_turn(b, c, H)
    local picked
    if not c.dm_target and c.hurt_by then
        local best, bv
        for o, v in pairs(c.hurt_by) do
            if not o.dead and not o.down and not o.removed
                and (not bv or v > bv or (v == bv and o.uid < best.uid)) then
                best, bv = o, v
            end
        end
        if best then
            c.dm_target, picked = best, true
        end
    end
    H.standard(b, c)
    if picked then
        c.dm_target = nil
    end
    return true
end

local TURNS = {
    euryale = M.euryale_turn, lecturer = M.lecturer_turn, steam_mech = M.mech_turn, kruthik = kruthik_turn,
    knight = knight_turn, bone_construct = bone_turn, sentinel = sentinel_turn,
}

-- A museum monster's turn. H: the tactics' helpers (game/rules/ai.lua). Returns true when the
-- turn is done, false to carry on with the usual monster turn.
function M.turn(b, c, H)
    local f = c.data and c.data.museum and TURNS[c.data.museum]
    if not f then
        return false
    end
    return f(b, c, H)
end

return M
