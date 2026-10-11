-- Creatures for the rules engine: player characters built from a sheet using
-- the SRD 5.2.1 class rules, and monsters built from their stat blocks.
-- Pure data plus small queries; the battle module runs the rules.

local classes = require "game.rules.data.classes"
local equipment = require "game.rules.data.equipment"
local monsters = require "game.rules.data.monsters"
local subclasses = require "game.rules.subclasses"

local M = {}

local ABILITIES = { "str", "dex", "con", "int", "wis", "cha" }
M.ABILITIES = ABILITIES

local SIZE_RANK = { tiny = 1, small = 2, medium = 3, large = 4, huge = 5, gargantuan = 6 }
M.SIZE_RANK = SIZE_RANK

local function set_of(list)
    local s = {}
    for _, v in ipairs(list or {}) do
        s[v] = true
    end
    return s
end
M.set_of = set_of

function M.mod(score)
    return math.floor((score - 10) / 2)
end

local next_id = 0
local function new_id()
    next_id = next_id + 1
    return next_id
end

local function base(t)
    t.uid = new_id()
    t.effects = {}
    t.temp = 0
    t.dead = false
    t.down = false
    t.stable = false
    t.ds = { s = 0, f = 0 }
    t.res = t.res or {}
    t.sub = t.sub or {}
    t.stats = { dealt = 0, taken = 0, healed = 0, downs = 0, crits = 0, hits = 0, misses = 0, kills = 0 }
    return t
end

function M.abmod(c, ab)
    return M.mod(c.abilities[ab])
end

-- Saving throw bonus before situational effects.
function M.save_bonus(c, ab)
    if c.save_override and c.save_override[ab] then
        return c.save_override[ab]
    end
    local b = M.abmod(c, ab)
    if c.save_prof[ab] then
        b = b + c.pb
    end
    return b + (c.item_saves or 0)    -- Cloak of Protection, Stone of Good Luck (A13)
end

-- Base Armor Class from armor, shield and fighting style; effects are added by the battle.
function M.base_ac(c)
    if c.ac_fixed then
        return c.ac_fixed
    end
    local dex = M.abmod(c, "dex")
    local ac
    local armor = c.armor and equipment.armor[c.armor]
    if armor then
        local d = dex
        if armor.category == "heavy" then
            d = 0                         -- Heavy armor ignores Dexterity (p. 92)
        elseif armor.dex_max then
            d = math.min(dex, armor.dex_max)
        end
        ac = armor.base + d
    elseif c.mage_armor then
        ac = 13 + dex                     -- Mage Armor (p. 145)
    else
        ac = 10 + dex
    end
    if c.shield then
        ac = ac + equipment.SHIELD_AC
    end
    if armor and c.feats.defense then
        ac = ac + 1                       -- Defense fighting style (p. 88)
    end
    return ac
end

function M.spell_dc(c)
    return 8 + c.pb + M.abmod(c, c.casting)
end

function M.spell_attack(c)
    return c.pb + M.abmod(c, c.casting)
end

-- Can this character use the weapon's mastery property?
function M.has_mastery(c, weapon_id)
    return c.masteries and c.masteries[weapon_id] or false
end

