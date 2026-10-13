-- The Story log (game/model/chronicle.lua): play several campaigns with the slice bots and check
-- every storyline's log holds together. Each scene that played is filed once, under the
-- storylines it moved; every storyline that moved has scenes in its log; every bullet reads as
-- sentences (no nil, no {placeholders}, nothing said twice); tonight's scenes show while the
-- night is on; this week's board shows as plans with the placed card marked; keywords split
-- text without losing any of it and every one explains itself; a save keeps the log; and an
-- old save without one gets a log rebuilt from its notebook.
-- Run from the project root:  lua tools/tests/chronicle_check.lua [campaigns] [weeks]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local campaign_mod = require "game.model.campaign"
local bots = require "slice_bots"
local rng_mod = require "game.model.rng"
local chronicle = require "game.model.chronicle"
local storylines = require "game.model.storylines"
local save = require "game.model.save"
local util = require "game.model.util"

local CAMPAIGNS = tonumber(arg[1]) or 6
local WEEKS = tonumber(arg[2]) or 4

local problems = {}
local function problem(msg)
    if #problems < 40 then
        table.insert(problems, msg)
    end
end

local stats = { scenes = 0, entries = 0, live = 0, planned = 0, focus = 0, words = 0, keywords = 0, backfilled = 0 }

local function check_text(where, text)
    if type(text) ~= "string" or text == "" then
        problem(where .. ": empty text")
        return
    end
    if string.find(text, "nil", 1, true) and string.find(text, "%f[%w]nil%f[%W]") then
        problem(where .. ": 'nil' in " .. text)
    end
    if string.find(text, "{[%w_]+}") then
        problem(where .. ": unfilled placeholder in " .. text)
    end
    if string.find(text, "[\128-\255]") then
        problem(where .. ": non-ASCII in " .. text)
    end
    if string.find(text, "  ") then
        problem(where .. ": double space in " .. text)
    end
end

local function check_view(c, v, where)
    if not v then
        problem(where .. ": no view")
        return
    end
    check_text(where .. " premise", v.premise)
    local seen = {}
    for _, e in ipairs(v.entries) do
        stats.entries = stats.entries + 1
        if #e.parts == 0 then
            problem(where .. ": an entry with nothing in it (" .. tostring(e.tag) .. " " .. tostring(e.w) .. "/" .. tostring(e.s) .. ")")
        end
        local said = {}
        for _, p in ipairs(e.parts) do
            check_text(where .. " entry", p)
            if said[p] then
                problem(where .. ": said twice: " .. p)
            end
            said[p] = true
            if not string.match(p, "[%.!?\"']$") then
                problem(where .. ": doesn't end a sentence: " .. p)
            end
            stats.words = stats.words + select(2, string.gsub(p, "%S+", ""))
        end
        local key = tostring(e.tag) .. ":" .. tostring(e.w) .. ":" .. tostring(e.s)
        if seen[key] then
            problem(where .. ": the same scene twice: " .. key)
        end
        seen[key] = true
        if e.tag == "tonight" then
            stats.live = stats.live + 1
        elseif e.tag == "planned" then
            stats.planned = stats.planned + 1
        end
        if e.focus then
            stats.focus = stats.focus + 1
        end
    end
    for _, kind in ipairs({ "people", "places", "heroes", "factions" }) do
        for _, it in ipairs(v.cast[kind]) do
            check_text(where .. " " .. kind, it.name or it.char)
        end
    end
    for _, l in ipairs(v.leads) do
        check_text(where .. " lead", l.name)
    end
end

-- Keywords: none twice, marking keeps every byte, each one defines itself.
local function check_keywords(c, texts)
    local kws = chronicle.keywords(c)
    local terms = {}
    for _, k in ipairs(kws) do
        if terms[k.term] then
            problem("keyword twice: " .. k.term)
        end
        terms[k.term] = true
        local ok, d = pcall(chronicle.define, c, k)
        if not ok then
            problem("define " .. k.term .. ": " .. tostring(d))
        elseif not d.title or d.title == "" then
            problem("keyword without a title: " .. k.term)
        else
            for _, ln in ipairs(d.lines) do
                check_text("define " .. k.term, ln.text)
            end
        end
    end
    for _, t in ipairs(texts) do
        local segs = chronicle.mark(t, kws)
        local out = {}
        for _, s in ipairs(segs) do
            table.insert(out, s.text)
            if s.kw then
                stats.keywords = stats.keywords + 1
            end
        end
        if table.concat(out) ~= t then
            problem("marking lost text: " .. t)
        end
    end
