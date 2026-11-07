-- The shared dice (game/kit/dice.lua): every kind a rule set might roll, read right, in range, and seeded rolls the
-- same each time. (Conner, November 6: "all types of dice".)
--     lua tools/tests/dice_kit_check.lua

package.path = "./?.lua;" .. package.path
local dice = require "game.kit.dice"
local rng_mod = require "game.model.rng"
local forced = require "game.rules.dice"

local fails = 0
local function ok(cond, what)
    if not cond then
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

-- Every kind, many times: always in range, and every face of a small die turns up.
local CASES = { "1d4", "1d6", "1d8", "1d10", "1d12", "1d20", "1d100", "d%", "2d6", "3d6+2", "1d20-1", "2d20kh1", "2d20kl1",
                "4d6kh3", "3d6!", "4dF", "5d6>=5", "1d20+1d4", "1d8+2d6+3", "10d10>=8" }
local rng = rng_mod.new(7)
for _, n in ipairs(CASES) do
    local lo, hi = dice.range(n)
    local seen = {}
    for _ = 1, 20000 do
        local r = dice.roll(rng, n)
        seen[r.total] = true
        if not string.find(n, "!") then
            ok(r.total >= lo and r.total <= hi, n .. " rolled " .. r.total .. ", outside " .. lo .. ".." .. hi)
        else
            ok(r.total >= lo, n .. " rolled " .. r.total .. ", under " .. lo)
        end
    end
    -- (Ten d10s all 8 or more is one roll in 170,000: that one only has to stay in range.)
    ok(n == "10d10>=8" or (seen[lo] and seen[hi]), n .. " never rolled its lowest or highest")
end

-- Read right.
do
    local s = dice.parse("2d20kh1+5")
    ok(#s.groups == 1 and s.groups[1].n == 2 and s.groups[1].sides == 20 and s.groups[1].keep.how == "h" and s.mod == 5, "2d20kh1+5 read")
    s = dice.parse("4dF")
    ok(s.groups[1].fate and s.groups[1].n == 4, "4dF read as Fate dice")
    s = dice.parse("d%")
    ok(s.groups[1].sides == 100, "d% is a d100")
    for _, bad in ipairs({ "", "d", "2x6", "2d6++", "abc", "0d6" }) do
        ok(not pcall(dice.parse, bad), "'" .. bad .. "' should be refused")
    end
end

-- Keep highest is Advantage: the better of two d20s, the same two dice in the same order as rolling them one by one.
do
    local a, b = rng_mod.new(11), rng_mod.new(11)
    for _ = 1, 200 do
        local r = dice.roll(a, "2d20kh1")
        local x, y = b:d20(), b:d20()
        ok(r.total == math.max(x, y), "2d20kh1 is the better of the same two d20s")
    end
end

-- A seeded roll is the same roll, and one d20 off the kit is one d20 off the game's own source.
do
    local a, b = rng_mod.new(99), rng_mod.new(99)
    for _ = 1, 500 do
        ok(dice.roll(a, "1d20").total == b:d20(), "1d20 from the kit matches rng:d20()")
    end
end

-- Pools count successes; forced faces (the rules engine's tests) come through.
do
    local d = forced.new(1)
    d:force(6, 5, 2, 6, 1)
    local r = dice.roll(d, "5d6>=5")
    ok(r.total == 3, "5d6>=5 with 6,5,2,6,1 counts 3 (got " .. r.total .. ")")
    d:force(6, 6, 3)
    r = dice.roll(d, "1d6!")
    ok(r.total == 15, "an exploding 6, 6, 3 is 15 (got " .. r.total .. ")")
    d:force(3, 1, 2)
    r = dice.roll(d, "3dF")
    ok(r.total == 0, "Fate faces 3, 1, 2 are +, -, 0: 0 (got " .. r.total .. ")")
    ok(r.text == "3dF: +, -, 0 = 0", "Fate dice say their faces: " .. r.text)
    d:force(17, 4)
    r = dice.roll(d, "2d20kh1+3")
    ok(r.total == 20 and r.text == "2d20kh1+3: 17, (4) +3 = 20", "Advantage says the die it dropped: " .. r.text)
end

print(fails == 0 and ("dice kit: all clear (" .. #CASES .. " kinds of dice)") or ("dice kit: " .. fails .. " failures"))
os.exit(fails == 0 and 0 or 1)
