-- Hand-checkable rules cases for the M3 gate. Each case sets up a tiny fight,
-- forces the exact dice, and checks the engine against SRD 5.2.1. Run from the
-- project root with any Lua 5.1+ or LuaJIT interpreter:
--
--   lua tools/tests/rules_cases.lua            (prints PASS/FAIL per case)
--   lua tools/tests/rules_cases.lua json FILE  (also writes the cases as JSON)

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local battle = require "game.rules.battle"
local creature = require "game.rules.creature"
local party = require "game.rules.party"
local spells = require "game.rules.spells"
local ai = require "game.rules.ai"
local enc = require "game.rules.encounter"

local S = spells.list
local cases = {}

local function case(id, title, page, rule, fn)
    table.insert(cases, { id = id, title = title, page = page, rule = rule, fn = fn })
end

-- Helpers ----------------------------------------------------------------------------------

local function fresh()
    local b = battle.new({ seed = 1, ai = ai })
    b.keep_log = true
    return b
end

-- A PC with optional feats switched off so the dice are easy to follow.
local function pc(cls, level, sub, opts)
    opts = opts or {}
    local sheet = party.sheet(cls, level, sub)
    for k, v in pairs(opts.sheet or {}) do sheet[k] = v end
    local c = creature.new_pc(sheet)
    if not opts.keep_savage then c.feats.savage_attacker = nil end
    if not opts.keep_gwf then c.feats.great_weapon_fighting = nil end
    if not opts.keep_luck then c.traits.halfling_luck = nil end
    c.res.thrown = 8
    return c
end

local function mon(id)
    return creature.new_monster(id, "")
end

local function at(b, c, x, y)
    b:add(c, x, y)
    c.turn = { action = true, bonus = true, move = c.speed, attacks = 0 }
    return c
end

local function melee(c)
    return creature.weapon_attack(c, c.weapons.main, { two_handed = c.weapons.two_handed })
end

-- Cases --------------------------------------------------------------------------------------

case("hit-vs-ac", "An attack hits when the total meets the target's AC", "p. 14",
    "Roll d20 + modifiers; meeting or beating AC is a hit.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local g = at(b, mon("goblin_warrior"), 6, 5)         -- AC 15
        local prof = melee(f)                                -- greatsword +5
        b.dice:force(10, 3, 4)                               -- 10 + 5 = 15 vs AC 15; damage 3 + 4 + 3
        local r = b:attack(f, g, prof)
        t:eq("to-hit bonus (Str +3, PB +2)", prof.to_hit, 5)
        t:eq("15 vs AC 15 hits", r.hit, true)
        t:eq("damage 2d6 (3+4) + Str 3", r.damage, 10)
    end)

case("nat20-crit", "A natural 20 always hits and rolls the damage dice twice", "p. 7, p. 16",
    "Critical Hit: roll all of the attack's damage dice twice, then add modifiers.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(20, 1, 2, 3, 4)                         -- four d6 for a 2d6 crit
        local r = b:attack(f, o, melee(f))
        t:eq("natural 20 is a Critical Hit", r.crit, true)
        t:eq("4d6 (1+2+3+4) + 3", r.damage, 13)
    end)

case("nat1-miss", "A natural 1 always misses", "p. 7",
    "A natural 1 on an attack roll misses regardless of modifiers or AC.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 4), 5, 5)
        local z = at(b, mon("zombie"), 6, 5)                 -- AC 8
        b.dice:force(1)
        local r = b:attack(f, z, melee(f))
        t:eq("1 + 6 against AC 8 still misses", r.hit, false)
    end)

case("adv-dis", "Advantage keeps the higher d20; both together cancel", "p. 8",
    "If a roll has Advantage and Disadvantage, neither applies.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 2), 5, 5)
        local g = at(b, mon("goblin_warrior"), 6, 5)
        b:add_effect(r, { name = "Steady Aim", steady_aim = true })
        local mode = b:attack_mode(r, g, melee(r))
        t:eq("Steady Aim gives Advantage", mode, 1)
        b:add_effect(r, { name = "Poisoned", conds = { poisoned = true } })
        mode = b:attack_mode(r, g, melee(r))
        t:eq("Advantage + Poisoned cancel out", mode, 0)
        local v, a, c = b.dice:d20(1)
        t:eq("advantage keeps the higher of two rolls", v, math.max(a, c))
    end)

case("champion-19", "Champion: Improved Critical on 19 or 20", "p. 49",
    "Weapon attack rolls score a Critical Hit on a roll of 19 or 20.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 3, "champion"), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(19, 1, 1, 1, 1)
        local r = b:attack(f, o, melee(f))
        t:eq("19 is a Critical Hit", r.crit, true)
        t:eq("4d6 all ones + 3", r.damage, 7)
        local b2 = fresh()
        local f2 = at(b2, pc("fighter", 3, "banner_captain"), 5, 5)
        local o2 = at(b2, mon("ogre"), 6, 5)
        b2.dice:force(19, 1, 1)
        local r2 = b2:attack(f2, o2, melee(f2))
        t:eq("a non-Champion's 19 is just a hit", r2.crit, false)
    end)

case("gwf", "Great Weapon Fighting turns 1s and 2s into 3s", "p. 88",
    "Two-Handed or Versatile melee weapon held in two hands: any 1 or 2 on a damage die counts as 3.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2, nil, { keep_gwf = true }), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(15, 1, 2)
        local r = b:attack(f, o, melee(f))
        t:eq("2d6 of 1 and 2 count as 3 + 3, plus Str 3", r.damage, 9)
    end)

case("savage", "Savage Attacker keeps the better weapon damage roll", "p. 87",
    "Once per turn when you hit with a weapon, roll its damage dice twice and use either roll.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2, nil, { keep_savage = true }), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(15, 1, 2, 6, 5)                         -- first 2d6 = 3, second = 11
        local r = b:attack(f, o, melee(f))
        t:eq("keeps 11 over 3, plus Str 3", r.damage, 14)
        b.dice:force(15, 1, 2)
        local r2 = b:attack(f, o, melee(f))
        t:eq("only once per turn: second hit uses one roll", r2.damage, 6)
    end)

case("sneak-ally", "Sneak Attack with an ally next to the target", "pp. 61-62",
    "Once per turn: Finesse or Ranged weapon, and Advantage, or an ally within 5 feet of the target "
        .. "(not Incapacitated) without Disadvantage.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 2), 5, 5)
        local f = at(b, pc("fighter", 2), 7, 6)
        local o = at(b, mon("ogre"), 6, 5)                   -- ally Brannoc is adjacent to the ogre
        b.dice:force(15, 4, 6)                               -- shortsword d6 = 4, Sneak 1d6 = 6
        local res = b:attack(r, o, melee(r))
        t:eq("ally adjacent: Sneak Attack lands", res.sneak, true)
        t:eq("1d6 (4) + Dex 3 + Sneak 1d6 (6)", res.damage, 13)
        b.dice:force(15, 4)
        local res2 = b:attack(r, o, melee(r))
        t:eq("only once per turn", res2.sneak, nil)
    end)

case("sneak-disadvantage", "No Sneak Attack with Disadvantage, even with an ally adjacent", "pp. 61-62",
    "The ally route only works if you don't have Disadvantage on the attack roll.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 2), 5, 5)
        local f = at(b, pc("fighter", 2), 7, 6)
        local o = at(b, mon("ogre"), 6, 5)
        b:add_effect(r, { name = "Poisoned", conds = { poisoned = true } })
        b.dice:force(18, 18, 4)
        local res = b:attack(r, o, melee(r))
        t:eq("hit lands", res.hit, true)
        t:eq("no Sneak Attack", res.sneak, nil)
    end)

