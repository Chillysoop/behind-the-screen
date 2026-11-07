-- No leaks between rule sets (docs/design/rule-sets.md, "No leaks: the first rule"; Conner, November 6: "It's critical
-- that systems never leak into another system"). The fences that can stand now, with one set:
--   RULES    every adventure names a rule set the game has; none goes without (nothing defaults to 5e).
--   ROLLS    no shared module rolls a check's die itself: the rule set picks the dice (from the table's own,
--            game/kit/dice.lua, which any set may use: d20s, d6s, pools, Fate dice).
--   REQUIRE  the shared game (game/model, game/ui) reaches a system's engine (game/rules) only through
--            game/model/ruleset.lua. The ones still to move are listed in rules_fence_known.lua: a new one fails, and so
--            does a listed one that's gone (so the list only shrinks, and stays true).
--   WORDS    a rule set's own words (5e's: DC, Advantage, hit points... its `owns`) and fixed dice ("the d20") in the
--            shared layer's code and data, per file: no file may gain any (the known counts are in
--            rules_fence_known.lua, and they only go down). Dice and grids are the table's, not a system's: shared text
--            names the dice the roll used, never a fixed one.
--     lua tools/tests/rules_fence_check.lua

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventures = require "game.data.adventures"
local ruleset = require "game.model.ruleset"
local ok_known, known = pcall(require, "rules_fence_known")
if not ok_known or os.getenv("FENCE_WRITE") then
    known = { REQUIRES = {}, WORDS = {} }
end

local fails = {}
local function fail(what)
    table.insert(fails, what)
    print("  FAIL " .. what)
end
local function files(glob)
    local out = {}
    local h = io.popen("ls " .. glob .. " 2>/dev/null")
    for line in h:lines() do
        table.insert(out, line)
    end
    h:close()
    return out
end
local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("a")
    f:close()
    return s
end
local function code_lines(s, path)
    local out = {}
    local json = string.find(path, "%.json$") ~= nil
    for line in string.gmatch(s, "[^\n]*") do
        if not string.find(line, json and "^%s*//" or "^%s*%-%-") then
            table.insert(out, line)
        end
    end
    return out
end

-- RULES ----------------------------------------------------------------------------------------------------------
local n_adv = 0
for id, a in pairs(adventures.list) do
    n_adv = n_adv + 1
    local ok, m = pcall(a.module)
    if not ok then
        fail("RULES " .. id .. ": its module didn't load (" .. tostring(m) .. ")")
    elseif not m.rules then
        fail("RULES " .. id .. " doesn't name its rule set (`M.rules`): nothing defaults to 5e")
    elseif not ruleset.SETS[m.rules] then
        fail("RULES " .. id .. " names a rule set the game doesn't have: " .. tostring(m.rules))
    end
end
do
    local ok = pcall(ruleset.get, nil)
    if ok then
        fail("RULES ruleset.get(nil) gave a set: nothing may default")
    end
end

-- DICE, REQUIRE, WORDS -------------------------------------------------------------------------------------------
local shared = {}
for _, glob in ipairs({ "game/model/*.lua", "game/ui/*.lua", "game/data/*.lua", "game/data/dialogue/*.json" }) do
    for _, f in ipairs(files(glob)) do
        table.insert(shared, f)
    end
end
-- Every set's own words, and the dice shared text mustn't fix: what a roll used comes from the roll.
local FIXED_DICE = { "%f[%w]d20s?%f[%W]", "%f[%w]d6s?%f[%W]", "%f[%w]2d6%f[%W]", "%f[%w]d100%f[%W]" }
local WORDS = {}
for _, w in ipairs(FIXED_DICE) do
    table.insert(WORDS, w)
end
for _, set in pairs(ruleset.SETS) do
    for _, w in ipairs(set.owns or {}) do
        table.insert(WORDS, w)
    end
