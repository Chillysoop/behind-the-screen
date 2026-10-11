-- A character sheet for the DM (real-session pass): everything about a hero as the rules
-- engine has it at the party's level, laid out the way a 5e sheet reads. The sheet view is
-- game/ui/sheet_view.lua; the numbers are the same ones game night's checks and fights use.
-- Pure Lua.

local party = require "game.rules.party"
local creature = require "game.rules.creature"
local classes = require "game.rules.data.classes"
local equipment = require "game.rules.data.equipment"
local spells = require "game.rules.spells"
local subclasses = require "game.rules.subclasses"
local skills = require "game.rules.skills"
local util = require "game.model.util"

local M = {}

M.ABILITIES = { "str", "dex", "con", "int", "wis", "cha" }
M.ABILITY_NAMES = { str = "Strength", dex = "Dexterity", con = "Constitution", int = "Intelligence", wis = "Wisdom",
                    cha = "Charisma" }
M.SKILL_ORDER = { "acrobatics", "animal_handling", "arcana", "athletics", "deception", "history", "insight",
                  "intimidation", "investigation", "medicine", "nature", "perception", "performance", "persuasion",
                  "religion", "sleight_of_hand", "stealth", "survival" }

-- Class features in our own words (SRD 5.2.1 "Classes"; pages in classes.lua).
M.FEATURES = {
    fighting_style = { "Fighting Style", "Great Weapon Fighting: when you roll damage for a two-handed melee weapon, treat any 1 or 2 on a damage die as a 3." },
    second_wind = { "Second Wind", "As a Bonus Action, regain 1d10 + your Fighter level Hit Points. A few uses, back after a rest." },
    weapon_mastery = { "Weapon Mastery", "You can use the mastery property of a few weapons you know well (Graze, Nick, Vex, Slow...)." },
    action_surge = { "Action Surge", "Once per rest, take one extra action on your turn." },
    tactical_mind = { "Tactical Mind", "When you fail an ability check, spend a use of Second Wind to add 1d10 to it." },
    expertise = { "Expertise", "Your Proficiency Bonus is doubled for two of your skills." },
    sneak_attack = { "Sneak Attack", "Once per turn, deal extra damage with a Finesse or Ranged weapon when you have Advantage or an ally is next to the target." },
    thieves_cant = { "Thieves' Cant", "The secret language and signs of the underworld." },
    cunning_action = { "Cunning Action", "Dash, Disengage or Hide as a Bonus Action." },
    steady_aim = { "Steady Aim", "Give up your movement for Advantage on your next attack this turn." },
    spellcasting = { "Spellcasting", "You prepare spells each day and cast them with spell slots." },
    divine_order = { "Divine Order: Protector", "Training with martial weapons and heavy armor." },
    channel_divinity = { "Channel Divinity", "Divine Spark (heal or harm 1d8 + Wisdom) or Turn Undead. Two uses, back after a rest." },
    ritual_adept = { "Ritual Adept", "Cast any Ritual spell in your spellbook without preparing it." },
    arcane_recovery = { "Arcane Recovery", "Once a day after a Short Rest, recover a few expended spell slots." },
    scholar = { "Scholar", "Expertise in one of Arcana, History, Investigation, Medicine, Nature or Religion (Thessaly: Arcana)." },
    asi = { "Ability Score Improvement", "+2 to your main ability score." },
}

M.FEATS = {
    savage_attacker = { "Savage Attacker", "Once per turn, roll a weapon's damage dice twice and use either roll." },
    alert = { "Alert", "Add your Proficiency Bonus to Initiative." },
    magic_initiate_cleric = { "Magic Initiate (Cleric)", "Two Cleric cantrips and one level 1 spell you can cast once a day for free." },
    magic_initiate_wizard = { "Magic Initiate (Wizard)", "Two Wizard cantrips and one level 1 spell you can cast once a day for free." },
}

