-- The DM's bag, its books, people's pockets and lore tips (Conner, November 6), for any adventure:
--   BAG    thirty things, every magic one the rules', every bit one a hero can carry; what's in it from the start.
--   BOOKS  an hour of prep reads a book, in order, and its things join the bag; no hours, no reading.
--   POCKETS a thing from the bag put on someone comes out of the bag, goes back if taken off them, and reaches a pack.
--   TIPS   each adventure's tips: in their room, not twice, and a tip given counts as its secret's hint.
--   ITEMS  everything in the bag does what it says on whoever gets it; one weapon, armour and shield in use.
--   FIGHTS the friends use them: the wand from any hand, a potion when it's bad.
-- (The poke card itself, played in whole prologues: tools/tests/table_life_check.lua.)
--     lua tools/tests/dm_bag_check.lua            ADVENTURE=sheep lua tools/tests/dm_bag_check.lua
package.path = "./?.lua;" .. package.path

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local dm_bag = require "game.model.dm_bag"
local bagd = require "game.data.dm_bag"
local items = require "game.model.items"
local npcs = require "game.model.npcs"
local tips = require "game.model.lore_tips"
local secrets = require "game.model.secrets"

local fails, n = {}, 0
local function check(ok, what)
    n = n + 1
    if not ok then table.insert(fails, what) end
end

adventure.enter()
local c = campaign_mod.new(77)
adventure.enter(c)

