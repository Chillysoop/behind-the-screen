-- Save and resume: a museum campaign saved between sessions and loaded again carries on. Plays the
-- prologue with three kinds of DM (as tools/sim/museum.lua does), saves after Session Zero and after
-- each session, and checks that the save loads back to the same file, that it plays the same every
-- time it's loaded (two loads, the same choices, everything the table hears compared week by week),
-- that the original and the loaded copy both play on to an ending, and that a fresh Lua process
-- (fresh game data, so no table survives by accident) loads it and plays on. A save made at "Run
-- game night" or mid-prep picks up where it was.
-- (Why not the original against its loaded copy, line for line: a loaded campaign's tables are
-- built in another order than the original's, and some of the museum walks a table with pairs(),
-- so the two can draw their dice in another order. Two loads of one file are built alike.)
-- Run from the project root:   lua tools/tests/save_check.lua
-- Exit code 1 on any difference.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local thoughts = require "game.model.thoughts"
local rng_mod = require "game.model.rng"
local save = require "game.model.save"

local SCRATCH = os.getenv("TMPDIR") or "/tmp"
local STYLES = { "careful", "random", "careless" }

adventure.enter()

local function new_campaign(seed)
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = rng_mod.new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    return c
end

-- Between sessions and prep, as this kind of DM would (tools/sim/museum.lua).
local function prep_week(c, style, rng)
    local prep = c:start_week()
    for _, m in ipairs(c.chat) do
        if m.ask and not m.answered then
            museum_week.answer_chat(c, m, (style == "careful") and 1 or rng:int(1, 3))
        end
    end
    for _, pr in ipairs(c.adv.prompts) do
        if pr.kind == "request" then
            adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
        elseif pr.kind == "loose" then
            adventure.answer_loose(c, pr.id, 1)
        elseif pr.kind == "ruling" then
            adventure.answer_ruling(c, pr.id, style ~= "careless")
        elseif pr.kind == "favor" then
            adventure.answer_favor(c, pr.id, 1, 1)
        end
    end
    local pm = prep.museum
    if style ~= "careless" then
        museum_week.prep_greedy(prep)
        for _, id in ipairs(pm.ahead) do
            for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                local k = adventure.data.knobs[kid]
                museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
            end
        end
    end
    if pm.boss then
        c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
    end
    return prep
end