case("ranged-close", "Ranged attacks within 5 feet of an enemy have Disadvantage", "p. 15",
    "A ranged attack roll has Disadvantage if you're within 5 feet of an enemy who can see you and "
        .. "isn't Incapacitated.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 2), 5, 5)
        local g = at(b, mon("goblin_warrior"), 6, 5)
        local bow = creature.weapon_attack(r, "shortbow")
        t:eq("adjacent goblin: Disadvantage", (b:attack_mode(r, g, bow)), -1)
        b:add_effect(g, { name = "Asleep", conds = { unconscious = true } })
        t:eq("an Unconscious goblin doesn't count (and grants Advantage)", (b:attack_mode(r, g, bow)), 1)
    end)

case("prone", "Prone: Advantage within 5 feet, Disadvantage from farther away", "p. 186",
    "An attack roll against a Prone creature has Advantage if the attacker is within 5 feet, otherwise "
        .. "Disadvantage.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local r = at(b, pc("rogue", 2), 2, 5)
        local g = at(b, mon("goblin_warrior"), 6, 5)
        b:knock_prone(g, "test")
        t:eq("fighter adjacent: Advantage", (b:attack_mode(f, g, melee(f))), 1)
        t:eq("rogue 20 feet away with a bow: Disadvantage", (b:attack_mode(r, g, creature.weapon_attack(r, "shortbow"))), -1)
    end)

case("paralyzed-autocrit", "Hits on a Paralyzed creature within 5 feet are Critical Hits", "p. 186",
    "Attack rolls against a Paralyzed creature have Advantage; any hit within 5 feet is a Critical Hit.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local bc = at(b, mon("bandit_captain"), 6, 5)
        b:add_effect(bc, { name = "Hold Person", conds = { paralyzed = true } })
        bc.reaction_used = true                              -- no Parry while Paralyzed anyway
        b.dice:force(11, 9, 1, 1, 1, 1)                      -- Advantage: keeps 11; 11 + 5 = 16 vs AC 15
        local r = b:attack(f, bc, melee(f))
        t:eq("hit becomes a Critical Hit", r.crit, true)
        t:eq("4d6 all ones + 3", r.damage, 7)
    end)

case("resist-vuln", "Resistance halves (round down), Vulnerability doubles", "p. 17",
    "Adjustments first, then Resistance, then Vulnerability.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)                -- Dwarf: Resistance to Poison
        local sk = at(b, mon("skeleton"), 6, 5)               -- Vulnerable to Bludgeoning
        local before = c.hp
        b:deal(sk, c, { { 9, "poison" } })
        t:eq("9 Poison to a dwarf: 4", before - c.hp, 4)
        b.dice:force(15, 4)                                   -- mace 1d6 = 4, + Str 2 = 6, doubled
        local r = b:attack(c, sk, melee(c))
        t:eq("mace on a skeleton: (4 + 2) x 2 = 12", r.damage, 12)
        t:eq("skeleton (13 HP) hangs on at 1", sk.hp, 1)
    end)

case("temp-hp", "Temporary Hit Points absorb damage first and don't stack", "p. 18",
    "Lose Temporary Hit Points first; receiving more lets you keep the larger amount.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)
        b:give_temp(w, 7)
        b:give_temp(w, 5)
        t:eq("keeps 7, not 12", w.temp, 7)
        local before = w.hp
        b:deal(w, w, { { 10, "fire" } })
        t:eq("7 soaked, 3 through", before - w.hp, 3)
        t:eq("no Temporary Hit Points left", w.temp, 0)
    end)

case("drop-death-saves", "Dropping to 0 and Death Saving Throws", "pp. 17-18",
    "Unconscious at 0 HP. Death save: 10+ succeeds; three successes = Stable; a 1 counts as two failures; "
        .. "a 20 regains 1 HP; damage at 0 HP is a failure (a Critical Hit, two).",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)
        b:deal(w, w, { { w.hp + 3, "slashing" } })
        t:eq("at 0 HP and Unconscious", b:has(w, "unconscious"), true)
        t:eq("not dead (3 left over < max HP)", w.dead, false)
        b.dice:force(12, 1)
        b:death_save(w)
        t:eq("12: one success", w.ds.s, 1)
        b:death_save(w)
        t:eq("natural 1: two failures", w.ds.f, 2)
        b:deal(w, w, { { 2, "slashing" } }, { crit = true })
        t:eq("a Critical Hit at 0 HP: dead", w.dead, true)
        local b2 = fresh()
        local r = at(b2, pc("rogue", 2), 5, 5)
        b2:deal(r, r, { { r.hp, "slashing" } })
        b2.dice:force(20)
        b2:death_save(r)
        t:eq("natural 20: back up with 1 HP", r.hp, 1)
        t:eq("conscious again", r.down, false)
    end)

case("massive-damage", "Massive damage kills outright", "p. 17",
    "If damage reduces you to 0 and the remainder equals or exceeds your Hit Point maximum, you die.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)               -- 14 HP
        b:deal(w, w, { { w.hp + w.hp_max, "bludgeoning" } })
        t:eq("dead", w.dead, true)
    end)

case("concentration", "Concentration save after damage", "p. 179",
    "Constitution save, DC 10 or half the damage taken (round down), whichever is higher, up to 30.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)
        local f = at(b, pc("fighter", 2), 6, 5)
        S.bless.cast(b, c, 1, { f })
        t:eq("Bless is running", c.conc ~= nil, true)
        b.dice:force(8)                                       -- 8 + Con 1 = 9 vs DC 10 -> lost
        b:deal(f, c, { { 4, "slashing" } })
        t:eq("failed DC 10: Concentration ends", c.conc == nil, true)
        t:eq("Bless is gone from Brannoc", b:find_effect(f, "Bless") == nil, true)
        local b2 = fresh()
        local w = at(b2, pc("wizard", 3), 5, 5)
        S.blur.cast(b2, w, 2)
        b2:give_temp(w, 60)                                   -- soak the damage so she stays up
        b2.dice:force(12)                                     -- 28 damage: DC 14; 12 + Con 2 = 14 holds
        b2:deal(w, w, { { 28, "slashing" } })
        t:eq("28 damage, DC 14: 14 keeps Blur", w.conc ~= nil, true)
        b2.dice:force(12)                                     -- 30 damage: DC 15; 14 loses it
        b2:deal(w, w, { { 30, "slashing" } })
        t:eq("30 damage, DC 15: 14 drops Blur", w.conc == nil, true)
    end)

case("undead-fortitude", "Zombie: Undead Fortitude", "p. 343",
    "If damage drops it to 0, Constitution save DC 5 + the damage; on a success it drops to 1 HP instead. "
        .. "Not against Radiant damage or a Critical Hit.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local z = at(b, mon("zombie"), 6, 5)
        z.hp = 8
        b.dice:force(10)                                      -- 10 + 3 = 13 vs DC 5 + 8
        b:deal(f, z, { { 8, "slashing" } })
        t:eq("survives at 1 HP", z.hp, 1)
        b:deal(f, z, { { 6, "radiant" } })
        t:eq("Radiant damage finishes it", z.dead, true)
    end)

case("second-wind", "Fighter: Second Wind", "p. 48",
    "Bonus Action: regain 1d10 + Fighter level Hit Points. Two uses at levels 1-3, three at level 4.",
    function(t)
        local f2, f4 = pc("fighter", 2), pc("fighter", 4)
        t:eq("level 2: two uses", f2.res.second_wind, 2)
        t:eq("level 4: three uses", f4.res.second_wind, 3)
        local b = fresh()
        at(b, f2, 5, 5)
        f2.hp = 5
        local g = at(b, mon("goblin_warrior"), 15, 5)
        b.dice:force(7)
        b.active = f2
        ai.take_turn(b, f2)
        t:eq("heals 7 + 2", f2.hp, 14)
        t:eq("one use spent", f2.res.second_wind, 1)
    end)

