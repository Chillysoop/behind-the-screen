-- Cleric and Wizard spells up to level 2 (SRD 5.2.1 "Spells", pp. 107-175),
-- the ones that matter in a fight, plus the few the subclasses add.
-- Each spell: level, casting ("action" | "bonus" | "reaction" | "precast"),
-- range (feet), conc, tags for the AI, and cast(b, caster, slot, target) where
-- target is a creature, a list of creatures, or a point { x, y }.

local creature = require "game.rules.creature"

local S = {}
local M = { list = S }

local abmod = creature.abmod

local function cast_mod(c)
    return abmod(c, c.casting or "int")
end

-- Spell attack profile.
local function spell_attack(c, name, kind, count, die, dtype, range)
    return {
        id = name, name = name, is_weapon = false, kind = kind,
        to_hit = creature.spell_attack(c), damage = { { count, die, 0, dtype } },
        range = range and { range, range } or nil, reach = 5,
    }
end

local function half(parts)
    local out = {}
    for _, p in ipairs(parts) do
        table.insert(out, { math.floor(p[1] / 2), p[2] })
    end
    return out
end

-- Potent Cantrip (Evoker, p. 82): half damage on a miss or a successful save.
local function potent(b, c, spell, tgt, parts)
    if spell.level == 0 and c.sub and c.sub.potent_cantrip then
        b:log("  Potent Cantrip: half damage anyway.")
        b:deal(c, tgt, half(parts), { spell = spell.id })
    end
end

-- Geometry ------------------------------------------------------------------------------

function M.sphere(b, cx, cy, radius)
    local out = {}
    for _, o in ipairs(b.creatures) do
        if not o.dead and b:dist_xy(o.x, o.y, cx, cy) <= radius then
            table.insert(out, o)
        end
    end
    return out
end

-- A cone from the caster toward (tx, ty): within length and about 27 degrees either side.
function M.cone(b, c, tx, ty, length)
    local dx, dy = tx - c.x, ty - c.y
    local dl = math.sqrt(dx * dx + dy * dy)
    if dl == 0 then
        return {}
    end
    local out = {}
    for _, o in ipairs(b.creatures) do
        if o ~= c and not o.dead then
            local ox, oy = o.x - c.x, o.y - c.y
            local ol = math.sqrt(ox * ox + oy * oy)
            if ol > 0 and b:dist(c, o) <= length then
                local cosang = (ox * dx + oy * dy) / (ol * dl)
                if cosang >= 0.86 then
                    table.insert(out, o)
                end
            end
        end
    end
    return out
end

-- A cube of side `size` feet whose face touches the caster, pushed out in direction (sx, sy).
function M.cube_from(b, c, sx, sy, size)
    local n = math.floor(size / 5)
    local cells = {}
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
            cells[x .. "," .. y] = true
        end
    end
    local out = {}
    for _, o in ipairs(b.creatures) do
        if not o.dead and cells[o.x .. "," .. o.y] then
            table.insert(out, o)
        end
    end
    return out, cells
end

function M.square_cells(x0, y0, n)
    local cells = {}
    for x = x0, x0 + n - 1 do
        for y = y0, y0 + n - 1 do
            cells[x .. "," .. y] = true
        end
    end
    return cells
end

-- Shared helpers -------------------------------------------------------------------------

local function save_damage(b, c, spell, targets, ab, dc, parts_def, opts)
    opts = opts or {}
    local rolled = b:roll_parts(parts_def)            -- damage rolled once for all targets (p. 17)
    for _, t in ipairs(targets) do
        if not t.dead then
            local ok = b:save(t, ab, dc, { kind = spell.id, dis = opts.dis_for and opts.dis_for(t) })
            if ok then
                if spell.level > 0 and opts.half ~= false then
                    b:deal(c, t, half(rolled), { spell = spell.id })
                elseif spell.level == 0 then
                    potent(b, c, spell, t, rolled)
                end
            else
                b:deal(c, t, rolled, { spell = spell.id })
                if opts.on_fail and not t.dead then
                    opts.on_fail(t)
                end
            end
        end
    end
end