M.TRAITS = {
    resourceful = { "Resourceful", "Heroic Inspiration after every Long Rest." },
    versatile = { "Versatile", "An extra Origin feat." },
    dwarven_resilience = { "Dwarven Resilience", "Resistance to Poison damage; Advantage on saves against being Poisoned." },
    dwarven_toughness = { "Dwarven Toughness", "+1 Hit Point per level." },
    brave = { "Brave", "Advantage on saves against being Frightened." },
    halfling_luck = { "Luck", "Reroll a 1 on a d20 Test." },
    halfling_nimbleness = { "Halfling Nimbleness", "Move through the space of larger creatures." },
    fey_ancestry = { "Fey Ancestry", "Advantage on saves against being Charmed." },
    trance = { "Trance", "Four hours of meditation instead of sleep." },
}

local function spell_name(id)
    local s = spells.list[id]
    if s and s.name and s.name ~= id then
        return s.name
    end
    return util.capitalize((string.gsub(id, "_", " ")))
end

local function signed(n)
    return skills.signed(n)
end

-- The sheet for one player's character. campaign: level, subclasses; key: "mara"...
function M.build(campaign, key)
    local p = campaign:player(key)
    local cls = p.class
    local level = campaign.level or 2
    local sub = level >= 3 and campaign.subclasses and campaign.subclasses[cls] or nil
    local raw = party.sheet(cls, level, sub)
    local c = creature.new_pc(raw)
    local items = require "game.model.items"
    items.apply(campaign, key, c)          -- magic items the hero carries (A13)
    local cdef = classes[cls]
    local out = {
        key = key, player = p.name, name = p.char or raw.name, class = cls, class_name = cdef.name, level = level,
        subclass = sub, subclass_name = sub and subclasses.list[sub] and subclasses.list[sub].name or nil,
        species = classes.species[raw.species] and classes.species[raw.species].name or raw.species,
        background = util.capitalize(raw.background or ""), pb = c.pb, speed = c.speed,
        hp_max = c.hp_max, thread = p.thread, notes = p.notes,
    }
    -- Armor Class (Thessaly casts Mage Armor before every adventuring day).
    out.ac = creature.base_ac(c) + (c.item_ac or 0)
    if cls == "wizard" then
        local with = 13 + creature.abmod(c, "dex") + (c.item_ac or 0)
        out.ac_note = "with Mage Armor; " .. util.int(out.ac) .. " without"
        out.ac = with
    end
    local init = creature.abmod(c, "dex") + (c.feats.alert and c.pb or 0)
    out.initiative = signed(init)
    out.abilities = {}
    for _, ab in ipairs(M.ABILITIES) do
        local score = c.abilities[ab]
        table.insert(out.abilities, { id = ab, name = M.ABILITY_NAMES[ab], short = string.upper(ab), score = score,
                                      mod = signed(creature.abmod(c, ab)), save = signed(creature.save_bonus(c, ab)),
                                      save_prof = c.save_prof[ab] and true or false })
    end
    out.skills = {}
    for _, sk in ipairs(M.SKILL_ORDER) do
        local m = skills.mod(cls, sk, level, sub)
        local prof = skills.PROFICIENT[cls] and skills.PROFICIENT[cls][sk] or false
        local expert = prof and ((skills.EXPERTISE[cls] and skills.EXPERTISE[cls][sk])
            or (sub and skills.SUBCLASS_EXPERTISE[sub] and skills.SUBCLASS_EXPERTISE[sub][sk])) or false
        table.insert(out.skills, { id = sk, name = skills.name(sk), mod = signed(m), ability = string.upper(skills.ABILITY[sk]),
                                   prof = prof and true or false, expert = expert and true or false })
    end
    out.passive_perception = 10 + skills.mod(cls, "perception", level, sub)
    -- Attacks.
    out.attacks = {}
    local seen = {}
    for _, slot in ipairs({ "main", "offhand", "ranged", "thrown" }) do
        local wid = raw.weapons and raw.weapons[slot]
        if wid and not seen[wid] then
            seen[wid] = true
            local prof = creature.weapon_attack(c, wid, { two_handed = slot == "main" and cls == "wizard",
                                                          thrown = slot == "thrown" })
            local d = prof.damage[1]
            local w = equipment.weapons[wid]
            local notes = {}
            if prof.mastery then
                table.insert(notes, "Mastery: " .. util.capitalize(prof.mastery))
            end
            if w.range then
                table.insert(notes, util.int(w.range[1]) .. "/" .. util.int(w.range[2]) .. " ft")
            end
            table.insert(out.attacks, { name = w.name, to_hit = signed(prof.to_hit),
                                        damage = d[1] .. "d" .. d[2] .. (d[3] ~= 0 and signed(d[3]) or "") .. " " .. (d[4] or ""),
                                        notes = table.concat(notes, ", ") })
        end
    end
    if c.casting then
        out.spell_dc = creature.spell_dc(c)
        out.spell_attack = signed(creature.spell_attack(c))
        out.cantrips, out.prepared = {}, {}
        for _, id in ipairs(raw.cantrips or {}) do
            table.insert(out.cantrips, spell_name(id))
        end
        for _, id in ipairs(raw.prepared or {}) do
            table.insert(out.prepared, spell_name(id))
        end
        if c.always_prepared then
            local extra = {}
            for id in pairs(c.always_prepared) do
                table.insert(extra, id)
            end
            table.sort(extra)
            for _, id in ipairs(extra) do
                if not util.contains(raw.prepared or {}, id) then
                    table.insert(out.prepared, spell_name(id) .. " (always)")
                end
            end
        end
        if c.mi_spell then
            out.free_spell = spell_name(c.mi_spell) .. " once a day, free (Magic Initiate)"
        end
        out.slots = {}
        for l, n in ipairs(c.slots_max or {}) do
            out.slots[l] = n
        end
    end
    -- Features: class (to this level), subclass, feats, species.
    out.features = {}
    for l = 1, level do
        for _, f in ipairs(cdef.levels[l].features or {}) do
            if f ~= "subclass" and M.FEATURES[f] then
                local ft = M.FEATURES[f]
                if not (f == "divine_order" and raw.divine_order ~= "protector") then
                    table.insert(out.features, { name = ft[1], text = ft[2], level = l })
                end
            end
        end
    end
    if sub and subclasses.list[sub] then
        for _, f in ipairs(subclasses.list[sub].features or {}) do
            table.insert(out.features, { name = f[1], text = f[2], level = 3, sub = true })
        end
    end
    for _, f in ipairs(raw.feats or {}) do
        if M.FEATS[f] then
            table.insert(out.features, { name = M.FEATS[f][1], text = M.FEATS[f][2], feat = true })
        end
    end
    local sp = classes.species[raw.species]
    for _, t in ipairs(sp and sp.traits or {}) do
        if M.TRAITS[t] then
            table.insert(out.features, { name = M.TRAITS[t][1], text = M.TRAITS[t][2], species = true })
        end
    end
    -- Gear.
    local gear = {}
    if raw.armor and equipment.armor[raw.armor] then
        table.insert(gear, equipment.armor[raw.armor].name)
    end
    if raw.shield then
        table.insert(gear, "Shield")
    end
    for _, slot in ipairs({ "main", "offhand", "ranged", "thrown" }) do
        local wid = raw.weapons and raw.weapons[slot]
        if wid then
            table.insert(gear, equipment.weapons[wid].name .. (slot == "thrown" and " (8)" or ""))
        end
    end
    if (raw.potions or 0) > 0 then
        table.insert(gear, util.int(raw.potions) .. " healing potion" .. (raw.potions > 1 and "s" or ""))
    end
    for _, it in ipairs(items.held_by(campaign, key)) do
        local d = items.def(it.id)
        if d and not it.destroyed then
            table.insert(gear, d.name .. (it.charges and (" (" .. util.int(it.charges) .. " charges)") or ""))
            table.insert(out.features, { name = d.name, text = d.text .. " (SRD 5.2.1, p. " .. util.int(d.page) .. ")", item = true })
        end
    end
    out.gear = gear
    return out
end

return M