case("hp-fixed", "Hit Points at higher levels", "p. 23",
    "Level 1: maximum Hit Die + Con. After that, the fixed value + Con each level.",
    function(t)
        t:eq("Fighter 3, Con 14: 12 + 2 x 8", pc("fighter", 3).hp_max, 28)
        t:eq("Wizard 4, Con 14: 8 + 3 x 6", pc("wizard", 4).hp_max, 26)
        t:eq("Rogue 2, Con 14: 10 + 7", pc("rogue", 2).hp_max, 17)
        t:eq("Dwarf Cleric 3, Con 13: 9 + 2 x 6 + Dwarven Toughness 3", pc("cleric", 3).hp_max, 24)
    end)

case("armor", "Armor Class: heavy armor, shields, Mage Armor", "p. 92, p. 145",
    "Chain Mail is AC 16 and ignores Dexterity; a Shield adds 2; Mage Armor sets base AC to 13 + Dex.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)               -- Dex 8, Chain Mail + Shield
        t:eq("Oswin: 16 + 2, no Dex penalty", b:ac(c), 18)
        local w = at(b, pc("wizard", 2), 6, 5)
        t:eq("Thessaly unarmored: 10 + 1", b:ac(w), 11)
        w.mage_armor = true
        t:eq("with Mage Armor: 13 + 1", b:ac(w), 14)
        local r = at(b, pc("rogue", 2), 7, 5)
        t:eq("Pip in Leather: 11 + 3", b:ac(r), 14)
    end)

case("masteries", "Weapon Mastery: Sap, Vex, Graze, Topple", "p. 90",
    "Sap: Disadvantage on the target's next attack. Vex: Advantage on your next attack. Graze: a miss deals "
        .. "the ability modifier. Topple: Con save (DC 8 + mod + PB) or Prone.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)
        c.masteries.mace = true                             -- pretend Oswin trained the Mace
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(15, 3)
        b:attack(c, o, melee(c))
        t:eq("Sap: the ogre's next attack has Disadvantage", (b:attack_mode(o, c, creature.monster_attack(o, o.attacks[1]))), -1)
        local b2 = fresh()
        local r = at(b2, pc("rogue", 2), 5, 5)
        local o2 = at(b2, mon("ogre"), 6, 5)
        b2.dice:force(18, 3)
        b2:attack(r, o2, melee(r), { no_sneak = true })
        t:eq("Vex: Pip's next attack on the ogre has Advantage", (b2:attack_mode(r, o2, melee(r))), 1)
        local b3 = fresh()
        local f = at(b3, pc("fighter", 2), 5, 5)
        local o3 = at(b3, mon("ogre"), 6, 5)
        local before = o3.hp
        b3.dice:force(2)
        b3:attack(f, o3, melee(f))
        t:eq("Graze: a greatsword miss still deals Str 3", before - o3.hp, 3)
        local b4 = fresh()
        local w = at(b4, pc("wizard", 2), 5, 5)
        w.masteries.quarterstaff = true
        local g = at(b4, mon("goblin_warrior"), 6, 5)
        g.hp = 50
        b4.dice:force(19, 2, 3)                              -- hit, d6 = 2, goblin Con save 3 + 0 vs DC 8 - 1 + 2 = 9
        b4:attack(w, g, melee(w))
        t:eq("Topple: the goblin is Prone", b4:has(g, "prone"), true)
    end)

case("nick", "Nick: the Light weapon's extra attack inside the Attack action", "p. 89, p. 90",
    "The extra Light attack doesn't add a positive ability modifier to damage (without Two-Weapon Fighting).",
    function(t)
        local r = pc("rogue", 2)
        local off = creature.weapon_attack(r, "dagger", { offhand = true })
        t:eq("dagger extra attack: 1d4 + 0", off.damage[1][3], 0)
        t:eq("dagger has Nick mastery for Pip", off.mastery, "nick")
    end)

case("bless", "Bless adds 1d4 to attack rolls and saves", "p. 113",
    "Up to three creatures add 1d4 to attack rolls and saving throws while you concentrate.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)
        local f = at(b, pc("fighter", 2), 6, 5)
        local g = at(b, mon("goblin_warrior"), 7, 5)
        S.bless.cast(b, c, 1, { f })
        b.dice:force(8, 2, 4, 4)                             -- 8 + 5 + 2 = 15 vs AC 15
        local r = b:attack(f, g, melee(f))
        t:eq("8 + 5 + Bless 2 = 15 hits AC 15", r.hit, true)
    end)

case("shield-spell", "Shield: +5 AC, including against the triggering attack", "p. 161",
    "Reaction when hit: +5 AC until the start of your next turn.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)                -- AC 11, Shield free from Magic Initiate
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(8)                                       -- 8 + 6 = 14 vs AC 11 hits, +5 -> 16 misses
        local r = b:attack(o, w, creature.monster_attack(o, o.attacks[1]))
        t:eq("the hit turns into a miss", r.hit, false)
        t:eq("Shield used her Reaction", w.reaction_used, true)
        t:eq("the free Magic Initiate cast is spent", w.res.mi_free, 0)
    end)

case("magic-missile", "Magic Missile always hits", "p. 146",
    "Three darts, 1d4 + 1 Force each, one more per slot level above 1.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 3), 5, 5)
        local o = at(b, mon("ogre"), 10, 5)
        b.dice:force(1, 2, 3, 4)
        S.magic_missile.cast(b, w, 2, o)
        t:eq("four darts at level 2: 2+3+4+5", o.hp_max - o.hp, 14)
    end)

case("sleep", "Sleep: Incapacitated, then Unconscious", "p. 163",
    "Wisdom save or Incapacitated until the end of its next turn, then save again or Unconscious. Creatures "
        .. "immune to Exhaustion succeed automatically. Damage wakes them.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 2, 5)
        local g = at(b, mon("goblin_warrior"), 8, 5)
        local sk = at(b, mon("skeleton"), 9, 5)
        b.dice:force(4)                                       -- goblin Wis save 4 - 1 = 3 fails
        S.sleep.cast(b, w, 1, { x = 8, y = 5 })
        t:eq("goblin Incapacitated", b:has(g, "incapacitated"), true)
        t:eq("skeleton immune (Exhaustion immunity)", b:has(sk, "incapacitated"), false)
        b.active = g
        b:start_turn(g)
        b.dice:force(2)
        b:end_turn(g)
        t:eq("second failed save: Unconscious", b:has(g, "unconscious"), true)
        b:deal(w, g, { { 1, "fire" } })
        t:eq("damage wakes it", b:has(g, "unconscious"), false)
    end)

case("hold-person", "Hold Person: Humanoids only, save again each turn", "p. 141",
    "Wisdom save or Paralyzed; repeat the save at the end of each of its turns.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 4), 2, 5)
        local bc = at(b, mon("bandit_captain"), 8, 5)
        local wolf = at(b, mon("wolf"), 9, 5)
        b.dice:force(3)
        S.hold_person.cast(b, c, 2, bc)
        t:eq("captain Paralyzed", b:has(bc, "paralyzed"), true)
        b.active = bc
        b:start_turn(bc)
        b.dice:force(20)
        b:end_turn(bc)
        t:eq("shakes it off at end of turn", b:has(bc, "paralyzed"), false)
        local b2 = fresh()
        local c2 = at(b2, pc("cleric", 4), 2, 5)
        local w2 = at(b2, mon("wolf"), 8, 5)
        S.hold_person.cast(b2, c2, 2, w2)
        t:eq("a wolf isn't a Humanoid", b2:has(w2, "paralyzed"), false)
    end)

case("disciple-of-life", "Life Domain: Disciple of Life", "p. 40",
    "Healing from a spell slot adds 2 + the slot level.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 3, "life"), 5, 5)
        local f = at(b, pc("fighter", 3), 6, 5)
        f.hp = 1
        b.dice:force(3, 4)
        S.cure_wounds.cast(b, c, 1, f)
        t:eq("2d8 (3+4) + Wis 3 + 2 + 1", f.hp, 1 + 13)
    end)

