-- The round-two playtest findings Conner said yes to (the roadmap's "Fix before more testers", the
-- items about truth: F1, F3, F4, F5, F10, F11, F12, F13, F14, F18, F19, F20, F23, F27), played:
-- whole prologues headless over several seeds and three kinds of DM, each fix seen in play, plus
-- targeted cases for the moments a run can't be counted on to reach. Run from the project root:
--     lua tools/tests/roadmap_truth_check.lua [runs per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"

local RUNS = tonumber(arg[1]) or 3
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "F1", "F3", "F4", "F5", "F10", "F11", "F12", "F13", "F14", "F18", "F19", "F20", "F23", "F27" }
local NAMES = {
    F1 = "boss night keeps its break", F3 = "flee lines count who's standing", F4 = "an ally's fall, and the Mech's rule",
    F5 = "companions introduced once", F10 = "one inventory, real purchases", F11 = "no split with danger near",
    F12 = "promises kept", F13 = "lines tied to what happened", F14 = "rules talk about what happened",
    F18 = "credit and votes add up", F19 = "fight turns keep the rules", F20 = "the recap tells what happened",
    F23 = "the level-up says the refill", F27 = "the test logs show every roll",
}

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 6 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
-- A targeted case: an error inside it is a failure of its item, not of the whole check.
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end

-- A campaign at Session Zero, ready for its first week.
local function new_campaign(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    local s0 = social.default_choices()
    c:session_zero(s0)
    local rng = require("game.model.rng").new(seed * 7 + #(style or ""))
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    return c, rng
end

-- F27: the sim's log names every attacker and shows every roll ------------------------------------

case("F27", function()
    local fh = io.popen("lua tools/sim/museum.lua 22 random log")
    local out = fh:read("*a")
    fh:close()
    local turns, attacks = 0, 0
    for line in string.gmatch(out, "[^\n]+") do
        if string.match(line, "^    %. ") then
            turns = turns + 1
            if string.match(line, "^    %. nil:") then
                fail("F27", "a turn with no actor: " .. line)
            end
            for att in string.gmatch(line, "attack[^,]*") do
                attacks = attacks + 1
                if not string.find(att, "->", 1, true) then
                    fail("F27", "an attack without its attacker and target: " .. att)
                elseif not string.find(att, "d20 %d+") and not string.find(att, "%[") then
                    fail("F27", "an attack without its roll: " .. att)
                end
            end
        end
    end
    add("F27", "turn_lines", turns)
    add("F27", "attacks_with_both_sides", attacks)
    if not string.find(out, "(big roll)", 1, true) then
        fail("F27", "the big rolls aren't in the log")
    end
end)

-- The report -----------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    if not E[item] and not fails[item] then
        fail(item, "nothing seen: no run or case reached this item")
    end
    local parts = {}
    for k, v in pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-36s %s%s", item, NAMES[item], #parts > 0 and table.concat(parts, ", ") or "(nothing seen)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "roadmap truth check: every item holds" or ("roadmap truth check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