local function heal_amount(b, c, count, die, slot)
    local amount = b.dice:roll(count, die) + cast_mod(c)
    if slot and slot > 0 and c.sub and c.sub.disciple_of_life then
        amount = amount + 2 + slot                    -- Disciple of Life (p. 40)
    end
    return amount
end

-- Cantrips -----------------------------------------------------------------------------------

S.fire_bolt = { name = "Fire Bolt", level = 0, page = 132, casting = "action", range = 120, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Fire Bolt", "ranged", 1, 10, "fire", 120)
        b:attack(c, t, prof, { on_miss = function(_, _, tgt)
            potent(b, c, S.fire_bolt, tgt, b:roll_parts(prof.damage))
        end })
    end }

S.ray_of_frost = { name = "Ray of Frost", level = 0, page = 157, casting = "action", range = 60, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Ray of Frost", "ranged", 1, 8, "cold", 60)
        b:attack(c, t, prof, {
            on_hit = function(_, _, tgt)
                b:add_effect(tgt, { name = "Ray of Frost", speed_minus = 10, expires = b:next_turn(c, "start") })
            end,
            on_miss = function(_, _, tgt) potent(b, c, S.ray_of_frost, tgt, b:roll_parts(prof.damage)) end })
    end }

S.shocking_grasp = { name = "Shocking Grasp", level = 0, page = 162, casting = "action", range = 5, tags = { "damage", "single", "melee" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Shocking Grasp", "melee", 1, 8, "lightning")
        b:attack(c, t, prof, {
            on_hit = function(_, _, tgt)
                b:add_effect(tgt, { name = "Shocked", no_oa = true, expires = b:next_turn(tgt, "start") })
            end,
            on_miss = function(_, _, tgt) potent(b, c, S.shocking_grasp, tgt, b:roll_parts(prof.damage)) end })
    end }

S.chill_touch = { name = "Chill Touch", level = 0, page = 115, casting = "action", range = 5, tags = { "damage", "single", "melee" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Chill Touch", "melee", 1, 10, "necrotic")
        b:attack(c, t, prof, {
            on_hit = function(_, _, tgt)
                b:add_effect(tgt, { name = "Chill Touch", no_healing = true, expires = b:next_turn(c, "end") })
            end,
            on_miss = function(_, _, tgt) potent(b, c, S.chill_touch, tgt, b:roll_parts(prof.damage)) end })
    end }

S.poison_spray = { name = "Poison Spray", level = 0, page = 153, casting = "action", range = 30, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Poison Spray", "ranged", 1, 12, "poison", 30)
        b:attack(c, t, prof, { on_miss = function(_, _, tgt)
            potent(b, c, S.poison_spray, tgt, b:roll_parts(prof.damage))
        end })
    end }

S.acid_splash = { name = "Acid Splash", level = 0, page = 107, casting = "action", range = 60, area = { "sphere", 5 },
    tags = { "damage", "area" },
    cast = function(b, c, slot, p)
        save_damage(b, c, S.acid_splash, M.sphere(b, p.x, p.y, 5), "dex", creature.spell_dc(c), { { 1, 6, 0, "acid" } })
    end }

S.sacred_flame = { name = "Sacred Flame", level = 0, page = 159, casting = "action", range = 60, tags = { "damage", "single", "save" },
    cast = function(b, c, slot, t)
        save_damage(b, c, S.sacred_flame, { t }, "dex", creature.spell_dc(c), { { 1, 8, 0, "radiant" } })
    end }

-- True Strike (p. 171): a weapon attack using the spellcasting ability; Radiant if you like.
S.true_strike = { name = "True Strike", level = 0, page = 171, casting = "action", range = 5, tags = { "damage", "single", "melee" },
    cast = function(b, c, slot, t)
        local prof = creature.weapon_attack(c, c.weapons.main)
        local diff = cast_mod(c) - (prof.ability or 0)
        prof.to_hit = prof.to_hit + diff
        prof.ability = cast_mod(c)
        prof.damage = { { prof.damage[1][1], prof.damage[1][2], prof.damage[1][3] + diff,
                          t.resist[prof.damage[1][4]] and "radiant" or prof.damage[1][4] } }
        prof.name = "True Strike"
        b:attack(c, t, prof)
    end }

S.spare_the_dying = { name = "Spare the Dying", level = 0, page = 163, casting = "action", range = 15, tags = { "stabilize" },
    cast = function(b, c, slot, t)
        b:stabilize(t)
    end }

-- Utility cantrips the engine knows but never casts in a fight.
for _, id in ipairs({ "guidance", "light", "thaumaturgy", "mage_hand", "prestidigitation", "minor_illusion",
                      "mending", "message", "resistance", "dancing_lights" }) do
    S[id] = { name = id, level = 0, casting = "action", range = 0, tags = { "utility" }, utility = true }
end

-- Level 1 ------------------------------------------------------------------------------------

S.magic_missile = { name = "Magic Missile", level = 1, page = 146, casting = "action", range = 120, tags = { "damage", "auto_hit" },
    cast = function(b, c, slot, targets)
        if targets.x == nil and targets[1] == nil then targets = { targets } end
        if targets.uid then targets = { targets } end
        local darts = 3 + (slot - 1)
        for i = 1, darts do
            local t = targets[((i - 1) % #targets) + 1]
            if t.dead then
                for _, o in ipairs(b:enemies_of(c)) do t = o break end
            end
            if t and not t.dead then
                if b:find_effect(t, "Shield") then
                    b:log("  The dart fizzles against %s's Shield.", t.name)
                elseif b.ai and b.ai.try_shield_mm and b.ai.try_shield_mm(b, t, c) then
                    b:log("  The dart fizzles against %s's Shield.", t.name)
                else
                    b:deal(c, t, { { b.dice:d(4) + 1, "force" } }, { spell = "magic_missile" })
                end
            end
        end
    end }

S.shield = { name = "Shield", level = 1, page = 161, casting = "reaction", range = 0, tags = { "defense" },
    cast = function(b, c)
        b:add_effect(c, { name = "Shield", ac = 5, expires = b:next_turn(c, "start") })
    end }

S.sleep = { name = "Sleep", level = 1, page = 163, casting = "action", range = 60, conc = true, area = { "sphere", 5 },
    tags = { "control", "area" },
    cast = function(b, c, slot, p)
        local conc = b:start_concentration(c, "sleep")
        local dc = creature.spell_dc(c)
        for _, t in ipairs(M.sphere(b, p.x, p.y, 5)) do
            if t.side ~= c.side then
                local immune = t.condition_immune.exhaustion or t.species == "elf" or (t.traits and t.traits.trance)
                if not immune and not b:save(t, "wis", dc, { kind = "sleep" }) then
                    b:log("  %s's eyelids droop (Incapacitated).", t.name)
                    b:add_effect(t, { name = "Drowsy", conds = { incapacitated = true }, ends_on_damage = true,
                        conc_of = c, expires = b:next_turn(t, "end"),
                        on_end = function(bb, holder, why)
                            if why == "expired" and c.conc == conc and not holder.dead then
                                if not bb:save(holder, "wis", dc, { kind = "sleep" }) then
                                    bb:log("  %s falls asleep (Unconscious).", holder.name)
                                    bb:add_effect(holder, { name = "Asleep", conds = { unconscious = true },
                                        ends_on_damage = true, conc_of = c, shakeable = true })
                                end
                            end
                        end })
                end
            end
        end
    end }

S.burning_hands = { name = "Burning Hands", level = 1, page = 114, casting = "action", range = 0, area = { "cone", 15 },
    tags = { "damage", "area" },
    cast = function(b, c, slot, p)
        save_damage(b, c, S.burning_hands, M.cone(b, c, p.x, p.y, 15), "dex", creature.spell_dc(c), { { 2 + slot, 6, 0, "fire" } })
    end }

S.thunderwave = { name = "Thunderwave", level = 1, page = 169, casting = "action", range = 0, area = { "cube", 15 },
    tags = { "damage", "area" },
    cast = function(b, c, slot, p)
        local targets = M.cube_from(b, c, p.x, p.y, 15)
        save_damage(b, c, S.thunderwave, targets, "con", creature.spell_dc(c), { { 1 + slot, 8, 0, "thunder" } },
            { on_fail = function(t) b:push(c, t, 10) end })
    end }

S.mage_armor = { name = "Mage Armor", level = 1, page = 145, casting = "precast", range = 5, tags = { "precast_self" },
    cast = function(b, c, slot, t)
        (t or c).mage_armor = true
    end }

S.chromatic_orb = { name = "Chromatic Orb", level = 1, page = 115, casting = "action", range = 90, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local leaps = slot
        local hit_already = {}
        local function throw(tgt)
            hit_already[tgt] = true
            local dtype = "fire"
            for _, ty in ipairs({ "fire", "cold", "lightning", "acid", "thunder", "poison" }) do
                if not tgt.resist[ty] and not tgt.immune[ty] then dtype = ty break end
            end
            local faces
            local prof = spell_attack(c, "Chromatic Orb", "ranged", 0, 8, dtype, 90)
            prof.damage = {}
            local res = b:attack(c, tgt, prof, { on_hit = function(bb, _, target, r)
                local total
                total, faces = bb.dice:roll((r.crit and 2 or 1) * (2 + slot), 8)
                bb:deal(c, target, { { total, dtype } }, { spell = "chromatic_orb" })
            end })
            -- Leap if two dice matched.
            if res.hit and faces and leaps > 0 then
                local seen, dup = {}, false
                for _, f in ipairs(faces) do
                    if seen[f] then dup = true end
                    seen[f] = true
                end
                if dup then
                    leaps = leaps - 1
                    for _, o in ipairs(b:enemies_of(c)) do
                        if not hit_already[o] and b:dist(o, tgt) <= 30 then
                            b:log("  The orb leaps to %s.", o.name)
                            throw(o)
                            break
                        end
                    end
                end
            end
        end
        throw(t)
    end }

S.ice_knife = { name = "Ice Knife", level = 1, page = 141, casting = "action", range = 60, tags = { "damage", "single", "area" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Ice Knife", "ranged", 1, 10, "piercing", 60)
        local x, y = t.x, t.y
        b:attack(c, t, prof)
        local blast = b:roll_parts({ { 1 + slot, 6, 0, "cold" } })
        for _, o in ipairs(M.sphere(b, x, y, 5)) do
            if not o.dead and not b:save(o, "dex", creature.spell_dc(c), { kind = "ice_knife" }) then
                b:deal(c, o, blast, { spell = "ice_knife" })
            end
        end
    end }

S.ray_of_sickness = { name = "Ray of Sickness", level = 1, page = 158, casting = "action", range = 60, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Ray of Sickness", "ranged", 1 + slot, 8, "poison", 60)
        b:attack(c, t, prof, { on_hit = function(_, _, tgt)
            if not tgt.condition_immune.poisoned then
                b:add_effect(tgt, { name = "Poisoned", conds = { poisoned = true }, expires = b:next_turn(c, "end") })
            end
        end })
    end }

S.hideous_laughter = { name = "Hideous Laughter", level = 1, page = 140, casting = "action", range = 30, conc = true,
    tags = { "control", "single" },
    cast = function(b, c, slot, t)
        local dc = creature.spell_dc(c)
        b:start_concentration(c, "hideous_laughter")
        if not b:save(t, "wis", dc, { kind = "hideous_laughter" }) then
            b:log("  %s collapses laughing (Prone, Incapacitated).", t.name)
            b:knock_prone(t, "Hideous Laughter")
            b:add_effect(t, { name = "Hideous Laughter", conds = { incapacitated = true, prone = true }, conc_of = c,
                save_end = { ab = "wis", dc = dc }, save_on_damage = { ab = "wis", dc = dc } })
        else
            b:end_concentration(c, "no targets")
        end
    end }

S.false_life = { name = "False Life", level = 1, page = 129, casting = "action", range = 0, tags = { "precast_self", "temp" },
    cast = function(b, c, slot)
        b:give_temp(c, b.dice:roll(2, 4) + 4 + 5 * (slot - 1))
    end }

S.color_spray = { name = "Color Spray", level = 1, page = 116, casting = "action", range = 0, area = { "cone", 15 },
    tags = { "control", "area" },
    cast = function(b, c, slot, p)
        local dc = creature.spell_dc(c)
        for _, t in ipairs(M.cone(b, c, p.x, p.y, 15)) do
            if not b:save(t, "con", dc, { kind = "blinded" }) then
                b:add_effect(t, { name = "Blinded", conds = { blinded = true }, expires = b:next_turn(c, "end") })
            end
        end
    end }

S.grease = { name = "Grease", level = 1, page = 137, casting = "action", range = 60, area = { "square", 10 },
    tags = { "control", "area" },
    cast = function(b, c, slot, p)
        local dc = creature.spell_dc(c)
        local function slip(bb, z, o)
            if not bb:has(o, "prone") and not bb:save(o, "dex", dc, { kind = "prone" }) then
                bb:knock_prone(o, "Grease")
            end
        end
        local z = b:add_zone({ kind = "grease", cells = M.square_cells(p.x, p.y, 2), difficult = true,
            on_enter = slip, on_end_turn = slip, rounds = 10 })
        for _, o in ipairs(b.creatures) do
            if not o.dead and z.cells[o.x .. "," .. o.y] then
                slip(b, z, o)
            end
        end
    end }

S.bless = { name = "Bless", level = 1, page = 113, casting = "action", range = 30, conc = true, tags = { "buff", "multi" },
    cast = function(b, c, slot, targets)
        b:start_concentration(c, "bless")
        for i = 1, math.min(#targets, 2 + slot) do
            b:add_effect(targets[i], { name = "Bless", bless = true, conc_of = c })
        end
    end }

S.bane = { name = "Bane", level = 1, page = 112, casting = "action", range = 30, conc = true, tags = { "debuff", "multi" },
    cast = function(b, c, slot, targets)
        b:start_concentration(c, "bane")
        local dc = creature.spell_dc(c)
        local any = false
        for i = 1, math.min(#targets, 2 + slot) do
            if not b:save(targets[i], "cha", dc, { kind = "bane" }) then
                b:add_effect(targets[i], { name = "Bane", bane = true, conc_of = c })
                any = true
            end
        end
        if not any then
            b:end_concentration(c, "no targets")
        end
    end }

-- Command (p. 116): Grovel -- the target falls Prone and ends its turn.
S.command = { name = "Command", level = 1, page = 116, casting = "action", range = 60, tags = { "control", "single" },
    cast = function(b, c, slot, targets)
        if targets.uid then targets = { targets } end
        local dc = creature.spell_dc(c)
        for i = 1, math.min(#targets, slot) do
            local t = targets[i]
            if not b:save(t, "wis", dc, { kind = "command" }) then
                b:log("  %s obeys: Grovel!", t.name)
                b:add_effect(t, { name = "Commanded", command = "grovel", expires = b:next_turn(t, "end") })
            end
        end
    end }

S.cure_wounds = { name = "Cure Wounds", level = 1, page = 121, casting = "action", range = 5, tags = { "heal" },
    cast = function(b, c, slot, t)
        b:heal(c, t, heal_amount(b, c, 2 * slot, 8, slot))
    end }

S.healing_word = { name = "Healing Word", level = 1, page = 139, casting = "bonus", range = 60, tags = { "heal" },
    cast = function(b, c, slot, t)
        b:heal(c, t, heal_amount(b, c, 2 * slot, 4, slot))
    end }

S.guiding_bolt = { name = "Guiding Bolt", level = 1, page = 138, casting = "action", range = 120, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Guiding Bolt", "ranged", 3 + slot, 6, "radiant", 120)
        b:attack(c, t, prof, { on_hit = function(_, _, tgt)
            b:add_effect(tgt, { name = "Guided", marked_adv = true, expires = b:next_turn(c, "end") })
        end })
    end }

-- Inflict Wounds (p. 143): a Constitution save in the 2024 rules.
S.inflict_wounds = { name = "Inflict Wounds", level = 1, page = 143, casting = "action", range = 5, tags = { "damage", "single", "melee" },
    cast = function(b, c, slot, t)
        save_damage(b, c, S.inflict_wounds, { t }, "con", creature.spell_dc(c), { { 1 + slot, 10, 0, "necrotic" } })
    end }

S.sanctuary = { name = "Sanctuary", level = 1, page = 159, casting = "bonus", range = 30, tags = { "protect" },
    cast = function(b, c, slot, t)
        b:add_effect(t, { name = "Sanctuary", sanctuary_dc = creature.spell_dc(c), expires = { who = c, at = "start", n = 10 } })
    end }

S.shield_of_faith = { name = "Shield of Faith", level = 1, page = 162, casting = "bonus", range = 60, conc = true, tags = { "buff", "single" },
    cast = function(b, c, slot, t)
        b:start_concentration(c, "shield_of_faith")
        b:add_effect(t, { name = "Shield of Faith", ac = 2, conc_of = c })
    end }

for _, id in ipairs({ "detect_magic", "disguise_self", "silent_image", "longstrider", "expeditious_retreat",
                      "feather_fall", "find_familiar", "identify", "protection_from_evil_and_good" }) do
    S[id] = { name = id, level = 1, casting = "action", range = 0, tags = { "utility" }, utility = true }
end

-- Level 2 ------------------------------------------------------------------------------------

S.aid = { name = "Aid", level = 2, page = 107, casting = "precast", range = 30, tags = { "precast_party" },
    cast = function(b, c, slot, targets)
        for i = 1, math.min(3, #targets) do
            local t = targets[i]
            local n = 5 * (slot - 1)
            t.hp_max = t.hp_max + n
            t.hp = t.hp + n
        end
    end }

S.hold_person = { name = "Hold Person", level = 2, page = 141, casting = "action", range = 60, conc = true,
    tags = { "control", "single", "humanoid" },
    cast = function(b, c, slot, targets)
        if targets.uid then targets = { targets } end
        local dc = creature.spell_dc(c)
        b:start_concentration(c, "hold_person")
        local any = false
        for i = 1, math.min(#targets, slot - 1) do
            local t = targets[i]
            if t.type == "humanoid" and not b:save(t, "wis", dc, { kind = "paralyzed" }) then
                b:log("  %s is Paralyzed.", t.name)
                b:add_effect(t, { name = "Hold Person", conds = { paralyzed = true }, conc_of = c,
                                  save_end = { ab = "wis", dc = dc } })
                any = true
            end
        end
        if not any then
            b:end_concentration(c, "no targets")
        end
    end }

S.spiritual_weapon = { name = "Spiritual Weapon", level = 2, page = 165, casting = "bonus", range = 60, conc = true,
    tags = { "damage", "summon" },
    cast = function(b, c, slot, t)
        local weapon = { x = t.x, y = t.y, dice = slot - 1 }
        b:start_concentration(c, "spiritual_weapon", { summon = weapon, spiritual_weapon = weapon })
        M.spiritual_weapon_strike(b, c, weapon, t)
    end }

function M.spiritual_weapon_strike(b, c, weapon, t)
    weapon.x, weapon.y = t.x, t.y
    local prof = spell_attack(c, "Spiritual Weapon", "melee", weapon.dice, 8, "force")
    prof.damage[1][3] = abmod(c, c.casting)
    -- The attack is made from the weapon's space, so close-combat rules use the weapon.
    b:attack(c, t, prof)
end

S.blindness_deafness = { name = "Blindness/Deafness", level = 2, page = 113, casting = "action", range = 120,
    tags = { "control", "single" },
    cast = function(b, c, slot, t)
        local dc = creature.spell_dc(c)
        if not b:save(t, "con", dc, { kind = "blinded" }) then
            b:add_effect(t, { name = "Blindness", conds = { blinded = true }, save_end = { ab = "con", dc = dc },
                              expires = { who = c, at = "start", n = 10 } })
        end
    end }

S.lesser_restoration = { name = "Lesser Restoration", level = 2, page = 144, casting = "bonus", range = 5, tags = { "cure" },
    cast = function(b, c, slot, t)
        for i = #t.effects, 1, -1 do
            local e = t.effects[i]
            if e.conds and (e.conds.blinded or e.conds.deafened or e.conds.paralyzed or e.conds.poisoned) then
                b:remove_effect(t, e, "cured")
                b:log("  %s is cured of %s.", t.name, e.name)
                break
            end
        end
    end }

S.prayer_of_healing = { name = "Prayer of Healing", level = 2, page = 154, casting = "rest", range = 30, tags = { "rest_heal" },
    cast = function(b, c, slot, targets)
        for i = 1, math.min(5, #targets) do
            b:heal(c, targets[i], b.dice:roll(2 + (slot - 2), 8) + ((c.sub and c.sub.disciple_of_life) and (2 + slot) or 0))
        end
    end }

S.warding_bond = { name = "Warding Bond", level = 2, page = 173, casting = "precast", range = 5, tags = { "precast_ally" },
    cast = function(b, c, slot, t)
        b:add_effect(t, { name = "Warding Bond", warding_bond = true, ac = 1, source = c })
    end }

S.scorching_ray = { name = "Scorching Ray", level = 2, page = 159, casting = "action", range = 120, tags = { "damage", "multi_attack" },
    cast = function(b, c, slot, targets)
        if targets.uid then targets = { targets } end
        local rays = 3 + (slot - 2)
        for i = 1, rays do
            local t = targets[((i - 1) % #targets) + 1]
            if t.dead then
                local alive = b:enemies_of(c)
                t = alive[1]
            end
            if t then
                b:attack(c, t, spell_attack(c, "Scorching Ray", "ranged", 2, 6, "fire", 120))
            end
        end
    end }

S.shatter = { name = "Shatter", level = 2, page = 161, casting = "action", range = 60, area = { "sphere", 10 },
    tags = { "damage", "area" },
    cast = function(b, c, slot, p)
        save_damage(b, c, S.shatter, M.sphere(b, p.x, p.y, 10), "con", creature.spell_dc(c), { { 1 + slot, 8, 0, "thunder" } },
            { dis_for = function(t) return t.type == "construct" end })
    end }

S.misty_step = { name = "Misty Step", level = 2, page = 150, casting = "bonus", range = 30, tags = { "escape" },
    cast = function(b, c, slot, p)
        b:log("  %s vanishes in silver mist and reappears.", c.name)
        local carry = p.carry
        c.x, c.y = p.x, p.y
        if carry and c.res.folded_path and c.res.folded_path > 0 then
            c.res.folded_path = c.res.folded_path - 1
            local spot = p.carry_spot
            if spot then
                carry.x, carry.y = spot.x, spot.y
                b:log("  %s is folded along the path too.", carry.name)
            end
        end
    end }

S.web = { name = "Web", level = 2, page = 174, casting = "action", range = 60, conc = true, area = { "cube", 20 },
    tags = { "control", "area" },
    cast = function(b, c, slot, p)
        local dc = creature.spell_dc(c)
        local conc = b:start_concentration(c, "web")
        local stuck = {}
        local function snare(bb, z, o)
            if o.side == c.side and o == c then return end
            if stuck[o] == bb.round .. ":" .. tostring(bb.active and bb.active.uid) then return end
            stuck[o] = bb.round .. ":" .. tostring(bb.active and bb.active.uid)
            if not bb:find_effect(o, "Webbed") and not bb:save(o, "dex", dc, { kind = "restrained" }) then
                bb:log("  %s is stuck in the webs (Restrained).", o.name)
                bb:add_effect(o, { name = "Webbed", conds = { restrained = true }, zone = z, web_dc = dc })
            end
        end
        local z = b:add_zone({ kind = "web", cells = M.square_cells(p.x, p.y, 4), difficult = true, conc = conc,
            on_enter = snare, on_start = snare })
        for _, o in ipairs(b.creatures) do
            if not o.dead and z.cells[o.x .. "," .. o.y] then
                snare(b, z, o)
            end
        end
    end }

S.mirror_image = { name = "Mirror Image", level = 2, page = 150, casting = "action", range = 0, tags = { "defense" },
    cast = function(b, c)
        b:add_effect(c, { name = "Mirror Image", mirror_images = 3, expires = { who = c, at = "start", n = 10 } })
    end }

S.blur = { name = "Blur", level = 2, page = 114, casting = "action", range = 0, conc = true, tags = { "defense" },
    cast = function(b, c)
        b:start_concentration(c, "blur")
        b:add_effect(c, { name = "Blur", blur = true, conc_of = c })
    end }

S.flaming_sphere = { name = "Flaming Sphere", level = 2, page = 132, casting = "action", range = 60, conc = true,
    tags = { "damage", "summon" },
    cast = function(b, c, slot, t)
        local dc = creature.spell_dc(c)
        local sphere = { x = t.x, y = t.y, dice = slot }
        sphere.damage_on_end = function(bb, caster, victim)
            save_damage(bb, caster, S.flaming_sphere, { victim }, "dex", dc, { { sphere.dice, 6, 0, "fire" } })
        end
        sphere.ram = function(bb, caster, victim)
            sphere.x, sphere.y = victim.x, victim.y
            save_damage(bb, caster, S.flaming_sphere, { victim }, "dex", dc, { { sphere.dice, 6, 0, "fire" } })
        end
        b:start_concentration(c, "flaming_sphere", { summon = sphere, sphere = sphere })
    end }

S.acid_arrow = { name = "Acid Arrow", level = 2, page = 107, casting = "action", range = 90, tags = { "damage", "single" },
    cast = function(b, c, slot, t)
        local prof = spell_attack(c, "Acid Arrow", "ranged", 2 + slot, 4, "acid", 90)
        b:attack(c, t, prof, {
            on_hit = function(_, _, tgt)
                b:add_effect(tgt, { name = "Acid", source = c, end_turn_damage = { slot, 4, 0, "acid" },
                                    expires = b:next_turn(tgt, "end") })
            end,
            on_miss = function(_, _, tgt)
                b:deal(c, tgt, half(b:roll_parts(prof.damage)), { spell = "acid_arrow" })
            end })
    end }

S.mind_spike = { name = "Mind Spike", level = 2, page = 149, casting = "action", range = 120, conc = true, tags = { "damage", "single", "save" },
    cast = function(b, c, slot, t)
        b:start_concentration(c, "mind_spike")
        save_damage(b, c, S.mind_spike, { t }, "wis", creature.spell_dc(c), { { 1 + slot, 8, 0, "psychic" } })
    end }

S.ray_of_enfeeblement = { name = "Ray of Enfeeblement", level = 2, page = 157, casting = "action", range = 60, conc = true,
    tags = { "debuff", "single" },
    cast = function(b, c, slot, t)
        local dc = creature.spell_dc(c)
        b:start_concentration(c, "ray_of_enfeeblement")
        if b:save(t, "con", dc, { kind = "enfeeble" }) then
            b:add_effect(t, { name = "Weakened", enfeeble_dis_next = true, expires = b:next_turn(c, "start") })
            b:end_concentration(c, "saved")
        else
            b:add_effect(t, { name = "Ray of Enfeeblement", enfeebled = true, conc_of = c, save_end = { ab = "con", dc = dc } })
        end
    end }

S.magic_weapon = { name = "Magic Weapon", level = 2, page = 146, casting = "precast", range = 5, tags = { "precast_ally" },
    cast = function(b, c, slot, t)
        t.magic_weapon = 1
    end }

for _, id in ipairs({ "invisibility", "darkness", "silence", "see_invisibility", "knock", "levitate",
                      "spider_climb", "suggestion", "enhance_ability", "augury" }) do
    S[id] = { name = id, level = 2, casting = "action", range = 0, tags = { "utility" }, utility = true }
end

for id, s in pairs(S) do
    s.id = id
end

-- Spell slots ------------------------------------------------------------------------------

-- Lowest slot of at least `level` (or exactly `level` with exact=true). Returns the slot level or nil.
function M.find_slot(c, level, exact)
    if not c.res.slots then
        return nil
    end
    for l = level, #c.res.slots do
        if (c.res.slots[l] or 0) > 0 then
            return l
        end
        if exact then
            return nil
        end
    end
    return nil
end

function M.spend_slot(c, level)
    c.res.slots[level] = c.res.slots[level] - 1
end

function M.has_spell(c, id)
    return c.known_spells and c.known_spells[id] or false
end

return M