case("preserve-life", "Life Domain: Preserve Life", "p. 40",
    "Restore 5 x Cleric level among Bloodied creatures within 30 feet, none above half its maximum.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 3, "life"), 5, 5)
        local f = at(b, pc("fighter", 3), 6, 5)
        local w = at(b, pc("wizard", 3), 7, 5)
        f.hp, w.hp = 2, 3
        ai.preserve_life(b, c)
        t:eq("Brannoc topped to half (14)", f.hp, 14)
        t:eq("Thessaly gets the rest (3 + 3 = 6)", w.hp, 6)
    end)

case("potent-cantrip", "Evoker: Potent Cantrip", "p. 82",
    "A damaging cantrip still deals half damage on a miss or a successful save.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 3, "evoker"), 2, 5)
        local o = at(b, mon("ogre"), 10, 5)
        b.dice:force(2, 8)                                    -- Fire Bolt misses (2 + 5), d10 = 8 -> 4
        S.fire_bolt.cast(b, w, 0, o)
        t:eq("half of 8 on a miss", o.hp_max - o.hp, 4)
    end)

case("pack-tactics", "Wolf: Pack Tactics", "p. 364",
    "Advantage if an ally is within 5 feet of the target and isn't Incapacitated.",
    function(t)
        local b = fresh()
        local w1 = at(b, mon("wolf"), 6, 5)
        local w2 = at(b, mon("wolf"), 6, 6)
        local f = at(b, pc("fighter", 2), 5, 5)
        t:eq("wolf with a packmate: Advantage", (b:attack_mode(w1, f, creature.monster_attack(w1, w1.attacks[1]))), 1)
        b:add_effect(w2, { name = "Asleep", conds = { unconscious = true } })
        t:eq("packmate asleep: no Advantage", (b:attack_mode(w1, f, creature.monster_attack(w1, w1.attacks[1]))), 0)
    end)

case("parry", "Bandit Captain: Parry", "p. 261",
    "Reaction when hit by a melee attack while holding a weapon: +2 AC against it.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local bc = at(b, mon("bandit_captain"), 6, 5)
        b.dice:force(11)                                      -- 11 + 5 = 16 vs AC 15; +2 = 17 misses
        local r = b:attack(f, bc, melee(f))
        t:eq("parried", r.hit, false)
        t:eq("Reaction spent", bc.reaction_used, true)
    end)

case("opportunity", "Opportunity Attacks and Disengage", "p. 15, p. 181, p. 185",
    "Leaving an enemy's reach provokes an Opportunity Attack; Disengage prevents it.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(1)                                       -- the OA misses
        b:move_to(w, 3, 5)
        t:eq("the ogre used its Reaction", o.reaction_used, true)
        local b2 = fresh()
        local r = at(b2, pc("rogue", 2), 5, 5)
        local o2 = at(b2, mon("ogre"), 6, 5)
        r.turn.disengaged = true
        b2:move_to(r, 3, 5)
        t:eq("Disengaged: no Opportunity Attack", o2.reaction_used, false)
    end)

case("turn-undead", "Turn Undead", "p. 37",
    "Each Undead within 30 feet: Wisdom save or Frightened and Incapacitated for 1 minute; ends if it takes damage.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 2), 5, 5)
        local z = at(b, mon("zombie"), 9, 5)
        b.dice:force(5)
        ai.turn_undead(b, c)
        t:eq("zombie is Incapacitated", b:has(z, "incapacitated"), true)
        b:deal(c, z, { { 1, "radiant" } })
        t:eq("damage ends the turning", b:has(z, "incapacitated"), false)
    end)

case("halfling-luck", "Halfling: Luck", "p. 85",
    "When you roll a 1 on the d20 of a D20 Test, reroll it and use the new roll.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 2, nil, { keep_luck = true }), 5, 5)
        local g = at(b, mon("goblin_warrior"), 6, 5)
        b.dice:force(1, 17, 2)
        local res = b:attack(r, g, melee(r), { no_sneak = true })
        t:eq("the 1 becomes a 17", res.roll, 17)
    end)

case("mirror-image", "Mirror Image", "p. 150",
    "When hit, roll a d6 per duplicate; on any 3+, a duplicate is hit and destroyed instead.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 3), 5, 5)
        w.res.mi_free = 0
        w.res.slots = { 0, 0 }                                -- no Shield to muddy the test
        local o = at(b, mon("ogre"), 6, 5)
        S.mirror_image.cast(b, w)
        b.dice:force(18, 1, 2, 4)
        local r = b:attack(o, w, creature.monster_attack(o, o.attacks[1]))
        t:eq("a duplicate takes it", r.mirror, true)
        t:eq("two duplicates left", b:find_effect(w, "Mirror Image").mirror_images, 2)
        t:eq("Thessaly unhurt", w.hp, w.hp_max)
    end)

case("xp-budget", "Encounter XP budget", "p. 202",
    "Multiply the XP Budget per Character by the party size: Low for four level 1 characters is 200 XP; "
        .. "Moderate for five level 3 characters is 1,125 XP.",
    function(t)
        local low = enc.budget(1, 4)
        local _, mod = enc.budget(3, 5)
        t:eq("4 x level 1, Low", low, 200)
        t:eq("5 x level 3, Moderate", mod, 1125)
        t:eq("one CR 2 Ogre for four level 2s rates Moderate", enc.rate(2, 4, { "ogre" }).label, "Moderate")
    end)

-- Original subclasses ---------------------------------------------------------------------------

case("hold-fast", "Banner Captain: Hold Fast (original)", "Subclass design",
    "Allies within 5 feet of the captain get +1 AC.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 3, "banner_captain"), 5, 5)
        local w = at(b, pc("wizard", 3), 6, 5)
        t:eq("Thessaly next to Brannoc: 11 + 1", b:ac(w), 12)
        w.x = 9
        t:eq("away from Brannoc: 11", b:ac(w), 11)
    end)

case("battle-orders", "Banner Captain: Battle Orders (original)", "Subclass design",
    "Bonus Action, one use of Second Wind: an ally attacks with its Reaction (Sneak Attack works again).",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 3, "banner_captain"), 5, 5)
        local r = at(b, pc("rogue", 3), 6, 4)
        local o = at(b, mon("ogre"), 6, 5)
        r.turn.sneak_used = true                              -- Pip already used Sneak Attack on his turn
        b.dice:force(15, 1, 1, 15, 3, 4, 5)                  -- Brannoc hits (15, 2d6 = 1,1); Pip hits (15, d6 = 3, Sneak 2d6 = 4,5)
        b.active = f
        f.turn = { action = true, bonus = true, move = 0, attacks = 0 }
        f.res.action_surge = 0
        ai.take_turn(b, f)
        t:eq("one Second Wind use spent on the order", f.res.second_wind, 1)
        t:eq("Pip used his Reaction", r.reaction_used, true)
        t:eq("ogre took 1+1+3 from Brannoc and 3+3+4+5 from Pip", o.hp_max - o.hp, 20)
    end)

case("feint", "Silvertongue: Feint (original)", "Subclass design",
    "Bonus Action: Charisma (Deception) vs Wisdom (Insight); win and your next attack this turn has Advantage.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 3, "silvertongue"), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(10, 10)                                  -- 10 + Cha 2 + 4 = 16 vs 10 - 2 = 8
        ai.feint(b, r, o)
        t:eq("Advantage against the ogre", (b:attack_mode(r, o, melee(r))), 1)
    end)

