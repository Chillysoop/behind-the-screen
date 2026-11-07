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

-- SAVES and HAND-OFFS: a save names its rule set and won't load under another; carrying on into another set's
-- adventure is refused (the table carries, the system doesn't, and that carry isn't built yet) -------------------
do
    local adventure = require "game.model.adventure"
    local save = require "game.model.save"
    local campaign_mod = require "game.model.campaign"
    adventure.use("museum")
    local c = campaign_mod.new(3)
    adventure.enter(c)
    local text = save.dump(c, { where = "fence" })
    local head = save.peek(text)
    if not (head and head.rules == "5e") then
        fail("SAVES a save doesn't say its rule set (R=): " .. tostring(head and head.rules))
    end
    local other = string.gsub(text, "\nR=5e\n", "\nR=fence_test\n", 1)
    local back, why = save.load(other)
    if back or not string.find(tostring(why), "another rule set", 1, true) then
        fail("SAVES a save made under another rule set loaded anyway (" .. tostring(why) .. ")")
    end
    if not save.load(text) then
        fail("SAVES the same save under its own rule set didn't load")
    end
    -- A second set, for the test only, and the Sheep Chase pretending to be in it.
    ruleset.SETS.fence_test = { id = "fence_test", title = "Fence test" }
    local part = adventures.part
    adventures.part = function(id, name)
        local m = part(id, name)
        if id == "sheep" and name == "module" then
            local copy = setmetatable({ rules = "fence_test" }, { __index = m })
            return copy
        end
        return m
    end
    adventure.use("museum")
    c = campaign_mod.new(4)
    adventure.enter(c)
    local ok, err = pcall(adventure.handoff, c, "sheep")
    if ok or not string.find(tostring(err), "carries the table, not the system", 1, true) then
        fail("HANDOFF carrying on into another rule set's adventure wasn't refused (" .. tostring(err) .. ")")
    end
    adventures.part = part
    ruleset.SETS.fence_test = nil
end

-- FITS: under another set, none of 5e's tagged things are offered: its decision cards, its bag, its ways of digging --
do
    local adventure = require "game.model.adventure"
    local campaign_mod = require "game.model.campaign"
    local dm_bag = require "game.model.dm_bag"
    adventure.use("museum")
    local c = campaign_mod.new(5)
    adventure.enter(c)
    local five = #dm_bag.stock(c)
    local current = ruleset.current
    ruleset.current = function()
        return { id = "fence_test", title = "Fence test" }
    end
    local n = #dm_bag.stock(c)
    local cards = 0
    for _, d in ipairs(require("game.model.content").decisions) do
        if ruleset.fits(d) and d.rules then
            cards = cards + 1
        end
    end
    local ways_fit = ruleset.fits(require("game.data.find_out").ways)
    ruleset.current = current
    if five == 0 then
        fail("FITS the DM's bag is empty in a 5e adventure")
    end
    if n > 0 then
        fail("FITS another set's adventure is offered " .. n .. " of 5e's things from the DM's bag")
    end
    if cards > 0 then
        fail("FITS another set's adventure would be dealt " .. cards .. " of 5e's decision cards")
    end
    if ways_fit then
        fail("FITS another set's adventure would dig with 5e's ways (skills and spells)")
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
-- A file that says "-- rules: <set>" at its top is that set's own (5e's grid fight, its sheet...): its words are its
-- set's, and the shared game may only reach it through the rule set, never by name.
local owned, owned_by = {}, {}
for _, path in ipairs(shared) do
    local set_id = string.match(read(path), "^%-%- rules: ([%w_]+)")
    if set_id then
        owned[path] = set_id
        local mod = string.match(path, "^(game/.+)%.lua$")
        if mod then
            owned_by[string.gsub(mod, "/", ".")] = set_id
        end
    end
end
local leaks, counts, seen_known = {}, {}, {}
for _, path in ipairs(shared) do
    local s = read(path)
    local lines = code_lines(s, path)
    local n = 0
    if owned[path] then
        if not ruleset.SETS[owned[path]] then
            fail("OWNED " .. path .. " says it's the rule set " .. owned[path] .. "'s, and there's no such set")
        end
        lines = {}
    end
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
        -- (A set's own module named from the shared game: it goes through the rule set instead.)
        for name in string.gmatch(line, '"(game%.[%w_%.]+)"') do
            if owned_by[name] then
                leaks[path] = leaks[path] or {}
                leaks[path]["owned " .. name] = true
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
-- The shared data (game/data/*.lua) is read as data, not lines: a record tagged `rules = "<set>"` (and everything in
-- it) is that set's, and only shows in its adventures; a string with a set's words or a fixed die anywhere else is a
-- leak. So tagging a record takes it off the count.
local function has_words(str)
    for _, w in ipairs(WORDS) do
        if string.find(str, w) then
            return true
        end
    end
    return false
end
local function walk(v, seen, tally)
    if type(v) == "string" then
        if has_words(v) then
            tally.n = tally.n + 1
        end
    elseif type(v) == "table" and not seen[v] then
        seen[v] = true
        if v.rules ~= nil and ruleset.SETS[v.rules] then
            return
        end
        for k, x in pairs(v) do
            if k ~= "match" then         -- (a glossary term's patterns aren't shown: its words are)
                walk(x, seen, tally)
            end
        end
    end
end
for _, path in ipairs(shared) do
    local mod = string.match(path, "^game/data/([%w_]+)%.lua$")
    if mod then
        local ok, data = pcall(require, "game.data." .. mod)
        if ok and type(data) == "table" then
            local tally = { n = 0 }
            walk(data, {}, tally)
            counts[path] = tally.n
        end
    end
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