-- An attack profile for a PC wielding a weapon. two_handed: use the Versatile die.
function M.weapon_attack(c, weapon_id, opts)
    opts = opts or {}
    local w = equipment.weapons[weapon_id]
    assert(w, "unknown weapon " .. tostring(weapon_id))
    local str, dex = M.abmod(c, "str"), M.abmod(c, "dex")
    local ab_name
    if w.finesse then
        ab_name = dex >= str and "dex" or "str"
    elseif w.kind == "ranged" then
        ab_name = "dex"
    else
        ab_name = "str"
    end
    local ability = M.abmod(c, ab_name)
    local thrown = opts.thrown and w.thrown
    local ranged = w.kind == "ranged" or thrown
    local to_hit = ability + c.pb + (c.magic_weapon or 0)
    if ranged and c.feats.archery then
        to_hit = to_hit + 2               -- Archery (p. 87)
    end
    local die = w.damage[2]
    local two_handed = w.two_handed or (opts.two_handed and w.versatile)
    if opts.two_handed and w.versatile then
        die = w.versatile
    end
    local dmg_bonus = ability + (c.magic_weapon or 0)
    if ranged and c.item_bow_damage and (weapon_id == "longbow" or weapon_id == "shortbow") then
        dmg_bonus = dmg_bonus + c.item_bow_damage   -- Bracers of Archery (A13)
    end
    if opts.offhand and not c.feats.two_weapon_fighting and ability > 0 then
        dmg_bonus = (c.magic_weapon or 0)  -- Light extra attack adds no positive modifier (p. 89)
    end
    local heavy_penalty = w.heavy and ((not ranged and c.abilities.str < 13) or (ranged and c.abilities.dex < 13))
    return {
        id = weapon_id, name = w.name, weapon = w, is_weapon = true,
        kind = ranged and "ranged" or "melee",
        to_hit = to_hit, ability = ability, ability_name = ab_name,
        damage = { { w.damage[1], die, dmg_bonus, w.damage[3] } },
        reach = w.reach and 10 or 5,
        range = (ranged and w.range) or nil,
        two_handed = two_handed and not ranged,
        gwf = c.feats.great_weapon_fighting and two_handed and not ranged,
        mastery = M.has_mastery(c, weapon_id) and w.mastery or nil,
        light = w.light, finesse = w.finesse,
        heavy_disadvantage = heavy_penalty,
        offhand = opts.offhand,
        crit_range = c.crit_range or 20,
    }
end

-- Player characters ------------------------------------------------------------------

-- sheet = { name, player, class, level, subclass, species, background, abilities,
--   armor, shield, weapons = { main, offhand, ranged, thrown }, masteries = {...},
--   feats = {...}, fighting_style, divine_order, cantrips = {...}, prepared = {...},
--   potions }
function M.new_pc(sheet)
    local cls = classes[sheet.class]
    assert(cls, "unknown class " .. tostring(sheet.class))
    local level = sheet.level
    local row = cls.levels[level]
    local species = classes.species[sheet.species or "human"]
    local c = base({
        name = sheet.name, player = sheet.player, side = "party", pc = true,
        class = sheet.class, class_name = cls.name, level = level, subclass = sheet.subclass,
        species = sheet.species, size = species.size, type = "humanoid",
        abilities = {}, pb = row.pb, speed = species.speed,
        save_prof = set_of(cls.saves), save_override = nil,
        armor = sheet.armor, shield = sheet.shield or false,
        weapons = sheet.weapons or {},
        masteries = set_of(sheet.masteries),
        feats = set_of(sheet.feats), traits = set_of(species.traits),
        resist = set_of(species.resist), vulnerable = {}, immune = {}, condition_immune = {},
        casting = cls.casting, cantrips = sheet.cantrips or {}, prepared = sheet.prepared or {},
        tags = {},
    })
    for _, ab in ipairs(ABILITIES) do
        c.abilities[ab] = sheet.abilities[ab]
    end
    if sheet.fighting_style then
        c.feats[sheet.fighting_style] = true
    end
    if sheet.divine_order == "protector" then
        c.divine_order = "protector"
    elseif sheet.divine_order then
        c.divine_order = sheet.divine_order
    end
    -- Hit points: max die + Con at level 1, then fixed value + Con per level (p. 23).
    local con = M.mod(c.abilities.con)
    local hp = cls.hit_die + con + (level - 1) * (cls.fixed_hp + con)
    if c.traits.dwarven_toughness then
        hp = hp + level                   -- Dwarven Toughness (p. 84)
    end
    c.hp_max, c.hp = hp, hp
    -- Hit Point Dice: one per level, spent on Short Rests, all back on a Long Rest (SRD 5.2.1).
    c.hd = { die = cls.hit_die, max = level, left = level }
    -- Class resources.
    c.res.potions = sheet.potions or 0
    if sheet.class == "fighter" then
        c.res.second_wind = row.second_wind
        c.res.second_wind_max = row.second_wind
        c.res.action_surge = level >= 2 and 1 or 0
    elseif sheet.class == "rogue" then
        c.sneak_dice = row.sneak
    elseif sheet.class == "cleric" then
        c.res.channel = row.channel or 0
        c.res.channel_max = row.channel or 0
    end
    if row.slots then
        c.res.slots = {}
        c.slots_max = {}
        for i, n in ipairs(row.slots) do
            c.res.slots[i] = n
            c.slots_max[i] = n
        end
    end
    if c.feats.magic_initiate_cleric or c.feats.magic_initiate_wizard then
        c.res.mi_free = sheet.mi_spell and 1 or 0
        c.mi_spell = sheet.mi_spell
    end
    c.crit_range = 20
    c.known_spells = {}
    for _, s in ipairs(c.cantrips) do
        c.known_spells[s] = true
    end
    for _, s in ipairs(c.prepared) do
        c.known_spells[s] = true
    end
    if c.mi_spell then
        c.known_spells[c.mi_spell] = true
    end
    if c.casting == nil and c.mi_spell then
        c.casting = sheet.mi_ability or "int"
    end
    -- Subclass features (level 3+).
    if level >= 3 and sheet.subclass then
        subclasses.apply(c, sheet.subclass, sheet)
    end
    c.mage_armor = sheet.mage_armor or false
    -- What a Long Rest restores to (game/rules/rest.lua).
    c.res_full = {}
    for k, v in pairs(c.res) do
        if type(v) == "table" then
            local t = {}
            for i, n in pairs(v) do
                t[i] = n
            end
            c.res_full[k] = t
        else
            c.res_full[k] = v
        end
    end
    return c
