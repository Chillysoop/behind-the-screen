-- A16 rules check: Short and Long Rests per SRD 5.2.1, and the party's state carried across
-- nights. Run from the project root:   texlua tools/tests/rest_check.lua

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local party_mod = require "game.rules.party"
local rest = require "game.rules.rest"
local fight = require "game.model.fight"
local campaign_mod = require "game.model.campaign"

local fails, n = 0, 0
local function check(name, ok, detail)
    n = n + 1
    if not ok then
        fails = fails + 1
    end
    print(string.format("%s  %-58s %s", ok and "PASS" or "FAIL", name, detail or ""))
end

local function by_class(level, class)
    for _, c in ipairs(party_mod.build(level, nil)) do
        if c.class == class then
            return c
        end
    end
end

-- A dice stub that always rolls the given number.
local function fixed(v)
    return { roll = function() return v end }
end

do
    local f = by_class(3, "fighter")
    check("Hit Point Dice: one per level, a d10 for a fighter (SRD 5.2.1)", f.hd.max == 3 and f.hd.left == 3 and f.hd.die == 10)
    f.hp = 5
    local got = rest.spend_hit_dice(f, fixed(6), { upto = 1, keep = 0 })
    local con = require("game.rules.creature").mod(f.abilities.con)
    check("Short Rest: each die is the roll plus Con (SRD 5.2.1)", got == math.min(f.hp_max - 5, 3 * (6 + con)),
        "regained " .. got)
    local w = by_class(3, "wizard")
    w.hp = 1
    w.abilities.con = 1   -- Con -5: a roll of 1 would heal -4
    local g2 = rest.spend_hit_dice(w, fixed(1), { upto = 1, keep = 0 })
    check("A Hit Point Die always heals at least 1", g2 >= 1 and w.hd.left < w.hd.max, "regained " .. g2)
end

do
    local f = by_class(3, "fighter")
    f.res.second_wind, f.res.action_surge = 0, 0
    rest.short(f, fixed(5))
    check("Short Rest: one use of Second Wind back (SRD 5.2.1)", f.res.second_wind == 1)
    check("Short Rest: Action Surge back (SRD 5.2.1)", f.res.action_surge == 1)
    local c = by_class(3, "cleric")
    c.res.channel = 0
    rest.short(c, fixed(5))
    check("Short Rest: one Channel Divinity use back (SRD 5.2.1)", c.res.channel == 1)
    rest.short(c, fixed(5))
    rest.short(c, fixed(5))
    check("Channel Divinity never past its maximum", c.res.channel == c.res.channel_max, tostring(c.res.channel))
end

do
    local w = by_class(3, "wizard")
    for i in ipairs(w.res.slots) do
        w.res.slots[i] = 0
    end
    local r = rest.short(w, fixed(3))
    local total = 0
    for i, s in ipairs(w.res.slots) do
        total = total + s * i
    end
    check("Arcane Recovery: slots worth up to half the level, rounded up (SRD 5.2.1)", total == 2, "levels back " .. total)
    rest.short(w, fixed(3))
    local total2 = 0
    for i, s in ipairs(w.res.slots) do
        total2 = total2 + s * i
    end
    check("Arcane Recovery: once per Long Rest", total2 == total)
    rest.long(w)
    local full = true
    for i, s in ipairs(w.res.slots) do
        full = full and s == w.slots_max[i]
    end
    check("Long Rest: every spell slot back (SRD 5.2.1)", full)
    check("Long Rest: Arcane Recovery usable again", w.arcane_used == false)
end

do
    local f = by_class(3, "fighter")
    f.hp, f.temp, f.hd.left, f.res.potions = 3, 5, 0, 0
    rest.long(f)
    check("Long Rest: all HP back", f.hp == f.hp_max)
    check("Long Rest: all Hit Point Dice back (2024 rules)", f.hd.left == f.hd.max)
    check("Long Rest: Temporary Hit Points end", f.temp == 0)
    check("Long Rest: potions are things, not features", f.res.potions == 0)
    f.hp = 0
    f.down = true
    rest.long(f)
    check("Down but stable: they wake and rest from 1 HP", f.hp == f.hp_max and not f.down)
end

do
    -- The party's state carries across nights (cliffhangers pick up where they stopped).
    local bots = require "slice_bots"
    local c = campaign_mod.new(77)
    c:session_zero(bots.DMS.careful.s0)
    c:start_week()
    local night = c:start_night()
    fight.party(night)
    local before = {}
    for _, pc in ipairs(night.pc_list) do
        pc.hp = math.max(1, pc.hp - 7)
        if pc.res.slots and pc.res.slots[1] then
            pc.res.slots[1] = 0
        end
        if pc.hd then
            pc.hd.left = 1
        end
        before[pc.player_key] = { hp = pc.hp, slot = pc.res.slots and pc.res.slots[1], hd = pc.hd and pc.hd.left }
    end
    fight.save_state(night, false)
    local n2 = { campaign = c, players = night.players, rng = night.rng }
    fight.party(n2)
    local same = true
    for _, pc in ipairs(n2.pc_list) do
        local b = before[pc.player_key]
        same = same and b and pc.hp == b.hp and (pc.res.slots and pc.res.slots[1]) == b.slot and (pc.hd and pc.hd.left) == b.hd
    end
    check("No rest since: next night starts with the same HP, slots and Hit Dice", same)
    fight.save_state(night, true)
    local n3 = { campaign = c, players = night.players, rng = night.rng }
    fight.party(n3)
    local full = true
    for _, pc in ipairs(n3.pc_list) do
        full = full and pc.hp >= pc.hp_max - 0 or (pc.hp == pc.hp_max)
    end
    check("A night that ended in town starts rested", full)
    local save = require "game.model.save"
    local ok, err = pcall(function()
        local blob = save.dump(c)
        local back = save.load(blob)
        assert(back.party_state and back.party_state.pcs, "no party state in the save")
    end)
    check("The party's state is in the save", ok, ok and "" or tostring(err))
end

print(string.format("%d of %d rest checks pass", n - fails, n))
os.exit(fails == 0 and 0 or 1)
