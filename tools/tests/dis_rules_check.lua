-- Death in Space's combat, as written (pp. 52-54, the weapons table p. 122), on forced dice: game/rules/dis/battle.lua.
-- An attack is a d20 plus Body in melee or Tech at range against the defense rating; a hit rolls the weapon's damage,
-- a natural 20 adds a die, a risky hit adds a die and a risky miss gets hit straight back; a gun reloads after its
-- shots; anyone at 0 rolls Body against 12; foes test morale on 2d6 when their leader falls; a hero's miss is a void
-- point. Nothing of 5e is loaded.
--     lua tools/tests/dis_rules_check.lua

package.path = "./?.lua;" .. package.path
local battle = require "game.rules.dis.battle"
local set = require "game.rules.sets.dis"

local fails = 0
local function ok(cond, what)
    if not cond then
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

-- Dice that come up as told, then 10s.
local function rng(faces)
    local q = { table.unpack(faces) }
    return {
        int = function(_, a, b)
            local v = table.remove(q, 1) or 10
            return math.max(a, math.min(b, v))
        end,
        chance = function()
            return false
        end,
    }
end

local function fight(faces, campaign)
    local events = {}
    local b = battle.new({ W = 10, H = 6, rng = rng(faces), set = set, campaign = campaign or {}, first = "party",
                           on_event = function(_, ev) table.insert(events, ev) end })
    return b, events
end

local function hero(o)
    local c = { side = "party", pc = true, player_key = "dev", name = "Brask", hp = 8, dr = 12, bdy = 3, dex = 0, svy = -2,
                tec = 2, weapons = { { name = "Raid rifle", damage = "1d10", ranged = true, uses = 2 }, { name = "Wrench", damage = "1d4" } } }
    for k, v in pairs(o or {}) do
        c[k] = v
    end
    return c
end
local function foe(o)
    local c = { side = "foes", name = "Thug", hp = 5, dr = 13, bdy = 2, dex = 1, tec = 0, ml = 10,
                weapons = { { name = "Shotgun", damage = "2d4", ranged = true, uses = 4 } } }
    for k, v in pairs(o or {}) do
        c[k] = v
    end
    return c
end
local function find(events, kind)
    for _, e in ipairs(events) do
        if e.kind == kind then
            return e
        end
    end
end

do
    -- Ranged: d20 + Tech. 11 + 2 = 13 against DR 13 hits; the rifle's 1d10 rolls a 4.
    local b, ev = fight({ 11, 4 })
    local h, f = b:add(hero(), 1, 1), b:add(foe(), 5, 1)
    b:attack(h, f, h.weapons[1])
    local a = find(ev, "attack")
    ok(a.total == 13 and a.hit and a.bonus == 2, "a shot is d20 + Tech, and meeting the defense rating hits (" .. tostring(a.total) .. ")")
    ok(f.hp == 1, "the rifle's 1d10 comes off their hit points (" .. f.hp .. " left)")
end

do
    -- Melee: d20 + Body. 9 + 3 = 12 misses DR 13, and the miss is a void point for the hero.
    local camp = {}
    local b, ev = fight({ 9 }, camp)
    local h, f = b:add(hero(), 1, 1), b:add(foe(), 2, 1)
    b:attack(h, f, h.weapons[2])
    local a = find(ev, "attack")
    ok(a.total == 12 and not a.hit and a.bonus == 3, "a melee attack is d20 + Body, and 12 misses a 13")
    ok(set.void_points(camp, "dev") == 1, "a hero's missed attack gives a void point (" .. set.void_points(camp, "dev") .. ")")
end

do
    -- A natural 20 adds a damage die: two d10s, 3 and 5.
    local b = fight({ 20, 3, 5 })
    local h, f = b:add(hero(), 1, 1), b:add(foe({ hp = 20 }), 5, 1)
    b:attack(h, f, h.weapons[1])
    ok(f.hp == 12, "a natural 20 rolls an extra damage die (" .. f.hp .. " of 20 left)")