-- The night, answered as this kind of DM would; returns every line the table heard, in order.
local function play_night(c, style, rng)
    local night = c:start_night()
    local out = {}
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 4000 do
        guard = guard + 1
        local answer
        if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc" then
            out[#out + 1] = ev.kind .. " " .. tostring(ev.who or ev.name or ev.style) .. ": " .. tostring(ev.text)
        elseif ev.kind == "thought" then
            local aid = thoughts.bot_play(night, ev, style, rng)
            out[#out + 1] = "thought " .. tostring(ev.who) .. ": " .. tostring(ev.text) .. " -> " .. tostring(aid)
        elseif ev.kind == "decision" then
            local opts = ev.card.options
            answer = (style == "careful") and 1 or rng:int(1, #opts)
            if opts[answer].disabled then
                answer = 1
            end
            out[#out + 1] = "decision " .. tostring(ev.card.id) .. " -> " .. answer
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = rng:d20()
            out[#out + 1] = "roll " .. answer
        end
        ev = night:advance(answer)
    end
    local rep = c:finish_night()
    c:level_up()
    local st = c.adv
    out[#out + 1] = string.format("week %d: average %s, marks %s, francs %d, at %s, level %d", c.week, tostring(rep.average),
        table.concat(st.mark_list or {}, ","), st.francs or 0, tostring(st.at), c.level or 0)
    return table.concat(out, "\n")
end

local function play_week(c, style, rng)
    prep_week(c, style, rng)
    return play_night(c, style, rng)
end

local function play_rest(c, style, rng)
    local out = {}
    while not adventure.over(c) and c.week < adventure.data.MAX_WEEKS do
        out[#out + 1] = play_week(c, style, rng)
    end
    return out
end

-- Child mode: load a save from a file and play on (a fresh process, so a fresh content table).
if arg[1] == "child" then
    local f = assert(io.open(arg[2], "rb"))
    local src = f:read("*a")
    f:close()
    local c = assert(save.load(src))
    adventure.enter(c)
    io.write(save.dump(c) == src and "same\n" or "different\n")
    local rng = rng_mod.new(1)
    rng.s = tonumber(arg[4])
    play_rest(c, arg[3], rng)
    io.write("played on\n")
    os.exit(0)
end

local failures, checks = 0, 0
local function check(ok, what)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        print("  FAIL " .. what)
    end
end

local function first_diff(a, b)
    for i = 1, math.max(#a, #b) do
        if a:sub(i, i) ~= b:sub(i, i) then
            return string.format("at %d: ...%s... vs ...%s...", i, a:sub(math.max(1, i - 60), i + 60), b:sub(math.max(1, i - 60), i + 60))
        end
    end
    return "same"
end

local function copy_rng(rng)
    local r = rng_mod.new(1)
    r.s = rng.s
    return r
end

local biggest = 0
for _, style in ipairs(STYLES) do
    for run = 1, 2 do
        local seed = 9100 + run * 31
        for stop = 0, adventure.data.MAX_WEEKS do
            local a = new_campaign(seed)
            local rng = rng_mod.new(seed + 3)
            local w = 0
            while w < stop and not adventure.over(a) do
                play_week(a, style, rng)
                w = w + 1
            end
            if w < stop then
                break      -- (the prologue was over already)
            end
            local src = save.dump(a)
            biggest = math.max(biggest, #src)
            local b, err = save.load(src)
            check(b ~= nil, string.format("%s run %d: load after session %d (%s)", style, run, stop, tostring(err)))
            if b then
                adventure.enter(b)
                check(save.dump(b) == src, string.format("%s run %d: saving the loaded copy gives the same file", style, run))
                check(getmetatable(b) == campaign_mod and getmetatable(b.rng) == rng_mod and b.rng ~= a.rng and b.adv ~= a.adv,
                      style .. ": classes come back, nothing shared with the original")
                local path = SCRATCH .. "/bts_save_check.lua"
                local f = assert(io.open(path, "wb"))
                f:write(src)
                f:close()
                local rs = rng.s
                local b2 = assert(save.load(src))
                adventure.enter(b2)
                local want = play_rest(b, style, copy_rng({ s = rs }))
                local got = play_rest(b2, style, copy_rng({ s = rs }))
                check(#want == #got, string.format("%s run %d, saved after session %d: as many weeks, loaded twice (%d, %d)",
                    style, run, stop, #want, #got))
                for i = 1, #want do
                    local same = want[i] == got[i]
                    check(same, string.format("%s run %d, saved after session %d: week %d plays the same, loaded twice (%s)",
                        style, run, stop, stop + i, same and "" or first_diff(want[i], got[i] or "")))
                end
                check(adventure.over(b), string.format("%s run %d, saved after session %d: the loaded copy plays on to an ending",
                    style, run, stop))
                local ok, err2 = pcall(play_rest, a, style, rng)
                check(ok and adventure.over(a), string.format("%s run %d, saved after session %d: the original plays on to an ending (%s)",
                    style, run, stop, tostring(err2)))
                local exe = arg[-1] or "lua"
                local p = io.popen(string.format('%s tools/tests/save_check.lua child "%s" %s %d', exe, path, style, rs))
                local child = p:read("*a")
                p:close()
                -- (Lua 5.3 seeds its string hashing per process, so pairs() order and with it the rest of
                -- the campaign can differ from process to process even without a save. So a fresh
                -- process only has to rebuild the exact same campaign and play on without errors.)
                check(child == "same\nplayed on\n", string.format("%s run %d, saved after session %d: a fresh process loads the same campaign and plays on (%s)",
                    style, run, stop, child))
            end
        end
    end
end

-- Bad saves are refused, not half-loaded.
check(save.load("hello") == nil, "a file that isn't a save is refused")
check(save.load("F=99\nW=1\nS=1\nT[1]={}\n") == nil, "a save from another format is refused")
check(save.load('F=2\nW=1\nS=1\nT[1]={"s","x","c",{"no_such_table"}}\n') == nil, "a save pointing at missing game data is refused")
check(save.load('F=2\nW=1\nS=1\nT[1]={"s","x","t",7}\n') == nil, "a save with a broken link is refused")
check(save.load('F=2\nW=1\nS=1\nos.exit(1)\nT[1]={m="campaign"}\n') ~= nil, "lines that aren't table statements are ignored")
check(save.load('F=2\nW=1\nS=1\nT[1]={m="campaign"}\n') ~= nil, "a minimal campaign line loads")
check(save.load('F=2\nW=1\nS=1\nT[1]={}\n') == nil, "a save without a campaign is refused")
check(save.load('F=1\nW=1\nS=1\nT[1]={m="campaign"}\n') == nil, "a save from before the slice rework is turned away")
for _, bad in ipairs({ 'T[1]={os.exit(1)}', 'T[1]={("x"):rep(9)}', 'T[1]={"a".."b"}', 'T[1]={while true do end}',
                       'T[1]={m="campaign","s","x","s","\\n"}', 'T[1]={function() end}' }) do
    check(not save.safe_line(bad) and save.load("F=2\nW=1\nS=1\n" .. bad .. "\n") == nil,
        "a line that isn't plain data is refused: " .. bad)
end

-- A save made at "Run game night" keeps the board, and loading it plays the same night from its
-- start, then carries on as if it had never stopped.
for _, style in ipairs(STYLES) do
    for stop = 1, 3 do
        local seed = 9300 + stop * 17
        local a = new_campaign(seed)
        local rng = rng_mod.new(seed + 5)
        for _ = 1, stop - 1 do
            play_week(a, style, rng)
        end
        local prep = prep_week(a, style, rng)
        a.at_night = true
        local src = save.dump(a)
        a.at_night = nil
        local b, err = save.load(src)
        local b2 = save.load(src)
        check(b ~= nil and b.at_night and b.prep ~= nil and getmetatable(b.prep) == getmetatable(prep),
            string.format("%s: a save at game night %d loads with its board (%s)", style, stop, tostring(err)))
        check(save.peek(src).at_night, style .. ": the header says it was saved at game night")
        if b and b2 then
            adventure.enter(b)
            adventure.enter(b2)
            check(save.dump(b) == src, style .. ": saving the loaded game-night copy gives the same file")
            local function board(p)
                local ids = {}
                for id in pairs(p.museum.prepped) do
                    ids[#ids + 1] = id
                end
                table.sort(ids)
                return table.concat(ids, ",") .. ":" .. tostring(p:spent())
            end
            check(board(prep) == board(b.prep), style .. ": the board comes back as built")
            local rs = rng.s
            local rng_b = copy_rng({ s = rs })
            local want, got = play_night(b, style, rng_b), play_night(b2, style, copy_rng({ s = rs }))
            check(want == got, string.format("%s: game night %d plays the same every time it's loaded at Run game night (%s)",
                style, stop, want == got and "" or first_diff(want, got)))
            check(not b.at_night, style .. ": the night clears the game-night flag")
            check(not string.find(save.dump(b), "\nN=1"), style .. ": the save after the night is an ordinary between-weeks save")
            local ok, err2 = pcall(play_night, a, style, rng)
            check(ok, style .. ": the original plays its night too (" .. tostring(err2) .. ")")
            if not adventure.over(b) then
                local ok2, err3 = pcall(play_week, b, style, rng_b)
                check(ok2, style .. ": and the week after (" .. tostring(err3) .. ")")
            end
        end
    end
end

-- Prep survives a quit (A11): a save made mid-prep keeps the half-built board and the week, and
-- carrying on from it plays exactly as if nobody had quit.
for _, style in ipairs(STYLES) do
    local seed = 9700 + #style
    local a = new_campaign(seed)
    local rng = rng_mod.new(seed + 5)
    play_week(a, style, rng)
    local prep = a:start_week()
    -- Half the board: the first room ahead prepped, then quit.
    local first = prep.museum.ahead[1]
    if first and museum_week.can_prep(prep, first) then
        museum_week.set_prepped(prep, first, true)
    end
    a.at_prep = true
    local src = save.dump(a)
    local b, err = save.load(src)
    local b2 = save.load(src)
    check(save.peek(src).at_prep and not save.peek(src).at_night, style .. ": the header says it was saved mid-prep")
    check(b ~= nil and b.at_prep and b.prep ~= nil and b.week == a.week,
        string.format("%s: a mid-prep save loads with its board and its week (%s)", style, tostring(err)))
    if b and b2 then
        adventure.enter(b)
        adventure.enter(b2)
        check(not first or (b.prep.museum.prepped[first] and true) == (prep.museum.prepped[first] and true),
            style .. ": the room prepped before quitting is still prepped")
        check(b.prep:left() == prep:left(), style .. ": the hours spent before quitting stay spent")
        check(save.dump(b) == src, style .. ": saving the loaded mid-prep copy gives the same file")
        local want, got = play_night(b, style, copy_rng(rng)), play_night(b2, style, copy_rng(rng))
        check(want == got, string.format("%s: the night after a mid-prep quit plays the same every time it's loaded (%s)", style,
            want == got and "" or first_diff(want, got)))
        check(not b.at_prep and not string.find(save.dump(b), "\nP=1"), style .. ": the night clears the mid-prep flag")
    end
end

-- A game-night save whose board is missing falls back to prep instead of a broken night.
do
    local c = new_campaign(41)
    c:start_week()
    c.at_night = true
    local saved_prep = c.prep
    c.prep = nil
    local b = save.load(save.dump(c))
    check(b and not b.at_night, "a game-night save without its board loads as a between-weeks save")
    c.prep = saved_prep
end
local head = save.peek(save.dump(new_campaign(5)))
check(head and head.week == 0 and head.seed == 5, "the header says the week and seed")

print(string.format("%d of %d checks pass; biggest save %.0f KB", checks - failures, checks, biggest / 1024))
os.exit(failures == 0 and 0 or 1)
