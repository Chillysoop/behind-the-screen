-- Step 4 of docs/design/rule-sets.md: fights both ways, for any rule set.
--   GRID     another rule set (tools/tests/fixtures/skirmish_set.lua: 2d6, three harm and you're out) fights on the
--            table's grid with rules of its own: round a wall, through a door, to a winner, with none of 5e's engine
--            loaded and none of 5e's words said.
--   STORY    a fight told as story (game/model/story_fight.lua) under that other set: its dice, its words, never 5e's.
--   STORY5E  a 5e adventure's room told as story instead of on the grid: the Sheep Chase's yard and bedroom, whole
--            playthroughs to an ending, the fight in the log, no attack rolls against AC in those rooms.
--     lua tools/tests/rule_sets_check.lua

package.path = "./?.lua;./tools/tests/?.lua;./tools/tests/fixtures/?.lua;" .. package.path
unpack = unpack or table.unpack

local fails = 0
local function ok(cond, what)
    if not cond then
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

-- GRID (first, before anything loads 5e) -------------------------------------------------------------------------
local skirmish = require "skirmish_set"
local grid = require "game.kit.grid"
local rng_mod = require "game.model.rng"
do
    for seed = 1, 20 do
        -- A wall down the middle, a door in it at row 4.
        local opaque, doors = {}, {}
        for y = 1, 8 do
            if y ~= 4 then
                opaque[grid.key(6, y)] = true
            end
        end
        doors[grid.key(6, 4)] = { state = "open", x = 6, y = 4 }
        local r = skirmish.grid_fight({ opaque = opaque, doors = doors, sides = {
            a = { { name = "Ash", x = 2, y = 2, edge = 1 }, { name = "Bel", x = 2, y = 6, edge = 0 } },
            b = { { name = "Cog", x = 10, y = 3, edge = 0 }, { name = "Dun", x = 10, y = 7, edge = 1 } } } }, rng_mod.new(seed))
        ok(r.winner ~= nil, "GRID seed " .. seed .. ": the skirmish on the shared grid comes to a winner (" .. r.rounds .. " rounds)")
        for _, c in ipairs(r.board.creatures) do
            ok(not r.board:opaque_at(c.x, c.y), "GRID seed " .. seed .. ": " .. c.name .. " never stands in the wall")
        end
    end
    for _, name in ipairs({ "game.rules.battle", "game.rules.ai", "game.rules.creature", "game.rules.spells", "game.rules.sets.dnd5e" }) do
        ok(package.loaded[name] == nil, "GRID another set's grid fight loaded 5e's " .. name)
    end
end

-- STORY under the other set ---------------------------------------------------------------------------------------
local ruleset = require "game.model.ruleset"
local story_fight = require "game.model.story_fight"
local util = require "game.model.util"
local dnd5e = ruleset.SETS["5e"]
local function five_e_words(text)
    for _, w in ipairs(dnd5e.owns) do
        if string.find(text, w) then
            return w
        end
    end
    for _, w in ipairs({ "%f[%w]d20%f[%W]", "natural 20", "%f[%w]AC%f[%W]" }) do
        if string.find(text, w) then
            return w
        end
    end
end
do
    ruleset.SETS.skirmish = skirmish
    local current = ruleset.current
    ruleset.current = function()
        return skirmish
    end
    local outcomes = {}
    for seed = 1, 12 do
        -- (A night's few pieces a story fight uses, and nothing of 5e's: who's at the table, what they say.)
        local said, logged = {}, nil
        local night = { rng = rng_mod.new(seed), campaign = { week = 1 } }
        night.players = {
            { key = "dev", char = "Brannoc", class = "fighter" }, { key = "mara", char = "Thessaly", class = "wizard" },
            { key = "jess", char = "Pip", class = "rogue" }, { key = "sam", char = "Oswin", class = "cleric" },
        }
        for _, p in ipairs(night.players) do
            p.bars = { spotlight = 50, fun = 50, challenge = 50 }
        end
        function night:at_hand() return self.players end
        function night:fresh(list) return list[self.rng:int(1, #list)] end
        function night:say(text) table.insert(said, text) end
        function night:emit(ev) table.insert(said, ev.text or "") end
        function night:best_skill(p, list)
            local best, bm
            for _, a in ipairs(list) do
                local m = skirmish.mod(p.class, a)
                if not bm or m > bm then best, bm = a, m end
            end
            return best, bm
        end
        function night:log_fight(sc, f, result) logged = result end
        local sc = { difficulty = 2, encounter = { boss_name = "the bandits", ids = { "bandit" } } }
        local score = require "game.model.score"
        local add = score.add
        score.add = function() end
        local result = story_fight.run(night, sc)
        score.add = add
        outcomes[result.winner] = (outcomes[result.winner] or 0) + 1
        ok(logged == result and (sc.outcome == "win" or sc.outcome == "lose"), "STORY seed " .. seed .. ": the fight is logged, with how it came out")
        local checks = 0
        for _, t in ipairs(said) do
            local w = five_e_words(t)
            ok(not w, "STORY seed " .. seed .. ": 5e's '" .. tostring(w) .. "' in another set's story fight: " .. t)
            if string.find(t, "^%a+: %a+ %d%+%d") then
                checks = checks + 1
            end
        end
        ok(checks > 0, "STORY seed " .. seed .. ": the checks are the set's own (2d6, its stats)")
    end
    ok((outcomes.party or 0) > 0, "STORY the party wins some story fights")
    ruleset.current = current
    ruleset.SETS.skirmish = nil
end

-- STORY5E: whole Sheep Chases with the yard and the bedroom told as story ----------------------------------------
do
    local rooms = { compound = "The tower's yard", bedroom = "The bedroom" }
    local played = 0
    for seed = 1, 6 do
        local h = io.popen("ADVENTURE=sheep STORY_ROOMS=compound,bedroom lua tools/sim/museum.lua " .. seed .. " careful log 2>&1; echo EXIT=$?")
        local out = h:read("a")
        h:close()
        ok(string.find(out, "EXIT=0", 1, true) ~= nil, "STORY5E seed " .. seed .. ": the playthrough ends cleanly")
        local scene
        for line in string.gmatch(out, "[^\n]+") do
            local name = string.match(line, "^== Scene %d+: (.-) %(")
            if name then
                scene = name
            end
            if scene == rooms.compound or scene == rooms.bedroom then
                ok(not string.find(line, "vs AC %d"), "STORY5E seed " .. seed .. ": a grid attack in " .. scene .. ", told as story: " .. line)
                if string.find(line, "against the party%.") or string.find(line, "comes at them%.") or string.find(line, "And it's on, against") then
                    played = played + 1
                end
            end
        end
    end
    ok(played >= 6, "STORY5E the story fights were played (" .. played .. " of them in six playthroughs)")
end

print(fails == 0 and "rule sets check: all clear" or ("rule sets check: " .. fails .. " failures"))
os.exit(fails == 0 and 0 or 1)