-- BAG
check(#bagd.list == 30, "the bag has thirty things (" .. #bagd.list .. ")")
for _, e in ipairs(bagd.list) do
    if e.kind == "magic" then
        check(items.def(e.magic) ~= nil, "a magic thing the rules don't have: " .. e.id)
    else
        check(items.thing(e.thing or e.id) ~= nil, "a thing nobody can carry: " .. e.id)
    end
    check(e.name and e.rarity and e.text, "a thing without its name, rarity or words: " .. e.id)
    check(not e.book or bagd.book_by_id[e.book], "a thing in a book that isn't there: " .. e.id)
end
local start = #dm_bag.stock(c)
check(start > 0 and start < 30, "some of the bag from the start, the rest in the books (" .. start .. ")")

-- BOOKS
c:session_zero(require("game.model.social").default_choices())
for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
    adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
end
local prep = c:start_week()
local hours = prep:left()
check(not dm_bag.can_read(c, prep, "wonders"), "the second book can't be read before the first")
local added = dm_bag.read(c, prep, "armourer")
check(added and #added > 0 and #dm_bag.stock(c) == start + #added, "reading a book puts its things in the bag")
check(prep:left() == hours - bagd.READ_COST, "reading a book takes an hour of prep")
check(not dm_bag.can_read(c, prep, "armourer"), "a book is read once")
prep.extra = prep.extra + prep:left()
check(not dm_bag.can_read(c, prep, "wonders"), "no hours left, no reading")

-- POCKETS
local who = npcs.all()[1]
check(who ~= nil, "someone has a sheet to put things on")
if who then
    local choices = npcs.item_choices(c)
    check(#choices == #dm_bag.stock(c), "what can go in a pocket is what's in the bag")
    local e = bagd.by_id[choices[1]]
    local left = dm_bag.left(c, e)
    local d = npcs.add_drop(c, who.id, e.id)
    check(d and d.bag and dm_bag.left(c, e) == left - 1, "a thing put on someone comes out of the bag")
    check(npcs.drop_def(e.id) and npcs.drop_def(e.id).name, "a pocketed thing has its name for the sheet")
    npcs.remove_drop(c, who.id, #npcs.drops(c, who.id))
    check(dm_bag.left(c, e) == left, "a thing taken off them goes back in the bag")
    -- (And one reaches the party: into a pack.)
    local magic
    for _, x in ipairs(dm_bag.stock(c)) do
        if x.kind == "magic" and not magic then magic = x end
    end
    local before = #items.list(c)
    local it = dm_bag.hand_over(c, c.players[1], magic)
    check(it and #items.list(c) == before + 1 and it.holder, "a magic thing from the bag reaches a hero's pack")
    local bit = bagd.list[1]
    local it2 = dm_bag.hand_over(c, c.players[2], bit)
    check(it2 and it2.holder == c.players[2].key, "a bit from the bag reaches the hero it was for")
end

-- TIPS
local list = tips.list()
check(#list >= 10, "the adventure has its lore tips (" .. #list .. ")")
local seen = {}
for _, t in ipairs(list) do
    check(t.id and t.name and t.text, "a tip without its id, name or words")
    check(not seen[t.id], "two tips share an id: " .. tostring(t.id))
    seen[t.id] = true
    check(not t.room or adventure.data.rooms[t.room], "a tip for a room the adventure doesn't have: " .. tostring(t.id))
    check(not t.hints or secrets.def(t.hints), "a tip hinting a secret the adventure doesn't have: " .. tostring(t.id))
end
local first = adventure.data.start
local here = tips.for_room(c, first)
if #here > 0 then
    local t = here[1]
    local said = {}
    local night = { campaign = c, say = function(_, text) table.insert(said, text) end }
    tips.give(night, t, c.players[1])
    check(#said == 1 and tips.given(c, t.id), "a tip given is said and kept")
    check(not tips.useful(c, t), "a tip isn't given twice")
    check(not t.hints or secrets.hinted(c, t.hints), "a tip given counts as its secret's hint")
end

-- ITEMS (Conner, November 6: "make sure the items / weapons have mechanical benefits and work correctly when used
-- by friends"): every thing in the bag, given to whoever the party hands it to, does what its words say on that
-- hero's sheet. A weapon is their main weapon only; armour and a shield go to someone who wears or carries one.
local party = require "game.rules.party"
local creature = require "game.rules.creature"
local battle = require "game.rules.battle"
local ai = require "game.rules.ai"
local function fresh_camp()
    local cc = campaign_mod.new(91)
    adventure.enter(cc)
    items.start(cc)
    return cc
end
local function built(cc, p)
    local lvl = cc.level or 2
    local sub = lvl >= 3 and cc.subclasses and cc.subclasses[p.class] or nil
    local cr = creature.new_pc(party.sheet(p.class, lvl, sub))
    items.apply(cc, p.key, cr)
    return cr
end
local function of_class(cc, cls)
    for _, p in ipairs(cc.players) do
        if p.class == cls then return p end
    end
end
local function main_attack(cr)
    return creature.weapon_attack(cr, cr.weapons.main, { two_handed = cr.weapons.two_handed })
end
local worked = 0
for _, e in ipairs(bagd.list) do
    local cc = fresh_camp()
    local it = dm_bag.give(cc, nil, e)
    local p = it and it.holder and cc:player(it.holder)
    check(p ~= nil, "nobody in the party got " .. e.id)
    if p then
        local base = built(fresh_camp(), p)
        local cr = built(cc, p)
        local ok = true
        local function want(cond, what)
            check(cond, e.id .. " on " .. p.char .. ": " .. what)
            ok = ok and cond
        end
        if e.kind == "bit" then
            local h = e.helps
            want(h and items.check_bonus(cc, p.key, h.skill) == items.check_bonus(fresh_camp(), p.key, h.skill) + (h.n or 1),
                "+1 to its kind of check")
            want(string.find(e.text, "+1 to", 1, true) ~= nil, "its words say what it does")
        elseif e.kind == "potion" then
            want((cr.res.potions or 0) == (base.res.potions or 0) + 1, "one more potion to drink in a fight")
        else
            local d = items.def(e.magic)
            local fx = d.effect
            if fx.weapon then
                local a, b0 = main_attack(cr), main_attack(base)
                want(a.to_hit == b0.to_hit + fx.weapon, "+" .. fx.weapon .. " to hit with " .. a.name)
                want(a.damage[1][3] == b0.damage[1][3] + fx.weapon, "+" .. fx.weapon .. " damage with " .. a.name)
                want(a.magical == true, "its blows are magic")
                for _, slot in ipairs({ "thrown", "ranged", "offhand" }) do
                    local wid = cr.weapons[slot]
                    if wid and wid ~= cr.weapons.main then
                        local o = creature.weapon_attack(cr, wid, { thrown = slot == "thrown", offhand = slot == "offhand" })
                        local o0 = creature.weapon_attack(base, wid, { thrown = slot == "thrown", offhand = slot == "offhand" })
                        want(o.to_hit == o0.to_hit, "only the one weapon: not the " .. o.name)
                    end
                end
            end
            if fx.ac then
                want((cr.item_ac or 0) == (base.item_ac or 0) + fx.ac, "+" .. fx.ac .. " Armor Class")
            end
            if d.needs == "shield" then want(cr.shield == true, "carries a shield to hold it") end
            if d.needs == "armor" then want(cr.armor ~= nil, "wears armour for it") end
            if d.needs == "bow" then
                local bow = cr.weapons.ranged
                want(bow == "shortbow" or bow == "longbow", "has a bow for it")
                if bow then
                    local r, r0 = creature.weapon_attack(cr, bow), creature.weapon_attack(base, bow)
                    want(r.damage[1][3] == r0.damage[1][3] + fx.bow_damage, "+" .. fx.bow_damage .. " damage with the bow")
                end
            end
            if fx.saves then
                want(creature.save_bonus(cr, "wis") == creature.save_bonus(base, "wis") + fx.saves, "+" .. fx.saves .. " to saves")
            end
            if fx.checks then want((cr.item_checks or 0) == fx.checks, "+" .. fx.checks .. " to checks in a fight") end
            if fx.checks then
                want(items.check_bonus(cc, p.key, "athletics") == items.check_bonus(fresh_camp(), p.key, "athletics") + fx.checks,
                    "+" .. fx.checks .. " to checks on game night")
            end
            for _, sk in ipairs(fx.adv or {}) do want(items.check_edge(cc, p.key, sk) == "adv", "Advantage on " .. sk) end
            if fx.init then want(cr.item_init_adv == true, "Advantage on Initiative") end
            if fx.charges then want(cr.res.wand == fx.charges.n, "its charges in a fight") end
            if fx.slot then want(cr.pearl == fx.slot and (p.class == "wizard" or p.class == "cleric"), "a spell slot back, for a caster") end
            if fx.wound then want(cr.wound_closure == true, "death saves and Hit Point Dice") end
            if fx.climb_swim then
                want(items.check_bonus(cc, p.key, "athletics", { setting = { "high" } }) >= fx.climb_swim, "+" .. fx.climb_swim .. " climbing")
            end
            if d.attune then want(true, "") end
        end
        if ok then worked = worked + 1 end
    end
end
check(worked == #bagd.list, "every thing in the bag works on whoever has it (" .. worked .. " of " .. #bagd.list .. ")")

-- One of each in use: the best armour counts, not three at once; a shield never goes to Brannoc's greatsword.
do
    local cc = fresh_camp()
    local f = of_class(cc, "fighter")
    items.earn(cc, "armor_plus1", { f }, "found")
    items.earn(cc, "armor_plus3", { f }, "found")
    check((built(cc, f).item_ac or 0) == 3, "a hero with +1 and +3 armour gets +3, not +4")
    check(not items.can_use(cc, f, "armor_plus2"), "a +2 armour isn't given to the one in +3 armour")
    check(not items.can_use(cc, f, "shield_plus1"), "no shield for a greatsword")
    check(not items.can_use(cc, f, "bracers_of_archery"), "no bracers for a hero without a bow")
    check(not items.can_use(cc, of_class(cc, "wizard"), "armor_plus1"), "no armour for the wizard")
    check(items.can_use(cc, of_class(cc, "cleric"), "shield_plus1"), "the cleric's shield takes a +1")
    local w = items.earn(cc, "weapon_plus2", cc.players, "found")
    check(w and cc:player(w.holder).class == "fighter", "a +2 weapon goes to the fighter first")
    local w2 = items.earn(cc, "weapon_plus1", cc.players, "found")
    check(w2 and w2.holder ~= w.holder, "a +1 weapon goes to someone without a better one")
end

-- A magic weapon the wizard finds goes to someone who fights with one (the fourth playtest, 81 careless: "+1 Weapon." /
-- Mara: "I'll keep it.", and three fights of Fire Bolt with it in her pack); she keeps it only when nobody can use it
-- better. A cloak she finds is hers.
do
    local cc = fresh_camp()
    local wiz = of_class(cc, "wizard")
    local it, who = dm_bag.hand_over(cc, wiz, bagd.by_id.bag_weapon_plus1)
    local cls = who and who.class
    check(it and who and it.holder == who.key and (cls == "fighter" or cls == "rogue" or cls == "cleric"),
        "a +1 Weapon the wizard finds goes to a hero who fights with a weapon (" .. tostring(cls) .. ")")
    check(not items.good_home(cc, wiz, "weapon_plus1"), "the wizard is no home for a +1 Weapon")
    local _, cw = dm_bag.hand_over(cc, wiz, bagd.by_id.bag_cloak_of_protection)
    check(cw == wiz, "a cloak the wizard finds is hers")
    local c2 = fresh_camp()
    for _, p in ipairs(c2.players) do
        if p.class ~= "wizard" then items.earn(c2, "weapon_plus3", { p }, "found") end
    end
    local w2 = of_class(c2, "wizard")
    local _, kept = dm_bag.hand_over(c2, w2, bagd.by_id.bag_weapon_plus1)
    check(kept == w2, "with every weapon hand holding a better one, the wizard who found it keeps it")
end

-- FIGHTS: the friends use them. The wand from anyone's hand; a potion drunk when it's bad.
local function at(b, c, x, y)
    b:add(c, x, y)
    c.turn = { action = true, bonus = true, move = c.speed, attacks = 0 }
    return c
end
for _, cls in ipairs({ "fighter", "rogue", "cleric", "wizard" }) do
    local cc = fresh_camp()
    local p = of_class(cc, cls)
    items.earn(cc, "wand_of_magic_missiles", { p }, "found")
    local b = battle.new({ seed = 3, ai = ai })
    b.round = 3
    local hero = at(b, built(cc, p), 5, 5)
    local far = cls == "fighter" or cls == "cleric"
    local g = at(b, creature.new_monster("goblin_warrior", ""), far and 25 or 14, 5)
    if not far then g.hp = 6 end
    local hp0, w0 = g.hp, hero.res.wand
    ai.take_turn(b, hero)
    check((hero.res.wand or 0) < w0 and (g.hp < hp0 or g.dead), "the " .. cls .. " uses the wand ("
        .. (far and "a foe out of reach" or "a foe it's sure to finish") .. ")")
    items.settle(hero, cc)
    local it = items.holding(cc, "wand_of_magic_missiles")
    check(it and it.charges == hero.res.wand, "the " .. cls .. "'s wand keeps what's left after the fight")
end
do
    local cc = fresh_camp()
    local p = of_class(cc, "rogue")
    dm_bag.give(cc, p, bagd.by_id.bag_potion)
    local b = battle.new({ seed = 4, ai = ai })
    local hero = at(b, built(cc, p), 5, 5)
    at(b, creature.new_monster("goblin_warrior", ""), 20, 5)
    local had = hero.res.potions
    hero.hp = math.floor(hero.hp_max * 0.25)
    local hp0 = hero.hp
    ai.take_turn(b, hero)
    check(hero.res.potions == had - 1 and hero.hp > hp0, "a hurt friend drinks a potion from their pack")
    items.settle(hero, cc)
    check(items.count(cc, p.key, items.POTION) == had - 1, "a potion drunk leaves the pack")
end

print(string.format("DM BAG  %s: bag, books, pockets, tips, items, fights   checks %d%s", adventure.current(), n,
    #fails > 0 and ("  FAIL x" .. #fails) or ""))
for _, f in ipairs(fails) do print("         FAIL: " .. f) end
print(#fails == 0 and "dm bag check: all clear" or ("dm bag check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
