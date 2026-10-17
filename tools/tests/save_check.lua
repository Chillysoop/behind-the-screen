-- Save and resume (M7): a campaign saved between sessions and loaded again must carry on
-- exactly as if it had never stopped. Plays slices with the simulated DMs, saves after
-- Session Zero and after each session, loads the save, plays both copies on with the same
-- choices, and compares what the game would log, week by week. It also loads each save in a
-- fresh Lua process (fresh game data, so no table survives by accident) and plays on there.
-- Run from the project root:   texlua tools/tests/save_check.lua
-- Exit code 1 on any difference.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local telemetry = require "game.model.telemetry"
local save = require "game.model.save"
local bots = require "slice_bots"

local SCRATCH = os.getenv("TMPDIR") or "/tmp"

-- Play one week; returns the lines the game would log for it.
local function play_week(c, dm, rng)
    local prep = c:start_week()
    bots.prep(dm, c, prep, rng)
    local night = c:start_night()
    bots.play_night(night, rng, dm)
    local rep = c:finish_night()
    local lines = { telemetry.week_record(c, 300, night.clock) }
    for i, m in ipairs(c.chat or {}) do
        lines[#lines + 1] = "chat " .. i .. " " .. tostring(m.who) .. ": " .. tostring(m.text)
    end
    if dm.level and rep.level.ready then
        c:level_up()
    end
    lines[#lines + 1] = "level " .. tostring(c.level)
    return table.concat(lines, "\n")
end

local function play_rest(c, dm, rng, from)
    local out = {}
    for w = from, content.arc.SESSIONS + 1 do   -- one week past the slice, too
        out[#out + 1] = play_week(c, dm, rng)
    end
    return out
end

-- Child mode: load a save from a file and play on (a fresh process, so a fresh content table).
if arg[1] == "child" then
    local f = assert(io.open(arg[2], "rb"))
    local src = f:read("*a")
    f:close()
    local c = assert(save.load(src))
    io.write(save.dump(c) == src and "same\n" or "different\n")
    local dm = bots.DMS[arg[3]]
    local rng = rng_mod.new(1)
    rng.s = tonumber(arg[4])
    play_rest(c, dm, rng, tonumber(arg[5]))
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

local biggest = 0
for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, 3 do
        local seed = 9100 + run * 31
        for stop = 0, content.arc.SESSIONS do
            local a = campaign_mod.new(seed)
            local rng = rng_mod.new(seed + 3)
            a:session_zero(dm.s0)
            for w = 1, stop do
                play_week(a, dm, rng)
            end
            local src = save.dump(a)
            biggest = math.max(biggest, #src)
            local b, err = save.load(src)
            check(b ~= nil, string.format("%s run %d: load after session %d (%s)", dm_key, run, stop, tostring(err)))
            if b then
                check(save.dump(b) == src, string.format("%s run %d: saving the loaded copy gives the same file", dm_key, run))
                check(getmetatable(b) == campaign_mod and getmetatable(b.rng) == rng_mod and b.rng ~= a.rng,
                      dm_key .. ": classes come back, nothing shared with the original")
                local path = SCRATCH .. "/bts_save_check.lua"
                local f = assert(io.open(path, "wb"))
                f:write(src)
                f:close()
                local rs = rng.s
                local rng_b = rng_mod.new(1)
                rng_b.s = rs
                local want = play_rest(a, dm, rng, stop + 1)
                local got = play_rest(b, dm, rng_b, stop + 1)
                for i = 1, #want do
                    local same = want[i] == got[i]
                    check(same, string.format("%s run %d, saved after session %d: week %d plays the same after loading (%s)",
                        dm_key, run, stop, stop + i, same and "" or first_diff(want[i], got[i])))
                end
                local exe = arg[-1] or "texlua"
                local p = io.popen(string.format('%s tools/tests/save_check.lua child "%s" %s %d %d', exe, path, dm_key, rs, stop + 1))
                local child = p:read("*a")
                p:close()
                -- texlua (Lua 5.3) seeds its string hashing per process, so pairs() order and with it
                -- the rest of the campaign differ from process to process even without a save. So a
                -- fresh process only has to rebuild the exact same campaign and play on without errors.
                check(child == "same\nplayed on\n", string.format("%s run %d, saved after session %d: a fresh process loads the same campaign and plays on (%s)",
                    dm_key, run, stop, child))
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
-- New books (A13): the shelf, what was pulled in, the items the party carries and a published
-- adventure on the board all come back after loading.
do
    local books = require "game.model.books"
    local items = require "game.model.items"
    local c = campaign_mod.new(4242)
    local rng = rng_mod.new(77)
    c:session_zero(bots.DMS.plain.s0)
    for _ = 1, 3 do
        play_week(c, bots.DMS.plain, rng)
    end
    local prep = c:start_week()
    check(books.get(c).arrived.vale_gazetteer == 4, "the gazetteer comes out in week 4")
    prep:inspire("supplement")
    local r = prep.reading
    check(r ~= nil and r.book == "vale_gazetteer", "the supplement evening opens the newest book")
    local mod_entry, place_entry
    for _, e in ipairs(r and books.book(r.book).entries or {}) do
        if e.kind == "module" and not mod_entry then mod_entry = e end
        if e.kind == "place" and not place_entry then place_entry = e end
    end
    books.pull(c, prep, r, mod_entry.id)
    books.pull(c, prep, r, place_entry.id)
    items.earn(c, "cloak_of_protection")
    check(prep:place_module(3, mod_entry.module), "a pulled adventure goes on the board")
    c.at_night = true
    local src = save.dump(c)
    local b, err = save.load(src)
    check(b ~= nil, "a campaign with books loads (" .. tostring(err) .. ")")
    if b then
        check(save.dump(b) == src, "saving the loaded book campaign gives the same file")
        check(b.books.pulled[mod_entry.id] and b.books.pulled[place_entry.id] and b.books.modules[mod_entry.module],
            "what was pulled in comes back")
        check(b.prep.reading and b.prep.reading.left == r.left, "the open reading comes back with its pulls left")
        check(b.prep.scenes[3].module and b.prep.scenes[3].module.id == mod_entry.module, "the adventure is still on scene 3")
        local cloak
        for _, it in ipairs(items.list(b)) do
            if it.id == "cloak_of_protection" then cloak = it end
        end
        check(#items.list(b) == #items.list(c) and cloak ~= nil and cloak.holder ~= nil, "the party still carries its magic item")
        check(require("game.model.deck").entry(b, place_entry.card.id) ~= nil, "the pulled place is still in the deck")
    end
end

-- Cards a campaign made for itself (a callback from inspiration) come back after loading.
do
    local seeds_mod = require "game.model.seeds"
    local c = campaign_mod.new(77)
    c:session_zero()
    table.insert(c.canon, "the toll-taker owes Pip a favour")
    local prep = c:start_week()
    prep.extra = prep.extra - 5
    local drawn = seeds_mod.inspire(c, prep, "canon")
    local card = c.registered and c.registered[1]
    check(card ~= nil and card.runtime, "a canon evening makes a campaign card")
    if card then
        local id = card.id
        c.improv_deck = c.improv_deck or {}
        table.insert(c.improv_deck, id)
        c.last_used = { id }
        content.components[id] = nil   -- as in a fresh process
        local b, err = save.load(save.dump(c))
        check(b ~= nil, "a save with a campaign card loads (" .. tostring(err) .. ")")
        check(b and content.components[id] ~= nil and content.components[id] == b.registered[1],
            "the campaign card is back in the game data after loading")
    end
end
-- The fix pass: a save made at "Run game night" keeps the board, and loading it plays the same
-- night from its start, then carries on as if it had never stopped.
for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for stop = 1, content.arc.SESSIONS do
        local seed = 9300 + stop * 17
        local a = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 5)
        a:session_zero(dm.s0)
        for w = 1, stop - 1 do
            play_week(a, dm, rng)
        end
        local prep = a:start_week()
        bots.prep(dm, a, prep, rng)
        a.at_night = true
        local src = save.dump(a)
        a.at_night = nil
        local b, err = save.load(src)
        check(b ~= nil and b.at_night and b.prep ~= nil and getmetatable(b.prep) == getmetatable(prep),
            string.format("%s: a save at game night %d loads with its board (%s)", dm_key, stop, tostring(err)))
        check(save.peek(src).at_night, dm_key .. ": the header says it was saved at game night")
        if b then
            check(save.dump(b) == src, dm_key .. ": saving the loaded game-night copy gives the same file")
            local types_a, types_b = {}, {}
            for i, sc in ipairs(prep.scenes) do
                types_a[i] = tostring(sc.type) .. ":" .. tostring(prep:spent())
                types_b[i] = tostring(b.prep.scenes[i].type) .. ":" .. tostring(b.prep:spent())
            end
            check(table.concat(types_a, ",") == table.concat(types_b, ","), dm_key .. ": the board comes back as built")
            local rs = rng.s
            local rng_b = rng_mod.new(1)
            rng_b.s = rs
            local function night_of(c, r)
                local night = c:start_night()
                bots.play_night(night, r, dm)
                local rep = c:finish_night()
                local out = telemetry.week_record(c, 300, night.clock)
                if dm.level and rep.level.ready then
                    c:level_up()
                end
                return out
            end
            local want = night_of(a, rng)
            local got = night_of(b, rng_b)
            check(want == got, string.format("%s: game night %d plays the same after loading at Run game night (%s)",
                dm_key, stop, want == got and "" or first_diff(want, got)))
            check(not b.at_night, dm_key .. ": the night clears the game-night flag")
            local after = save.dump(b)
            check(not string.find(after, "\nN=1"), dm_key .. ": the save after the night is an ordinary between-weeks save")
            local wa, wb = play_week(a, dm, rng), play_week(b, dm, rng_b)
            check(wa == wb, dm_key .. ": the week after plays the same too")
        end
    end
end
-- Prep survives a quit (A11): a save made mid-prep keeps the half-built board and the week, and
-- carrying on from it plays exactly as if nobody had quit.
for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    local seed = 9700 + #dm_key
    local a = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 5)
    a:session_zero(dm.s0)
    play_week(a, dm, rng)
    local prep = a:start_week()
    -- Half the board: scene 1's type and a card, then quit.
    prep:set_type(1, prep.scenes[1].type or "social")
    local first = nil
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(prep.hand[kind] or {}) do
            if not first and prep:place(1, c.id) then
                first = c.id
            end
        end
    end
    a.at_prep = true
    local src = save.dump(a)
    local b, err = save.load(src)
    check(save.peek(src).at_prep and not save.peek(src).at_night, dm_key .. ": the header says it was saved mid-prep")
    check(b ~= nil and b.at_prep and b.prep ~= nil and b.week == a.week,
        string.format("%s: a mid-prep save loads with its board and its week (%s)", dm_key, tostring(err)))
    if b then
        check(not first or b.prep:placed_at(first) == 1, dm_key .. ": the card placed before quitting is still on scene 1")
        check(b.prep:left() == prep:left(), dm_key .. ": the hours spent before quitting stay spent")
        check(save.dump(b) == src, dm_key .. ": saving the loaded mid-prep copy gives the same file")
        local rng_b = rng_mod.new(1)
        rng_b.s = rng.s
        bots.prep(dm, a, a.prep, rng)
        bots.prep(dm, b, b.prep, rng_b)
        local function night_of(c, r)
            local night = c:start_night()
            bots.play_night(night, r, dm)
            c:finish_night()
            return telemetry.week_record(c, 300, night.clock)
        end
        local want, got = night_of(a, rng), night_of(b, rng_b)
        check(want == got, string.format("%s: the night after a mid-prep quit plays the same (%s)", dm_key,
            want == got and "" or first_diff(want, got)))
        check(not b.at_prep and not string.find(save.dump(b), "\nP=1"), dm_key .. ": the night clears the mid-prep flag")
    end
end
-- A game-night save whose board is missing falls back to prep instead of a broken night.
do
    local c = campaign_mod.new(41)
    c:session_zero()
    c:start_week()
    c.at_night = true
    local src = string.gsub(save.dump(c), "\nN=1", "\nN=1")
    local saved_prep = c.prep
    c.prep = nil
    local b = save.load(save.dump(c))
    check(b and not b.at_night, "a game-night save without its board loads as a between-weeks save")
    c.prep = saved_prep
end
-- A save from an older build (October 16, mid-prep in week 2) still plays on: its night, and the
-- next week's start (the group chat's talker from that build had no "openers": d8bd251 crashed
-- there).
do
    local f = io.open("tools/tests/fixtures/save_oct16_week2.txt")
    local src = f and f:read("a")
    if f then
        f:close()
    end
    local old = src and save.load(src)
    local ok, err = false, "no fixture"
    if old then
        local rng = rng_mod.new(9)
        ok, err = pcall(function()
            bots.prep(bots.DMS.careful, old, old.prep, rng)
            local night = old:start_night()
            bots.play_night(night, rng, bots.DMS.careful)
            old:finish_night()
            old:start_week()
        end)
    end
    check(ok, "a save from an older build plays its night and starts the next week (" .. tostring(err) .. ")")
end
local head = save.peek(save.dump(campaign_mod.new(5)))
check(head and head.week == 0 and head.seed == 5, "the header says the week and seed")

print(string.format("%d of %d checks pass; biggest save %.0f KB", checks - failures, checks, biggest / 1024))
os.exit(failures == 0 and 0 or 1)