case("opening-strike", "Ambusher: Opening Strike (original)", "Subclass design",
    "Round 1: Advantage against creatures that haven't acted, and one extra Sneak Attack die once.",
    function(t)
        local b = fresh()
        local r = at(b, pc("rogue", 3, "ambusher"), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        b.round = 1
        b.dice:force(12, 3, 3, 1, 2, 3)                       -- Advantage d20s; d6 = 1; 3d6 Sneak = 2+3+...
        t:eq("Advantage on a creature that hasn't acted", (b:attack_mode(r, o, melee(r))), 1)
        b.dice.queue = {}
        b.dice:force(12, 3, 1, 2, 3, 4)
        local res = b:attack(r, o, melee(r))
        t:eq("1d6 (1) + Dex 3 + three Sneak dice (2+3+4)", res.damage, 13)
    end)

case("warm-welcome", "Hearth Domain: Warm Welcome (original)", "Subclass design",
    "Channel Divinity, Bonus Action: up to Wis-mod creatures within 30 ft gain Temp HP = Wis mod + level.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 3, "hearth"), 5, 5)
        local f = at(b, pc("fighter", 3), 6, 5)
        ai.warm_welcome(b, c)
        t:eq("Brannoc gets Wis 3 + level 3", f.temp, 6)
        t:eq("it's a Bonus Action", c.turn and c.turn.bonus, false)
        t:eq("one Channel Divinity spent", c.res.channel, 1)
    end)

case("tricky-decoy", "Mischief Domain: Tricky Decoy (original)", "Subclass design",
    "Bonus Action double; attackers near it save (Wis) or swing at it instead (AC = spell DC).",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 3, "mischief"), 5, 5)
        local f = at(b, pc("fighter", 3), 6, 5)
        local g = at(b, mon("goblin_warrior"), 7, 5)
        ai.tricky_decoy(b, c)
        t:eq("the decoy stands by Brannoc", c.decoy and c.decoy.x, 6)
        t:eq("no Concentration used", c.conc, nil)
        b.dice:force(5, 12)                       -- Wis save 4 fails vs DC 13; 12 + 4 hits the decoy's AC 13
        local r = b:attack(g, f, creature.monster_attack(g, g.attacks[1]))
        t:eq("the goblin swings at the decoy", r.decoyed, true)
        t:eq("Brannoc untouched", f.hp, f.hp_max)
        t:eq("a hit pops it", c.decoy, nil)
        ai.tricky_decoy(b, c)
        b.dice:force(15, 15, 3)                   -- 15 - 1 = 14 saves: the goblin sees through it
        local r2 = b:attack(g, f, creature.monster_attack(g, g.attacks[1]))
        t:eq("a successful save attacks Brannoc", r2.decoyed or false, false)
        t:eq("the decoy survives", c.decoy ~= nil, true)
        b.dice:force(2, 6)                        -- fails the save; 6 + 4 = 10 misses the decoy
        local r3 = b:attack(g, f, creature.monster_attack(g, g.attacks[1]))
        t:eq("a miss leaves the decoy standing", r3.decoyed and c.decoy ~= nil, true)
    end)

case("quick-reflection", "Mirror Mage: Quick Reflection (original)", "Subclass design",
    "Mirror Image as a Bonus Action; once per Long Rest without a slot (so it doesn't use the turn's slot).",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 3, "mirror_mage"), 5, 5)
        b.active = w
        b:start_turn(w)
        ai.cast(b, w, "mirror_image")
        t:eq("the free use is spent", w.res.qr_free, 0)
        t:eq("both level 2 slots left", w.res.slots[2], 2)
        t:eq("a slot spell is still allowed this turn", ai.can_cast(w, "magic_missile"), true)
    end)

case("shimmer", "Mirror Mage: Shimmer (original)", "Subclass design",
    "Reaction: impose Disadvantage on an attack roll against you (Int-mod uses per Long Rest).",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 3, "mirror_mage"), 5, 5)
        w.res.mi_free = 0
        w.res.slots = { 0, 0 }
        local o = at(b, mon("ogre"), 6, 5)
        b.dice:force(18, 2)
        local r = b:attack(o, w, creature.monster_attack(o, o.attacks[1]))
        t:eq("Disadvantage keeps the 2", r.roll, 2)
        t:eq("one use spent (3 -> 2)", w.res.shimmer, 2)
    end)

case("warding-flash", "Spellguard: Warding Flash (original)", "Subclass design",
    "Reaction when hit: +5 AC against that one attack. Once per Short or Long Rest.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 3, "spellguard"), 5, 5)
        local o = at(b, mon("ogre"), 6, 5)
        t:eq("Spellguard AC", b:ac(f), 16)
        b.dice:force(11)                                      -- 11 + 6 = 17 vs AC 16: hit, 17 < 21 -> miss
        local r = b:attack(o, f, creature.monster_attack(o, o.attacks[1]))
        t:eq("Warding Flash turns the hit", r.hit, false)
        t:eq("the use is spent", f.res.warding_flash, 0)
        t:eq("AC is back to normal", b:ac(f), 16)
        b.dice:force(11, 3, 3)
        f.reaction_used = false
        local r2 = b:attack(o, f, creature.monster_attack(o, o.attacks[1]))
        t:eq("no second flash before a rest", r2.hit, true)
        local f2 = at(b, pc("fighter", 3, "spellguard"), 9, 9)
        b.dice:force(16, 3, 3)                                -- 16 + 6 = 22: even +5 doesn't save it
        local r3 = b:attack(o, f2, creature.monster_attack(o, o.attacks[1]))
        t:eq("a big hit isn't worth the reaction", r3.hit, true)
        t:eq("so the use is kept", f2.res.warding_flash, 1)
    end)

case("one-slot", "One spell slot per turn", "p. 105",
    "On a turn, you can expend only one spell slot to cast a spell.",
    function(t)
        local b = fresh()
        local c = at(b, pc("cleric", 3), 5, 5)
        local f = at(b, pc("fighter", 3), 6, 5)
        b.active = c
        b:start_turn(c)
        t:eq("Shield of Faith is castable", ai.can_cast(c, "shield_of_faith"), true)
        ai.cast(b, c, "shield_of_faith", f)
        t:eq("no second slot spell this turn", ai.can_cast(c, "guiding_bolt"), false)
        t:eq("the free Magic Initiate Healing Word still works", ai.can_cast(c, "healing_word"), true)
        t:eq("cantrips still fine", ai.can_cast(c, "sacred_flame"), true)
    end)

-- The Vale Bestiary (A13) and hazards (A10) -------------------------------------------------------

case("grapple-escape", "Giant Crab: a claw that grabs, and breaking free", "pp. 350, 182 (Grappled)",
    "Claw hit: a Medium or smaller target is Grappled (escape DC 11). Grappled: Speed 0, Disadvantage on attacks against "
        .. "anyone but the grappler. Escape: an action, Athletics or Acrobatics against the escape DC.",
    function(t)
        local b = fresh()
        local w = at(b, pc("wizard", 2), 5, 5)
        local crab = at(b, mon("giant_crab"), 6, 5)
        local other = at(b, mon("bandit"), 4, 5)
        b.dice:force(15, 4)                                -- 15 + 3 = 18 hits; damage 1d6 4 + 1
        local r = b:attack(crab, w, creature.monster_attack(crab, crab.attacks[1]))
        t:eq("the claw hits", r.hit, true)
        t:eq("the wizard is Grappled", b:has(w, "grappled"), true)
        t:eq("Speed 0", b:speed(w), 0)
        local mode = b:attack_mode(w, other, { kind = "ranged", is_weapon = false })
        t:eq("Disadvantage against someone else", mode, -1)
        w.turn = { action = true }
        b.dice:force(15, 4)                                -- Str check 15 - 1; Dex check 4 + 2: best 14 vs DC 11
        t:eq("breaks free", b:escape_grapple(w), true)
        t:eq("no longer Grappled", b:has(w, "grappled"), false)
    end)