end

do
    -- A risky hit adds a die; a risky miss gets hit straight back, and the one who hit back picks who's next.
    local b = fight({ 15, 2, 2 })
    local h, f = b:add(hero(), 1, 1), b:add(foe({ hp = 20 }), 2, 1)
    b:attack(h, f, h.weapons[2], true)
    ok(f.hp == 16, "a risky hit rolls an extra die (" .. f.hp .. " of 20 left)")
    local b2, ev2 = fight({ 2, 18, 3, 3 })
    local h2, f2 = b2:add(hero(), 1, 1), b2:add(foe(), 2, 1)
    b2:attack(h2, f2, h2.weapons[2], true)
    local back
    for _, e in ipairs(ev2) do
        if e.kind == "attack" and e.counter then
            back = e
        end
    end
    ok(back and back.att == f2, "a risky miss: the target hits straight back")
    ok(b2.picks_next == f2, "and the one who hit back picks who acts next")
end

do
    -- A gun fires its shots, then the turn is a reload.
    local b, ev = fight({ 15, 1, 15, 1 })
    local h, f = b:add(hero(), 1, 1), b:add(foe({ hp = 50 }), 6, 1)
    h.weapons = { { name = "Raid rifle", damage = "1d10", ranged = true, uses = 2 } }
    b:take_turn(h)
    b:take_turn(h)
    b:take_turn(h)
    ok(find(ev, "reload") ~= nil, "after its shots, a gun's next action is a reload")
end

do
    -- At 0, anyone rolls Body against 12: a hero with Body +3 on a 9 makes it (stable); a thug on a 2 doesn't.
    local b, ev = fight({ 15, 4, 4, 9 })
    local h, f = b:add(hero({ hp = 3 }), 1, 1), b:add(foe(), 2, 1)
    b:attack(f, h, f.weapons[1])
    local chk = find(ev, "death_check")
    ok(chk and chk.total == 12 and chk.ok and h.stable and not h.dead, "a hero at 0 rolls Body against 12: 9 + 3 is stable")
    local b2, ev2 = fight({ 15, 4, 2 })
    local h2, f2 = b2:add(hero(), 1, 1), b2:add(foe({ hp = 3 }), 2, 1)
    b2:attack(h2, f2, h2.weapons[2])
    local chk2 = find(ev2, "death_check")
    ok(chk2 and not chk2.ok and f2.dead and not f2.out_cold, "a foe at 0 rolls Body too: 2 + 2 misses, and they're dead")
end

do
    -- Their leader down: the others test morale on 2d6 against their morale; over it, they give up as the DM says.
    local b, ev = fight({ 15, 10, 1, 6, 6 })
    local h = b:add(hero(), 1, 1)
    local lead = b:add(foe({ boss = true, hp = 2 }), 2, 1)
    local other = b:add(foe({ ml = 9 }), 4, 1)
    local asked
    b.on_morale = function(_, c)
        asked = c
        return "surrender"
    end
    b:attack(h, lead, h.weapons[2])
    local m = find(ev, "morale")
    ok(m and m.who == other and m.roll == 12 and m.broke, "the leader falls: the rest test morale on 2d6 (" .. tostring(m and m.roll) .. " against 9)")
    ok(asked == other and other.removed and other.gave_up == "surrender", "a broken foe does what the DM says: surrenders")
end

do
    -- Partly behind cover: a shot at them is at disadvantage (two dice, the worse).
    local b, ev = fight({ 18, 4 })
    b.cover["4,1"] = "crate"
    local h, f = b:add(hero(), 1, 1), b:add(foe(), 5, 1)
    b:attack(h, f, h.weapons[1])
    local a = find(ev, "attack")
    ok(a.edge == "dis" and a.roll == 4 and not a.hit, "a shot at someone behind cover takes the worse of two dice")
end

print(fails == 0 and "dis rules: all clear" or ("dis rules: " .. fails .. " failures"))
os.exit(fails == 0 and 0 or 1)
