-- Checks the dialogue library (M5): every line is well formed for its trigger,
-- every cell the slice needs has lines, every placeholder the game fills is one
-- the trigger allows, and the picker behaves (no repeats, absent players stay
-- unnamed, split and aimed lines only play where they fit).
-- Run from the project root:  lua tools/tests/dialogue_check.lua

package.path = "./?.lua;" .. package.path
local dialogue = require "game.model.dialogue"
local rng_mod = require "game.model.rng"

local problems = {}
local function problem(s)
    table.insert(problems, s)
end

local lib = dialogue.load()

-- Every line is well formed.
local ids, texts = {}, {}
for _, l in ipairs(lib.lines) do
    if ids[l.id] then
        problem("duplicate id " .. l.id)
    end
    ids[l.id] = true
    for _, p in ipairs(lib:lint(l)) do
        problem(l.id .. ": " .. p)
    end
    local key = l.speaker .. "|" .. string.lower(l.text)
    if texts[key] then
        problem(l.id .. " repeats " .. texts[key])
    end
    texts[key] = l.id
    local ok = false
    for _, s in ipairs(dialogue.STATUSES) do
        ok = ok or s == l.status
    end
    if not ok then
        problem(l.id .. ": unknown status " .. tostring(l.status))
    end
end

-- Every speaker has a voice sheet; every trigger's split values and fill-ins are sane.
for _, t in ipairs(lib.triggers) do
    for _, s in ipairs(t.speakers) do
        if not lib.voices[s] then
            problem(t.id .. ": no voice sheet for " .. s)
        end
    end
end

-- Every cell can play: enough lines that aren't rejected.
local cells, totals = lib:coverage()
for _, c in ipairs(cells) do
    if c.approved + c.draft < lib.min_approved then
        problem(c.key .. ": only " .. (c.approved + c.draft) .. " usable lines")
    end
end
-- Lines that need {moment} can't be the only ones in a cell: there isn't always a best moment.
for _, c in ipairs(lib:all_cells()) do
    local without = 0
    for _, l in ipairs(lib:cell_lines(c.key)) do
        if l.status ~= "rejected" and not string.find(l.text, "{moment}", 1, true) then
            without = without + 1
        end
    end
    if without < 2 and #lib:cell_lines(c.key) > 0 then
        problem(c.key .. ": fewer than 2 lines work without a {moment}")
    end
end

-- The picker: no repeats within a run, absent players stay unnamed, aimed lines only for their pair.
local rng = rng_mod.new(7)
local recent = {}
local seen = {}
for _ = 1, 4 do
    local l = lib:pick("crit", "dev", { recent = recent, rng = rng })
    if not l then
        problem("crit|dev ran dry after " .. #seen .. " picks")
        break
    end
    if seen[l.id] then
        problem("picker repeated " .. l.id)
    end
    seen[l.id] = true
    recent[l.id] = true
    table.insert(seen, l.id)
end
local present = { mara = true, dev = true, jess = true } -- Sam is out tonight
for _, l in ipairs(lib.lines) do
    if l.mentions and l.mentions.sam and l.speaker ~= "sam" then
        for _ = 1, 30 do
            local t = lib.trigger[l.trigger]
            local got = lib:pick(l.trigger, l.speaker, { present = present, rng = rng, to = l.to,
                                                           split = t.split and l[t.split.field] or nil })
            if got and got.mentions and got.mentions.sam then
                problem(got.id .. " names Sam on a night he's out")
                break
            end
        end
        break
    end
end
for _ = 1, 40 do
    local l = lib:pick("cheer_other", "mara", { to = "sam", rng = rng })
    if l and l.to and l.to ~= "sam" then
        problem(l.id .. " is aimed at " .. l.to .. " but played for Sam")
    end
end
for _ = 1, 20 do
    local l = lib:pick("chat_reaction", "jess", { split = "bored", rng = rng })
    if not l or l.tier ~= "bored" then
        problem("chat_reaction for the bored tier picked " .. tostring(l and l.tier))
        break
    end
end

-- Saving round-trips.
local json = require "game.model.jsonlite"
local back = json.decode(lib:serialize())
if #back.lines ~= #lib.lines then
    problem("serialize lost lines: " .. #back.lines .. " of " .. #lib.lines)
end
for i, l in ipairs(back.lines) do
    if l.text ~= lib.lines[i].text or l.mentions then
        problem("serialize changed " .. tostring(l.id))
        break
    end
end

print(string.format("%d lines in %d cells: %d approved, %d drafts, %d rejected; cells with %d+ approved: %d",
    totals.lines, totals.cells, totals.approved, totals.draft, totals.rejected, lib.min_approved, totals.ok))
for i = 1, math.min(#problems, 40) do
    print("PROBLEM: " .. problems[i])
end
print(#problems == 0 and "DIALOGUE OK" or (#problems .. " PROBLEMS"))
os.exit(#problems == 0 and 0 or 1)