case("spider-web", "Giant Spider: Web holds you until it's cut", "p. 353",
    "Web (Recharge 5-6): Dex save DC 13 or Restrained until the web is destroyed (AC 10, HP 5, Vulnerability to Fire).",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local sp = at(b, mon("giant_spider"), 10, 5)
        b:add_effect(f, { name = "Spider web", conds = { restrained = true }, web = { ac = 10, hp = 5 } })
        t:eq("Restrained", b:has(f, "restrained"), true)
        b.dice:force(12, 3, 3)                             -- 12 + 5 hits AC 10; greatsword 3 + 3 + 3 = 9 >= 5
        t:eq("cut free", b:cut_web(f, melee(f)), true)
        t:eq("not Restrained", b:has(f, "restrained"), false)
    end)

case("specter-drain", "Specter: Life Drain lowers the Hit Point maximum", "p. 327, Long Rest p. 185",
    "Life Drain: the target's Hit Point maximum drops by the damage taken; a Long Rest returns it to normal.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local sp = at(b, mon("specter"), 6, 5)
        local full = f.hp_max
        f.hp_full = full
        b.dice:force(15, 3, 4)                             -- 15 + 4 hits; 2d6 = 7 necrotic
        b:attack(sp, f, creature.monster_attack(sp, sp.attacks[1]))
        t:eq("HP max down by 7", f.hp_max, full - 7)
        require("game.rules.rest").long(f)
        t:eq("a Long Rest brings it back", f.hp_max, full)
    end)

case("burning", "Burning: 1d4 Fire at the start of each turn, until put out", "p. 178",
    "A burning creature takes 1d4 Fire damage at the start of each of its turns; Prone and rolling puts it out.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local g = at(b, mon("goblin_warrior"), 9, 5)
        require("game.rules.hazards").setup(b, "strong_wind")   -- any hazard switches the hooks on
        b:add_effect(f, { name = "Burning", conds = {}, burning = { 1, 4, 0, "fire" } })
        local hp = f.hp
        b.dice:force(3)
        b:start_turn(f)
        t:eq("burns for 3", f.hp, hp - 3)
        t:eq("strong wind: ranged weapon attacks have Disadvantage",
            (b:attack_mode(g, f, { kind = "ranged", is_weapon = true })), -1)
    end)

case("falling", "Falling: 1d6 per 10 feet, and Prone", "p. 182",
    "A creature that falls takes 1d6 Bludgeoning damage for every 10 feet it fell, and lands Prone.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local hz = require "game.rules.hazards"
        local st = hz.setup(b, "crumbling_bridge")
        b.round = 1
        b.dice:force(2, 4, 1)                          -- Dex save 2 + 1 fails DC 10; 20 feet: 2d6 = 4 + 1
        local hp = f.hp
        -- Put the hole right under Brannoc and let the round run.
        local rng = b.dice.rng
        local real = rng.int
        rng.int = function(_, lo, hi) if lo == -1 and hi == 1 then return 0 end return real(rng, lo, hi) end
        hz.round(b)
        rng.int = real
        t:eq("2d6 from the fall", f.hp, hp - 5)
        t:eq("lands Prone", b:has(f, "prone"), true)
    end)

case("bridge-planks", "A crumbling bridge gives way under its planks, not on solid ground", "p. 182",
    "On a board with a bridge, holes open only on the planks; someone standing on the bank is never under one.",
    function(t)
        local b = fresh()
        local onb = at(b, pc("fighter", 2), 10, 7)       -- on the planks
        local bank = at(b, pc("rogue", 2), 4, 7)         -- on the bank
        b.planks = { ["9,6"] = true, ["10,6"] = true, ["11,6"] = true, ["9,7"] = true, ["10,7"] = true, ["11,7"] = true,
                     ["9,8"] = true, ["10,8"] = true, ["11,8"] = true }
        local hz = require "game.rules.hazards"
        local st = hz.setup(b, "crumbling_bridge")
        for r = 1, 6 do
            b.round = r
            hz.round(b)
        end
        local off = 0
        for k in pairs(st.holes or {}) do
            if not b.planks[k] then off = off + 1 end
        end
        t:eq("no hole off the planks", off, 0)
        t:eq("the bank stays solid under the rogue", b:has(bank, "prone"), false)
        t:eq("the planks do give way", next(st.holes or {}) ~= nil, true)
    end)

case("board-hazards", "The board says where a hazard starts: fire by the hearth, water out of the stream",
    "p. 178, p. 16, p. 195",
    "Spreading fire starts beside the board's fire; rising water comes up out of the board's water a ring a round; "
        .. "ice forms where the frost is.",
    function(t)
        local hz = require "game.rules.hazards"
        local b = fresh()
        at(b, pc("fighter", 2), 4, 6)
        at(b, mon("goblin_warrior"), 14, 6)
        b.blocked = { [17 * 1000 + 2] = true }
        b.sources = { fire = { { squares = { { 17, 2 } }, name = "hearth" } } }
        local st = hz.setup(b, "spreading_fire")
        local far = 0
        for k in pairs(st.fire) do
            local x, y = string.match(k, "^(%d+),(%d+)$")
            if math.max(math.abs(tonumber(x) - 17), math.abs(tonumber(y) - 2)) > 2 then far = far + 1 end
        end
        t:eq("the fire starts by the hearth", far, 0)
        t:eq("and says so", st.from, "hearth")
        local b2 = fresh()
        at(b2, pc("fighter", 2), 2, 6)
        at(b2, mon("goblin_warrior"), 18, 6)
        local stream = {}
        for y = 1, b2.H do table.insert(stream, { 10, y }) end
        b2.sources = { water = { { squares = stream, name = "stream" } } }
        local st2 = hz.setup(b2, "rising_water")
        b2.round = 1
        hz.round(b2)
        t:eq("round one: the stream and its banks", st2.water["10,3"] and st2.water["11,3"] and st2.water["9,3"] or false, true)
        t:eq("the far bank is dry", st2.water["2,6"] or false, false)
        t:eq("the DM's edge isn't flooded first", st2.water["2," .. b2.H] or false, false)
        local b3 = fresh()
        at(b3, pc("fighter", 2), 2, 2)
        b3.sources = { ice = { { squares = { { 15, 9 } }, name = "frost" } } }
        local st3 = hz.setup(b3, "slippery_ice")
        local near = 0
        for k in pairs(st3.ice) do
            local x, y = string.match(k, "^(%d+),(%d+)$")
            if math.abs(tonumber(x) - 15) <= 1 and math.abs(tonumber(y) - 9) <= 1 then near = near + 1 end
        end
        t:eq("the ice is where the frost was", near > 0, true)
    end)

-- Runner ---------------------------------------------------------------------------------------

local function run_case(cs)
    local t = { checks = {}, ok = true }
    function t:eq(label, actual, expected)
        local ok = actual == expected
        table.insert(self.checks, { label = label, expected = tostring(expected), actual = tostring(actual), ok = ok })
        if not ok then self.ok = false end
    end
    local ok, err = xpcall(function() cs.fn(t) end, debug.traceback)
    if not ok then
        t.ok = false
        table.insert(t.checks, { label = "error", expected = "no error", actual = tostring(err), ok = false })
    end
    return t
end

