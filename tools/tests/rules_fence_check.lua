-- No leaks between rule sets (docs/design/rule-sets.md, "No leaks: the first rule"; Conner, November 6: "It's critical
-- that systems never leak into another system"). The fences that can stand now, with one set:
--   RULES    every adventure names a rule set the game has; none goes without (nothing defaults to 5e).
--   DICE     no shared module rolls a system's die itself: rolls come from the rule set (its `die`, `check`).
--   REQUIRE  the shared game (game/model, game/ui) reaches a system's engine (game/rules) only through
--            game/model/ruleset.lua. The ones still to move are listed in rules_fence_known.lua: a new one fails, and so
--            does a listed one that's gone (so the list only shrinks, and stays true).
--   WORDS    5e's own words (DC, Advantage, natural 20, hit points...) in the shared layer's code and data, per file:
--            no file may gain any (the known counts are in rules_fence_known.lua, and they only go down).
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
local WORDS = {      -- 5e's own words (game/rules/sets/dnd5e.lua is the only shared door to them)
    "%f[%w]d20s?%f[%W]", "%f[%w]DCs?%f[%W]", "%f[%w]Advantage%f[%W]", "%f[%w]Disadvantage%f[%W]", "natural 20", "natural 1%f[%D]",
    "spell slot", "hit points", "%f[%w]HP%f[%W]", "%f[%w]AC%f[%W]", "Armor Class", "saving throw", "death save",
    "Heroic Inspiration", "Proficiency", "cantrip", "short rest", "long rest", "%f[%w]Insight%f[%W]", "%f[%w]Arcana%f[%W]",
    "%f[%w]Perception%f[%W]", "%f[%w]Investigation%f[%W]", "%f[%w]Persuasion%f[%W]", "%f[%w]Stealth%f[%W]",
    "%f[%w]Athletics%f[%W]", "%f[%w]Concentration%f[%W]", "%f[%w]Bless%f[%W]", "Cure Wounds", "Healing Word", "Detect Magic",
}
local leaks, counts, seen_known = {}, {}, {}
for _, path in ipairs(shared) do
    local s = read(path)
    local lines = code_lines(s, path)
    local n = 0
    for _, line in ipairs(lines) do
        if path ~= "game/model/rng.lua" and string.find(line, ":d20%(") then
            fail("DICE " .. path .. " rolls a d20 itself: " .. line:gsub("^%s+", ""))
        end
        for _, w in ipairs(WORDS) do
            if string.find(line, w) then
                n = n + 1
                break
            end
        end
        for mod in string.gmatch(line, 'require%(?%s*"game%.rules%.([%w_%.]+)"') do
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
        fail("WORDS " .. path .. " has " .. n .. " lines with 5e's words, " .. k .. " known: put them behind the rule set, "
            .. "or tag the record rules = \"5e\" (and lower the count once the fence can read tags)")
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
print(string.format("rules fence: %s (%d adventures; %d direct reaches into the 5e engine still to move; %d shared lines with 5e words)",
    #fails == 0 and "all clear" or (#fails .. " failures"), n_adv, nreq, total))
os.exit(#fails == 0 and 0 or 1)