end

for n = 1, CAMPAIGNS do
    local seed = 1000 + n * 37
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed * 3)
    local dm = ({ bots.DMS.careful, bots.DMS.plain, bots.DMS.careless })[n % 3 + 1]
    c:session_zero(dm.s0)
    for w = 1, WEEKS do
        local prep = c:start_week()
        bots.prep(dm, c, prep, rng)
        -- This week's board: every storyline it touches shows its plans, the placed card marked.
        for _, s in ipairs(prep.scenes) do
            for _, card in pairs(s.slots) do
                for _, id in ipairs(storylines.of_card(c, card)) do
                    local v = chronicle.story(c, id, { prep = prep, focus = card.id })
                    check_view(c, v, "planned " .. id)
                    local found = false
                    for _, e in ipairs(v and v.entries or {}) do
                        found = found or (e.tag == "planned" and e.focus)
                    end
                    if not found then
                        problem(string.format("seed %d week %d: %s on the board but %s's log doesn't show it planned", seed, w,
                            card.id, id))
                    end
                end
            end
        end
        local night = c:start_night()
        local before = #chronicle.get(c).scenes
        bots.play_night(night, rng, dm, function(ev, nt)
            -- Tonight, while it plays: the scene before this one is in its storylines' logs.
            if ev.kind == "scene" and ev.index and ev.index > 1 then
                local prev = nt.scenes[ev.index - 1]
                for _, id in ipairs(prev and prev.terrain and prev.stories or {}) do
                    local v = chronicle.story(c, id, { night = nt })
                    local found = false
                    for _, e in ipairs(v.entries) do
                        found = found or (e.tag == "tonight" and e.s == prev.index)
                    end
                    if not found then
                        problem(string.format("seed %d week %d: tonight's scene %d isn't in %s's log while the night's on",
                            seed, w, prev.index, id))
                    end
                    check_view(c, v, "live " .. id)
                end
            end
        end)
        local played = 0
        for _, sc in ipairs(night.scenes) do
            if sc.terrain then
                played = played + 1
            end
        end
        c:finish_night()
        local recs = chronicle.get(c).scenes
        if #recs - before ~= played then
            problem(string.format("seed %d week %d: %d scenes played, %d filed", seed, w, played, #recs - before))
        end
        stats.scenes = stats.scenes + played
        for i = before + 1, #recs do
            local r = recs[i]
            if r.w ~= c.week then
                problem("a record filed under the wrong week")
            end
            local sc = night.scenes[r.s]
            if not util.contains(sc.stories or {}, r.stories[1] or "none") and #r.stories > 0 then
                problem("a record's storylines aren't the scene's")
            end
            if not r.out then
                problem("a record without an outcome")
            end
        end
    end
    -- Every storyline that moved has its scenes; every log reads.
    local texts = {}
    for _, d in ipairs(storylines.defs(c)) do
        local v = chronicle.story(c, d.id, {})
        check_view(c, v, "seed " .. seed .. " " .. d.id)
        local st = storylines.get(c)[d.id]
        local past = 0
        for _, e in ipairs(v.entries) do
            past = past + ((e.tag == "past") and 1 or 0)
            table.insert(texts, table.concat(e.parts, " "))
        end
        if st and (st.moves or 0) > 0 and past == 0 then
            problem(string.format("seed %d: %s moved %d nights but its log is empty", seed, d.id, st.moves))
        end
        if st and past < (st.moves or 0) then
            problem(string.format("seed %d: %s moved %d nights, its log has %d scenes", seed, d.id, st.moves, past))
        end
        table.insert(texts, v.premise or "")
    end
    check_keywords(c, texts)
    -- A save keeps the log.
    local text = save.dump(c)
    local c2 = save.load(text)
    if not c2 then
        problem("seed " .. seed .. ": the save didn't load")
    else
        local a, b = chronicle.get(c).scenes, chronicle.get(c2).scenes
        if #a ~= #b then
            problem("seed " .. seed .. ": the save lost Story log scenes")
        end
        for _, d in ipairs(storylines.defs(c)) do
            local v1, v2 = chronicle.story(c, d.id, {}), chronicle.story(c2, d.id, {})
            local t1, t2 = {}, {}
            for _, e in ipairs(v1.entries) do
                table.insert(t1, table.concat(e.parts, " "))
            end
            for _, e in ipairs(v2.entries) do
                table.insert(t2, table.concat(e.parts, " "))
            end
            if table.concat(t1, "|") ~= table.concat(t2, "|") then
                problem("seed " .. seed .. ": " .. d.id .. " reads differently after a save")
            end
        end
        -- An old save: no Story log, rebuilt from the notebook.
        c2.chronicle = nil
        local rebuilt = chronicle.get(c2).scenes
        stats.backfilled = stats.backfilled + #rebuilt
        if #rebuilt == 0 and #a > 0 then
            problem("seed " .. seed .. ": nothing rebuilt from the notebook")
        end
        for _, d in ipairs(storylines.defs(c2)) do
            check_view(c2, chronicle.story(c2, d.id, {}), "backfilled " .. d.id)
        end
    end
end

-- A hero falls and a new one takes the seat: the old hero's story stays readable (it ended with
-- them), and the new hero's story starts empty, never borrowing the old one's scenes.
do
    local c = campaign_mod.new(4242)
    local rng = rng_mod.new(77)
    c:session_zero(bots.DMS.careful.s0)
    for _ = 1, 3 do
        local prep = c:start_week()
        bots.prep(bots.DMS.careful, c, prep, rng)
        local night = c:start_night()
        bots.play_night(night, rng, bots.DMS.careful)
        c:finish_night()
    end
    local victim, had
    for _, p in ipairs(c.players) do
        local v = chronicle.story(c, "bs_" .. p.key, {})
        if not victim and v and #v.entries > 0 then
            victim, had = p, #v.entries
        end
    end
    if not victim then
        problem("no hero's story moved in three weeks (the fallen-hero check needs one)")
    else
        local old_char = victim.char
        victim.char, victim.pregen = "Sister Aldith", true
        storylines.get(c)
        local ended_id = "ended_bs_" .. victim.key .. "_" .. old_char
        local found
        for _, it in ipairs(chronicle.list(c, nil, nil)) do
            found = found or it.def.id == ended_id
        end
        if not found then
            problem("the fallen hero's story isn't in the Story log list")
        end
        local v = chronicle.story(c, ended_id, {})
        if not v or #v.entries ~= had then
            problem(string.format("the fallen hero's story kept %s of %d scenes", tostring(v and #v.entries), had))
        end
        check_view(c, v, "ended " .. ended_id)
        for _, e in ipairs(v and v.entries or {}) do
            for _, part in ipairs(e.parts) do
                if string.find(part, "Sister Aldith", 1, true) then
                    problem("the fallen hero's scenes name the new hero: " .. part)
                end
            end
        end
        local nv = chronicle.story(c, "bs_" .. victim.key, {})
        if nv and #nv.entries > 0 then
            problem("the new hero's story borrowed the old one's scenes")
        end
        if nv and nv.quote then
            problem("the new hero's story quotes the old hero's player intro")
        end
    end
end

print(string.format("chronicle: %d campaigns x %d weeks, %d scenes filed, %d entries read (%d live, %d planned, %d marked as "
    .. "just placed), %d words, %d keywords lit, %d scenes rebuilt from old notebooks", CAMPAIGNS, WEEKS, stats.scenes,
    stats.entries, stats.live, stats.planned, stats.focus, stats.words, stats.keywords, stats.backfilled))
if stats.live == 0 then
    problem("no live entries were ever checked")
end
if stats.planned == 0 or stats.focus == 0 then
    problem("no planned entries were ever checked")
end
if #problems > 0 then
    for _, p in ipairs(problems) do
        print("PROBLEM: " .. p)
    end
    print(#problems .. " PROBLEMS")
    os.exit(1)
end
print("CHRONICLE OK")