case("heroic-inspiration", "Heroic Inspiration rerolls a die, and the new roll stands", "Rules Glossary: Heroic Inspiration",
    "Expend Heroic Inspiration to reroll any die immediately after rolling it; you must use the new roll.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local boss = at(b, mon("bandit_captain"), 6, 5)       -- AC 15
        boss.boss = true
        f.heroic = true
        b.dice:force(3, 9)                                   -- 3 + 5 misses; the reroll 9 + 5 = 14 still misses
        local r = b:attack(f, boss, melee(f))
        t:eq("the token is spent on the missed swing at the boss", f.heroic, nil)
        t:eq("the new roll stands, even when it's no better", r.roll, 9)
        t:eq("14 against AC 15 misses", r.hit, false)
        f.heroic = true
        b.dice:force(4, 16, 5, 6)                            -- 4 + 5 misses; the reroll 16 + 5 = 21 hits
        r = b:attack(f, boss, melee(f))
        t:eq("the reroll can turn a miss into a hit", r.hit, true)
        f.heroic = true
        b.dice:force(18, 2, 2)                               -- a hit doesn't spend it
        r = b:attack(f, boss, melee(f))
        t:eq("a hit keeps the token", f.heroic, true)
        b.dice:force(2, 19)                                  -- a failed DEX save, rerolled to a success
        local ok = b:save(f, "dex", 15)
        t:eq("a failed save is rerolled with the token", f.heroic, nil)
        t:eq("and the new roll stands", ok, true)
    end)

case("dm-runs-turn", "The DM can run a monster's turn: who it goes for, or a speech instead", "Game night (B8)",
    "Taking over: the DM picks the boss's target, or has it gloat; the rules resolve the turn as usual.",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 5, 5)
        local w = at(b, pc("wizard", 2), 9, 5)
        local boss = at(b, mon("bandit_captain"), 6, 5)
        boss.side = "foes"
        local targets = {}
        b.on_event = function(_, ev)
            if ev.kind == "attack" and ev.att == boss then
                table.insert(targets, ev.tgt)
            end
        end
        boss.dm_target = w
        b:take_turn(boss)
        t:eq("it goes for the one the DM picked, not the hero next to it", targets[1] == w, true)
        t:eq("the pick lasts one turn", boss.dm_target, nil)
        targets = {}
        boss.dm_skip = true
        b:take_turn(boss)
        t:eq("a gloat is a turn with no attack", #targets, 0)
        t:eq("and the hero next to it is untouched", f.hp, f.hp_max)
    end)

case("map-cover", "A map's cover square: Half Cover against attacks from range", "Rules Glossary: Cover",
    "Half Cover: +2 bonus to AC and Dexterity saving throws (here: against attacks from more than 5 feet away).",
    function(t)
        local b = fresh()
        local f = at(b, pc("fighter", 2), 10, 5)
        local g = at(b, mon("goblin_warrior"), 3, 5)
        local g2 = at(b, mon("goblin_warrior"), 11, 5)
        b.cover = { ["10,5"] = true }
        local ac = b:ac(f)
        local bow
        for _, a in ipairs(g.attacks) do
            if a.kind == "ranged" then bow = a end
        end
        local prof = require("game.rules.creature").monster_attack(g, bow, true)
        b.dice:force(ac - prof.to_hit)                   -- exactly the AC: a hit, but for the cover
        local r = b:attack(g, f, prof)
        t:eq("from range, the cover turns a hit into a miss", r.hit, false)
        t:eq("and says so", r.cover, true)
        local sword
        for _, a in ipairs(g2.attacks) do
            if a.kind == "melee" then sword = a end
        end
        local mp = require("game.rules.creature").monster_attack(g2, sword, false)
        b.dice:force(ac - mp.to_hit, 3)
        r = b:attack(g2, f, mp)
        t:eq("right next to them, the cover doesn't help", r.hit, true)
    end)

case("board-cover", "Behind the board's scenery: a low wall between them is Half Cover from range", "Rules Glossary: Cover",
    "Half Cover: +2 AC against an attack when an obstacle blocks at least half of the target (here: a cover piece of "
        .. "the board on the square next to them, toward the attacker).",
    function(t)
        local b = fresh()
        b.blocked = { [9 * 1000 + 5] = true }
        b.cover = { ["9,5"] = "low wall" }               -- a low wall just west of the fighter
        local f = at(b, pc("fighter", 2), 10, 5)
        local g = at(b, mon("goblin_warrior"), 3, 5)     -- shooting from the west, across the wall
        local g3 = at(b, mon("goblin_warrior"), 16, 5)   -- shooting from the east, nothing in the way
        local ac = b:ac(f)
        local bow
        for _, a in ipairs(g.attacks) do
            if a.kind == "ranged" then bow = a end
        end
        local prof = require("game.rules.creature").monster_attack(g, bow, true)
        b.dice:force(ac - prof.to_hit)
        local r = b:attack(g, f, prof)
        t:eq("across the wall, the hit becomes a miss", r.hit, false)
        t:eq("and says it was the cover", r.cover, true)
        t:eq("the shot hits the wall instead (the table says which piece)", r.blocked .. ":" .. tostring(r.cover_what),
            "cover:low wall")
        b.dice:force(ac - prof.to_hit - 3)
        r = b:attack(g, f, prof)
        t:eq("a shot that would have missed anyway is just a miss", r.blocked, nil)
        b.dice:force(ac - prof.to_hit)
        r = b:attack(g3, f, prof)
        t:eq("from the open side, no cover", r.hit, true)
    end)

case("map-trap", "A trap on the map springs on whoever steps on it, once", "p. 200 (Hidden Pit)",
    "Hidden Pit: a creature that steps on the lid falls in, taking 1d6 Bludgeoning damage; it's Prone at the bottom.",
    function(t)
        local b = fresh()
        local g = at(b, mon("goblin_warrior"), 8, 5)
        local g2 = at(b, mon("goblin_warrior"), 8, 7)
        local f = at(b, pc("fighter", 2), 2, 5)
        require("game.rules.hazards").place_traps(b, { ["6,5"] = true }, "hidden_pit")
        local hp = g.hp
        b.dice:force(4)
        b:move_to(g, 6, 5)
        t:eq("the goblin falls in and takes the 1d6", g.hp, hp - 4)
        t:eq("and lands Prone", b:has(g, "prone"), true)
        t:eq("the trap is spent", b:zone_at(6, 5), nil)
        g.x, g.y = 8, 5
        b:move_to(g2, 6, 5)
        t:eq("the next one walks over the open pit's lid unharmed", g2.hp, g2.hp_max)
    end)

-- Set the stage: the DM's set pieces, by SRD 5.2.1 ----------------------------------------------

local function bow_of(g)
    for _, a in ipairs(g.attacks) do
        if a.kind == "ranged" then
            return require("game.rules.creature").monster_attack(g, a, true)
        end
    end
end

case("cover-degrees", "A pillar is Three-Quarters Cover; a crate halfway along still covers", "Rules Glossary: Cover",
    "Half Cover is +2 to AC, Three-Quarters Cover +5. A target has cover when the attack comes from the far side of it; "
        .. "only the best cover counts. (Here: pieces right beside the attacker don't count; they lean over them.)",
    function(t)
        local b = fresh()
        b.blocked = { [9 * 1000 + 5] = true, [6 * 1000 + 8] = true, [4 * 1000 + 11] = true }
        b.cover = { ["9,5"] = "pillar", ["6,8"] = "crate", ["4,11"] = "crate" }
        b.deg = { ["9,5"] = "three_quarters", ["6,8"] = "half", ["4,11"] = "half" }
        local f = at(b, pc("fighter", 2), 10, 5)
        local g = at(b, mon("goblin_warrior"), 3, 5)
        t:eq("behind a pillar: +5", (b:cover_bonus(g, f)), 5)
        f.x, f.y = 10, 8
        g.x, g.y = 3, 8
        t:eq("a crate in the middle of the line: +2", (b:cover_bonus(g, f)), 2)
        f.x, f.y = 10, 11
        g.x, g.y = 3, 11
        t:eq("a crate right beside the archer: no cover", (b:cover_bonus(g, f)), 0)
    end)