end

-- Monsters -----------------------------------------------------------------------------

function M.new_monster(id, name_suffix)
    local d = monsters[id]
    assert(d, "unknown monster " .. tostring(id))
    local c = base({
        name = d.name .. (name_suffix or ""), monster_id = id, side = "foes", pc = false,
        size = d.size, type = d.type, tags = set_of(d.tags),
        abilities = {}, pb = d.pb, speed = d.speed,
        save_prof = {}, save_override = d.saves,
        ac_fixed = d.ac, hp = d.hp, hp_max = d.hp,
        resist = set_of(d.resist), vulnerable = set_of(d.vulnerable), immune = set_of(d.immune),
        condition_immune = set_of(d.condition_immune),
        traits = set_of(d.traits), feats = {}, masteries = {},
        attacks = d.attacks, multiattack = d.multiattack,
        bonus_actions = set_of(d.bonus), reactions = set_of(d.reactions),
        cr = d.cr, xp = d.xp, role = d.role, data = d,
    })
    for _, ab in ipairs(ABILITIES) do
        c.abilities[ab] = d.abilities[ab]
    end
    c.res.ammo = {}
    for _, a in ipairs(d.attacks) do
        if a.ammo then
            c.res.ammo[a.id] = a.ammo
        end
    end
    c.crit_range = 20
    return c
end

-- A monster attack as an attack profile.
function M.monster_attack(c, a, as_ranged)
    local ranged = a.kind == "ranged" or (a.kind == "both" and as_ranged)
    return {
        id = a.id, name = a.name, is_weapon = true, monster_attack = a,
        kind = ranged and "ranged" or "melee",
        to_hit = a.to_hit,
        damage = a.damage,
        reach = a.reach or 5,
        range = ranged and a.range or nil,
        adv_bonus = a.adv_bonus,
        rider = a.rider,
        prone_max_size = a.prone_max_size,
        -- The Vale Bestiary (A13): grapple (escape DC), pull, mark, drain, swarm damage.
        grapple = a.grapple, pull = a.pull, mark = a.mark, drain = a.drain,
        bloodied_damage = a.bloodied_damage, adv_vs_grappled = a.adv_vs_grappled,
        crit_range = 20,
        thrown_ammo = a.ammo and a.id or nil,
    }
end

return M
