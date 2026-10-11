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
check(save.load('F=1\nW=1\nS=1\nT[1]={"s","x","c",{"no_such_table"}}\n') == nil, "a save pointing at missing game data is refused")
check(save.load('F=1\nW=1\nS=1\nT[1]={"s","x","t",7}\n') == nil, "a save with a broken link is refused")
check(save.load('F=1\nW=1\nS=1\nos.exit(1)\nT[1]={m="campaign"}\n') ~= nil, "lines that aren't table statements are ignored")
check(save.load('F=1\nW=1\nS=1\nT[1]={m="campaign"}\n') ~= nil, "a minimal campaign line loads")
check(save.load('F=1\nW=1\nS=1\nT[1]={}\n') == nil, "a save without a campaign is refused")
for _, bad in ipairs({ 'T[1]={os.exit(1)}', 'T[1]={("x"):rep(9)}', 'T[1]={"a".."b"}', 'T[1]={while true do end}',
                       'T[1]={m="campaign","s","x","s","\\n"}', 'T[1]={function() end}' }) do
    check(not save.safe_line(bad) and save.load("F=1\nW=1\nS=1\n" .. bad .. "\n") == nil,
        "a line that isn't plain data is refused: " .. bad)
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
local head = save.peek(save.dump(campaign_mod.new(5)))
check(head and head.week == 0 and head.seed == 5, "the header says the week and seed")

print(string.format("%d of %d checks pass; biggest save %.0f KB", checks - failures, checks, biggest / 1024))
os.exit(failures == 0 and 0 or 1)