case("total-cover", "A wall between them is Total Cover: no attack through it", "Rules Glossary: Cover",
    "Total Cover: a target can't be targeted directly by an attack or a spell. (Here: the attacker goes for someone it "
        .. "can see in range, or the attack doesn't happen.)",
    function(t)
        local b = fresh()
        b.opaque = { ["6,4"] = true, ["6,5"] = true, ["6,6"] = true }
        local f = at(b, pc("fighter", 2), 10, 5)
        local g = at(b, mon("goblin_warrior"), 3, 5)
        local prof = bow_of(g)
        local r = b:attack(g, f, prof)
        t:eq("behind the wall: the shot never happens", r.blocked, "no_line")
        t:eq("and the fighter is untouched", f.hp, f.hp_max)
        t:eq("the wall blocks sight too", b:can_see(g, f), false)
        local w = at(b, pc("wizard", 2), 4, 9)
        b.dice:force(19, 3, 3)
        r = b:attack(g, f, prof)
        t:eq("with someone else in sight, it shoots at them instead", r.target, w)
        t:eq("a line past the end of the wall is clear", b:los_xy(3, 5, 7, 9), true)
        t:eq("a line exactly through a corner between two wall squares is blocked", b:los_xy(5, 5, 7, 5) or b:los_xy(5, 4, 7, 6), false)
    end)

case("doors", "A shut door opens as a hero walks through; a wolf can't open it; a locked one holds",
    "p. 13 (Interacting with Things)",
    "You can interact with one object for free during your move: open a door as you stride toward a foe. A Lock is DC 15 "
        .. "to pick with Thieves' Tools (Dexterity (Sleight of Hand)).",
    function(t)
        local b = fresh()
        b.blocked = {}
        for y = 1, 9 do
            if y ~= 5 then b.blocked[6 * 1000 + y] = true end
        end
        b.opaque = {}
        for y = 1, 9 do
            if y ~= 5 then b.opaque["6," .. y] = true end
        end
        b.H = 9
        b.doors = { ["6,5"] = { state = "closed", x = 6, y = 5, fid = "dm1" } }
        local f = at(b, pc("fighter", 2), 4, 5)
        t:eq("the shut door blocks sight", b:los_xy(4, 5, 9, 5), false)
        local ok = b:move_to(f, 8, 5)
        t:eq("the fighter walks through", ok and f.x == 8, true)
        t:eq("and the door is open now", b.doors["6,5"].state, "open")
        t:eq("so it doesn't block sight any more", b:los_xy(4, 5, 9, 5), true)
        b.doors["6,5"].state = "closed"
        local w = at(b, mon("wolf"), 3, 3)
        local dist = b:paths(w, 60)
        t:eq("a wolf can't open it", dist[8 * 1000 + 5], nil)
        b.doors["6,5"].state = "locked"
        w.removed = true                                -- (the wolf wanders off: nobody on this side to fight)
        local r = at(b, pc("rogue", 2), 4, 6)
        local g = at(b, mon("goblin_warrior"), 9, 5)
        f.x, f.y = 2, 2
        dist = b:paths(r, 60)
        t:eq("a locked door holds for everyone", dist[8 * 1000 + 5], nil)
        b.dice:force(15)
        ai.work_lock(b, r)
        t:eq("the rogue picks it (15 + Dex + proficiency vs DC 15)", b.doors["6,5"].state, "closed")
        t:eq("that took the action", r.turn.action, false)
    end)

case("darkness", "In the dark, an unseen attacker has Advantage, and Darkvision sees",
    "p. 14 (Unseen Attackers and Targets); Rules Glossary: Darkvision",
    "When a creature can't see you, you have Advantage on attack rolls against it; attacking a target you can't see is "
        .. "at Disadvantage. Darkness is Heavily Obscured; Darkvision sees in it as if it were Dim Light.",
    function(t)
        local b = fresh()
        b.light = { ambient = "dark", sources = {} }
        local f = at(b, pc("fighter", 2), 10, 5)
        local g = at(b, mon("goblin_warrior"), 3, 5)
        local prof = bow_of(g)
        local mode = b:attack_mode(g, f, prof)
        t:eq("the goblin (Darkvision 60 ft) shoots the fighter it sees, who can't see it: Advantage", mode, 1)
        local fm = b:attack_mode(f, g, melee(f))
        t:eq("the fighter swings at what it can't see: Disadvantage", fm, -1)
        f.torch = true
        t:eq("with a torch, the goblin 35 ft off is in its Dim Light", b:can_see(f, g), true)
        local c = at(b, pc("cleric", 2), 12, 5)
        t:eq("the dwarf cleric sees in the dark anyway", c.darkvision ~= nil, true)
        f.torch = nil
        b.light.sources = { { x = 3, y = 4, bright = 20, dim = 20 } }
        t:eq("a brazier by the goblin lights it up for everyone", b:can_see(f, g), true)
    end)

case("ice", "Ice on the map: Difficult Terrain, and a DC 10 Dex save or Prone", "p. 195 (Slippery Ice)",
    "Slippery Ice is Difficult Terrain. When a creature moves onto it for the first time on a turn or starts its turn "
        .. "there, it must succeed on a DC 10 Dexterity saving throw or have the Prone condition.",
    function(t)
        local b = fresh()
        require("game.rules.hazards").slip_zone(b, { ["6,5"] = true })
        local g = at(b, mon("goblin_warrior"), 5, 5)
        t:eq("crossing it costs double", b:step_cost(6, 5), 10)
        b.dice:force(2)
        b:move_to(g, 6, 5)
        t:eq("a low save: down it goes", b:has(g, "prone"), true)
    end)

case("map-v2", "The DM's map is a board: its pieces block, cover and open", "Set the stage (game/model/maps.lua)",
    "Pieces from the prop kit: a table is Half Cover, a wall Total Cover, a door opens; a version 1 map's painted squares "
        .. "turn into the pieces that do the same thing.",
    function(t)
        local maps = require "game.model.maps"
        local campaign_mod = require "game.model.campaign"
        local c = campaign_mod.new(3)
        local m = maps.new(c, "x", "blank")
        t:eq("a table goes down", maps.place(m, "table_round", 10, 6, 0), true)
        t:eq("a door goes down", maps.place(m, "door", 12, 6, 0), true)
        t:eq("clicking the door again opens it", maps.place(m, "door", 12, 6, 0), true)
        t:eq("so it's an open door now", m.props[2].kind, "door_open")
        local blocked, layout, extras = maps.layout(m)
        t:eq("the table blocks", blocked[10 * 1000 + 6], true)
        t:eq("and is Half Cover", extras.deg["10,6"], "half")
        t:eq("the door is a door", #extras.doors, 1)
        t:eq("the map is a board of its own", string.sub(extras.board, 1, 4), "map:")
        local old = { template = "blank", pieces = { ["5,5"] = "wall", ["6,5"] = "cover", ["7,5"] = "rough", ["8,5"] = "trap" } }
        maps.migrate(old)
        t:eq("a version 1 map turns into pieces", #old.props .. ":" .. tostring(old.traps["8,5"]), "3:true")
    end)

local passed, results = 0, {}
for _, cs in ipairs(cases) do
    local r = run_case(cs)
    if r.ok then passed = passed + 1 end
    if not RULES_CASES_RETURN or not r.ok then
        print(string.format("%s  %-22s %s (%s)", r.ok and "PASS" or "FAIL", cs.id, cs.title, cs.page))
    end
    for _, c in ipairs(r.checks) do
        if not c.ok then
            print(string.format("        %s: expected %s, got %s", c.label, c.expected, c.actual))
        end
    end
    table.insert(results, { id = cs.id, title = cs.title, page = cs.page, rule = cs.rule, ok = r.ok, checks = r.checks })
end
print(string.format("%d of %d rules cases pass", passed, #cases))

if RULES_CASES_RETURN then
    return { passed = passed, total = #cases, results = results }
end
if arg and arg[1] == "json" and arg[2] then
    local telemetry = require "game.model.telemetry"
    local f = assert(io.open(arg[2], "w"))
    f:write(telemetry.encode and telemetry.encode(results) or "[]")
    f:close()
end
os.exit(passed == #cases and 0 or 1)