end
local leaks, counts, seen_known = {}, {}, {}
for _, path in ipairs(shared) do
    local s = read(path)
    local lines = code_lines(s, path)
    local n = 0
    for _, line in ipairs(lines) do
        if path ~= "game/model/rng.lua" and string.find(line, ":d20%(") then
            fail("ROLLS " .. path .. " rolls a d20 itself (the rule set picks the dice): " .. line:gsub("^%s+", ""))
        end
        for _, w in ipairs(WORDS) do
            if string.find(line, w) then
                n = n + 1
                break
            end
        end
        -- (Any way of naming a module of game/rules: require, pcall(require, ...), util.lazy.)
        for mod in string.gmatch(line, '"game%.rules%.([%w_%.]+)"') do
            if not (path == "game/model/ruleset.lua" and string.find(mod, "^sets%.")) then
                leaks[path] = leaks[path] or {}
                leaks[path][mod] = true
            end
        end
    end
    counts[path] = n
end
for path, mods in pairs(leaks) do
    for mod in pairs(mods) do
        local k = path .. " " .. mod
        seen_known[k] = true
        if not known.REQUIRES[k] then
            fail("REQUIRE " .. path .. " reaches the 5e engine directly (game.rules." .. mod .. "): go through the rule set")
        end
    end
end
for k in pairs(known.REQUIRES) do
    if not seen_known[k] then
        fail("REQUIRE " .. k .. " is listed as still to move, but it's gone: take it off rules_fence_known.lua")
    end
end
local total, was = 0, 0
for path, n in pairs(counts) do
    total = total + n
    local k = known.WORDS[path] or 0
    was = was + math.min(n, k)
    if n > k then
        fail("WORDS " .. path .. " has " .. n .. " lines with a rule set's own words or a fixed die, " .. k .. " known: "
            .. "put them behind the rule set, say the roll's own dice, or tag the record rules = \"<set>\"")
    end
end
for path, k in pairs(known.WORDS) do
    if (counts[path] or 0) < k then
        print(string.format("  (fewer 5e words in %s now: %d, was %d; lower it in rules_fence_known.lua)", path, counts[path] or 0, k))
    end
end

-- (FENCE_WRITE=1 writes the list as it stands: only for the first time, or after moving things behind the set.)
if os.getenv("FENCE_WRITE") then
    local out = { "-- What's still to move behind the rule set (tools/tests/rules_fence_check.lua). Only ever shrinks.",
                  "local M = {}", "-- A shared module reaching into the 5e engine directly: \"<file> <module>\".", "M.REQUIRES = {" }
    local keys = {}
    for path, mods in pairs(leaks) do
        for mod in pairs(mods) do
            table.insert(keys, path .. " " .. mod)
        end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(out, string.format("    [%q] = true,", k))
    end
    table.insert(out, "}")
    table.insert(out, "-- Lines with 5e's words in a shared file (not comments).")
    table.insert(out, "M.WORDS = {")
    local paths = {}
    for path, n in pairs(counts) do
        if n > 0 then
            table.insert(paths, path)
        end
    end
    table.sort(paths)
    for _, path in ipairs(paths) do
        table.insert(out, string.format("    [%q] = %d,", path, counts[path]))
    end
    table.insert(out, "}")
    table.insert(out, "return M")
    local f = assert(io.open("tools/tests/rules_fence_known.lua", "w"))
    f:write(table.concat(out, "\n") .. "\n")
    f:close()
    print("wrote tools/tests/rules_fence_known.lua")
    os.exit(0)
end
local nreq = 0
for _ in pairs(known.REQUIRES) do
    nreq = nreq + 1
end
print(string.format("rules fence: %s (%d adventures; %d direct reaches into the 5e engine still to move; %d shared lines with a set's own words or a fixed die)",
    #fails == 0 and "all clear" or (#fails .. " failures"), n_adv, nreq, total))
os.exit(#fails == 0 and 0 or 1)
