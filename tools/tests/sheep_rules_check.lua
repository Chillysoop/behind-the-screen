-- The Wild Sheep Chase's own rules (game/rules/sheep.lua), on the rules engine with the book's stat blocks (p5):
--   NOKE   up on his platform: Enlarge on the bear once it's out (concentration), Haste on an ape when the bear's down,
--          Ray of Frost (a hit slows), one Thunderwave at whoever gets close, then Expeditious Retreat and away; he
--          runs too once nobody's left fighting for him.
--   GUARDS a hasted ape swings twice; an enlarged bear hits for 1d4 more.
--   BED    the bed dragon's Splinter Breath, and Noke's Ray of Frost from its back.
--     lua tools/tests/sheep_rules_check.lua
package.path = "./?.lua;" .. package.path

local adventure = require "game.model.adventure"
adventure.use("sheep")
local battle = require "game.rules.battle"
local creature = require "game.rules.creature"
local party = require "game.rules.party"
local ai = require "game.rules.ai"

local fails, n = {}, 0
local function check(ok, what)
    n = n + 1
    if not ok then table.insert(fails, what) end
end
local function at(b, c, x, y)
    b:add(c, x, y)
    c.turn = { action = true, bonus = true, move = c.speed, attacks = 0 }
    return c
end
local function mon(id)
    return creature.new_monster("sheep_" .. id, "")
end
local function pc(cls)
    return creature.new_pc(party.sheet(cls, 4))
end
local function turn(b, c)
    c.turn = { action = true, bonus = true, move = c.speed, attacks = 0 }
    b.active = c
    ai.take_turn(b, c)
end
local function has(b, c, name)
    return b:find_effect(c, name) ~= nil
end

-- NOKE: Enlarge on the bear.
local b = battle.new({ seed = 5, ai = ai })
local noke = at(b, mon("noke"), 17, 8)
local bear = at(b, mon("bear_guard"), 12, 5)
local ape = at(b, mon("ape_guard"), 10, 3)
local hero = at(b, pc("wizard"), 3, 13)
hero.hp, hero.hp_max = 400, 400
turn(b, noke)
check(has(b, bear, "Enlarged") and noke.conc ~= nil, "Noke puts Enlarge on the bear once it's out")
turn(b, noke)
check(has(b, bear, "Enlarged") and not has(b, ape, "Hasted"), "he keeps the one spell going, and doesn't cast another over it")
-- (The bear down: he lets it go, and hastes an ape.)
bear.hp, bear.dead = 0, true
turn(b, noke)
check(has(b, ape, "Hasted"), "with the bear down, Haste on an ape")
-- Ray of Frost, with his spell held.
local hp0 = hero.hp
for _ = 1, 6 do
    turn(b, noke)
end
check(hero.hp < hp0, "Ray of Frost at whoever's in range while he holds his spell")
-- GUARDS: a hasted ape swings twice.
local b2 = battle.new({ seed = 7, ai = ai })
local ape2 = at(b2, mon("ape_guard"), 5, 5)
local f = at(b2, pc("fighter"), 6, 5)
b2:add_effect(ape2, { name = "Hasted", ac = 2, speed_bonus = 30, hasted = true })
b2.keep_log = true
turn(b2, ape2)
local swings = 0
for _, l in ipairs(b2.log_lines or b2.lines or {}) do
    if string.find(l, "swings again", 1, true) then swings = swings + 1 end
end
local attacks = 0
for _, s in ipairs(b2.steps or {}) do
    if s.kind == "attack" then attacks = attacks + 1 end
end
check(swings >= 1 or attacks >= 2, "a hasted ape swings a second time")
-- An enlarged bear's blow: 1d4 more, each time.
local b3 = battle.new({ seed = 9, ai = ai })
local bear3 = at(b3, mon("bear_guard"), 5, 5)
local t3 = at(b3, pc("fighter"), 6, 5)
t3.hp, t3.hp_max = 500, 500
local a = bear3.data.attacks[1]
local plain, big = 0, 0
for i = 1, 40 do
    b3.dice = require("game.rules.dice").new(100 + i)
    t3.hp = 500
    local prof = creature.monster_attack(bear3, a, false)
    prof.to_hit = 50
    b3:attack(bear3, t3, prof)
    plain = plain + (500 - t3.hp)
end
b3:add_effect(bear3, { name = "Enlarged", hit_dice = { 1, 4, 0 }, str_adv = true })
for i = 1, 40 do
    b3.dice = require("game.rules.dice").new(100 + i)
    t3.hp = 500
    local prof = creature.monster_attack(bear3, a, false)
    prof.to_hit = 50
    b3:attack(bear3, t3, prof)
    big = big + (500 - t3.hp)
end
check(big > plain + 40, "an enlarged bear hits harder: 1d4 a blow (" .. plain .. " -> " .. big .. " over 40)")
-- NOKE close up: one Thunderwave, then away.
local b4 = battle.new({ seed = 11, ai = ai })
local noke4 = at(b4, mon("noke"), 10, 5)
at(b4, mon("ape_guard"), 3, 3)
local h4 = at(b4, pc("fighter"), 11, 5)
h4.hp, h4.hp_max = 400, 400
turn(b4, noke4)
check(noke4.thundered == true, "someone right up close: Thunderwave")
h4.x, h4.y = noke4.x + 1, noke4.y
turn(b4, noke4)
check(noke4.removed == true, "close again: Expeditious Retreat, and he's gone into the hall")
-- NOKE alone: he runs.
local b5 = battle.new({ seed = 13, ai = ai })
local noke5 = at(b5, mon("noke"), 17, 8)
local ape5 = at(b5, mon("ape_guard"), 10, 3)
local h5 = at(b5, pc("wizard"), 3, 13)
h5.hp, h5.hp_max = 400, 400
turn(b5, noke5)
ape5.hp, ape5.dead = 0, true
turn(b5, noke5)
check(noke5.removed == true, "nobody left fighting for him: he runs")
-- BED: Noke's ray from the dragon's back.
local b6 = battle.new({ seed = 15, ai = ai })
local bed = at(b6, mon("bed_dragon"), 10, 3)
local far = at(b6, pc("rogue"), 10, 12)
far.hp, far.hp_max = 400, 400
local hp6 = far.hp
for _ = 1, 3 do
    turn(b6, bed)
end
check(far.hp < hp6, "Noke's Ray of Frost from the bed dragon's back, at whoever's backing off")

print(string.format("SHEEP RULES  Noke, his guards, the bed: checks %d%s", n, #fails > 0 and ("  FAIL x" .. #fails) or ""))
for _, f2 in ipairs(fails) do print("         FAIL: " .. f2) end
print(#fails == 0 and "sheep rules check: all clear" or ("sheep rules check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
