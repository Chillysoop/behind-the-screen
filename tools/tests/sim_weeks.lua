-- Headless checks for the M1 model. Run from the project root:
--   texlua tools/tests/sim_weeks.lua      (or any Lua 5.1+/LuaJIT)
-- Simulates many weeks with three DM styles and checks the numbers behave.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local score = require "game.model.score"
local telemetry = require "game.model.telemetry"
local util = require "game.model.util"

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        if failures <= 25 then
            print("FAIL: " .. msg)
        end
    end
end

local function text_ok(s, where)
    check(type(s) == "string", where .. ": not a string")
    if type(s) ~= "string" then return end
    check(not string.find(s, "{[%w_]+}"), where .. ": unfilled placeholder in '" .. s .. "'")
    check(not string.find(s, "[\128-\255]"), where .. ": non-ASCII in '" .. s .. "'")
    check(not string.find(s, "nil"), where .. ": 'nil' in '" .. s .. "'")
end

local function check_player(p, where)
    for _, k in ipairs(score.METERS) do
        local v = p.m[k]
        check(v == v and v >= 0 and v <= 100, where .. " meter " .. k .. "=" .. tostring(v))
    end
    for _, k in ipairs(score.LONG) do
        local v = p[k]
        check(v == v and v >= 0 and v <= 100, where .. " long " .. k .. "=" .. tostring(v))
    end
    local f = score.fun(p)
    check(f == f and f >= 0 and f <= 100, where .. " fun=" .. tostring(f))
end

-- DM styles ----------------------------------------------------------------

local function fill_random(prep, rng)
    for i, s in ipairs(prep.scenes) do
        prep:set_type(i, rng:pick(content.scenes.order))
    end
    local tries = 0
    while prep:left() > 0 and tries < 60 do
        tries = tries + 1
        local i = rng:int(1, 3)
        local kind = rng:pick(content.kinds)
        local c = rng:pick(prep.hand[kind])
        if c and not prep:placed_at(c.id) and not prep.scenes[i].slots[kind] then
            prep:place(i, c.id)
        end
    end
end

-- A thoughtful DM: tries every type combo, keeps the best forecast, then
-- fills slots greedily by forecast.
local function fill_greedy(prep, rng, campaign)
    for _, p in ipairs(campaign:present()) do
        if p.mood ~= "fine" and prep:can_talk(p.key) and not p.mood_known then
            prep:talk(p.key)
            break
        end
    end
    local function avg()
        local f = prep:forecast()
        local t, n = 0, 0
        for _, v in pairs(f) do
            t, n = t + v, n + 1
        end
        -- care about the least happy player too
        local lo = 100
        for _, v in pairs(f) do
            lo = math.min(lo, v)
        end
        return (n > 0 and t / n or 0) * 0.6 + lo * 0.4
    end
    local best, best_types = -1, nil
    for _, a in ipairs(content.scenes.order) do
        for _, b in ipairs(content.scenes.order) do
            for _, c in ipairs(content.scenes.order) do
                prep:set_type(1, a); prep:set_type(2, b); prep:set_type(3, c)
                local v = avg()
                if v > best then
                    best, best_types = v, { a, b, c }
                end
            end
        end
    end
    for i = 1, 3 do prep:set_type(i, best_types[i]) end
    local improved = true
    while improved and prep:left() > 0 do
        improved = false
        local base = avg()
        local best_gain, best_move = 0, nil
        for i = 1, 3 do
            for _, kind in ipairs(content.kinds) do
                if not prep.scenes[i].slots[kind] then
                    for _, c in ipairs(prep.hand[kind]) do
                        if not prep:placed_at(c.id) and prep:can_place(i, c.id) then
                            prep:place(i, c.id)
                            local gain = avg() - base
                            prep:clear(i, kind)
                            if gain > best_gain then
                                best_gain, best_move = gain, { i, c.id }
                            end
                        end
                    end
                end
            end
        end
        if best_move then
            prep:place(best_move[1], best_move[2])
            improved = true
        end
    end
end

local function fill_bad(prep)
    for i = 1, 3 do prep:set_type(i, "combat") end
    for i = 1, 3 do
        for _, c in ipairs(prep.hand.cast) do
            if not prep:placed_at(c.id) and prep:can_place(i, c.id) then
                prep:place(i, c.id)
                break
            end
        end
    end
end

-- Answer the night's questions according to style.
local function play_night(night, rng, style, stats)
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 3000 do
        guard = guard + 1
        local answer
        if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc" or ev.kind == "check" then
            text_ok(ev.text, "event " .. ev.kind)
        elseif ev.kind == "scene" or (ev.kind == "stage" and ev.title ~= nil) then
            text_ok(ev.title, "scene title")
        elseif ev.kind == "improv" then
            text_ok(ev.prompt, "improv prompt")
            check(#ev.cards >= 3 and #ev.cards <= 5, "improv hand has 3 to 5 cards (" .. #ev.cards .. " for " .. tostring(ev.slot or (ev.drift and "drift")) .. ")")
            for _, c in ipairs(ev.cards) do text_ok(c.name, "improv card") end
            if style == "greedy" then
                answer = {}
                for i, c in ipairs(ev.cards) do
                    if c.fit == "great" and #answer < 2 then table.insert(answer, i) end
                end
                if #answer == 0 then answer = { 1 } end
            else
                answer = { rng:int(1, #ev.cards) }
            end
            stats.improv = stats.improv + 1
        elseif ev.kind == "ruling" then
            text_ok(ev.prompt, "ruling prompt")
            for _, o in ipairs(ev.options) do text_ok(o.label, "ruling option") end
            answer = rng:int(1, #ev.options)
            if ev.cook then
                text_ok(ev.cook.label, "cook option")
                local cook = (style == "bad") and true or (style == "random" and rng:chance(0.3))
                if cook then
                    answer = "cook"
                    stats.cooks = stats.cooks + 1
                end
            end
        elseif ev.kind == "turn" then
            check(#ev.steps > 0, "turn has steps")
        elseif ev.kind == "decision" then
            text_ok(ev.card.text, "decision " .. ev.card.id)
            text_ok(ev.card.title, "decision title")
            for _, o in ipairs(ev.card.options) do text_ok(o.label, "option") end
            answer = rng:int(1, #ev.card.options)
            stats.decisions = stats.decisions + 1
        elseif ev.kind == "roll_where" then
            text_ok(ev.text, "roll_where")
            answer = (style == "bad") and "hidden" or ((style == "random" and rng:chance(0.5)) and "hidden" or "open")
        elseif ev.kind == "roll" then
            answer = rng:d20()
        end
        ev = night:advance(answer)
        for _, p in ipairs(night.players) do check_player(p, "mid-night " .. p.key) end
    end
    check(guard < 3000, "night ended")
end

local function run(style, weeks, seed)
    local c = campaign_mod.new(seed)
    local rng = require("game.model.rng").new(seed + 999)
    local stats = { improv = 0, decisions = 0, cooks = 0, callouts = 0, absences = 0, fun = {}, tiers = {} }
    for w = 1, weeks do
        local prep = c:start_week()
        for _, m in ipairs(c.chat) do text_ok(m.text, "chat " .. m.who) end
        for _, p in ipairs(c.players) do if not p.present then stats.absences = stats.absences + 1 end end
        if style == "greedy" then fill_greedy(prep, rng, c)
        elseif style == "bad" then fill_bad(prep)
        else fill_random(prep, rng) end
        check(prep:ready(), "prep ready")
        check(prep:spent() <= prep.budget, "budget respected")
        local pv = prep:pacing_now()
        for _, wtext in ipairs(pv.warnings) do text_ok(wtext, "warning") end
        local night = c:start_night()
        play_night(night, rng, style, stats)
        local rep = c:finish_night()
        stats.callouts = stats.callouts + rep.callouts
        for _, row in ipairs(rep.players) do
            text_ok(row.verdict, "verdict")
            if row.fun then
                text_ok(row.quote, "quote")
                stats.fun[row.key] = stats.fun[row.key] or {}
                table.insert(stats.fun[row.key], row.fun)
                stats.tiers[row.tier] = (stats.tiers[row.tier] or 0) + 1
            end
        end
        for _, m in ipairs(rep.moments) do text_ok(m, "moment") end
        local line = telemetry.week_record(c, 120)
        check(string.sub(line, 1, 1) == "{" and string.sub(line, -1) == "}", "telemetry json")
        for _, p in ipairs(c.players) do check_player(p, "after week " .. p.key) end
    end
    return c, stats
end

local function mean(t)
    local s = 0
    for _, v in ipairs(t) do s = s + v end
    return #t > 0 and s / #t or 0
end

local summary = {}
for _, style in ipairs({ "greedy", "random", "bad" }) do
    local agg = { fun = {}, commit = {}, cooks = 0, callouts = 0, absences = 0, decisions = 0, improv = 0, tiers = {} }
    for seed = 1, 30 do
        local c, st = run(style, 8, seed * 7919)
        for k, list in pairs(st.fun) do
            agg.fun[k] = agg.fun[k] or {}
            for _, v in ipairs(list) do table.insert(agg.fun[k], v) end
        end
        for _, p in ipairs(c.players) do
            agg.commit[p.key] = agg.commit[p.key] or {}
            table.insert(agg.commit[p.key], p.commitment)
        end
        agg.cooks = agg.cooks + st.cooks
        agg.callouts = agg.callouts + st.callouts
        agg.absences = agg.absences + st.absences
        agg.decisions = agg.decisions + st.decisions
        agg.improv = agg.improv + st.improv
        for t, n in pairs(st.tiers) do agg.tiers[t] = (agg.tiers[t] or 0) + n end
    end
    local line = string.format("%-7s", style)
    local all = {}
    for _, key in ipairs(content.players.order) do
        line = line .. string.format("  %s fun %3d commit %3d", key, math.floor(mean(agg.fun[key] or {}) + 0.5),
            math.floor(mean(agg.commit[key]) + 0.5))
        for _, v in ipairs(agg.fun[key] or {}) do table.insert(all, v) end
    end
    print(line)
    print(string.format("        avg fun %d | per 30x8 weeks: decisions %d improv %d cooks %d callouts %d absences %d",
        math.floor(mean(all) + 0.5), agg.decisions, agg.improv, agg.cooks, agg.callouts, agg.absences))
    local tl = "        tiers:"
    for _, t in ipairs({ "loved", "fun", "fine", "bored", "out" }) do
        tl = tl .. string.format(" %s %d", t, agg.tiers[t] or 0)
    end
    print(tl)
    summary[style] = mean(all)
end

check(summary.greedy > summary.random, "thoughtful prep beats random prep")
check(summary.random > summary.bad, "random prep beats three combats with cooked dice")

-- Determinism: same seed, same story.
local function trace(seed)
    local c = campaign_mod.new(seed)
    local rng = require("game.model.rng").new(5)
    local prep = c:start_week()
    fill_random(prep, rng)
    local night = c:start_night()
    local out = {}
    local ev = night:advance()
    while ev.kind ~= "done" do
        table.insert(out, ev.kind .. (ev.text or ""))
        local a
        if ev.kind == "improv" then a = 1 elseif ev.kind == "decision" then a = 2
        elseif ev.kind == "roll_where" then a = "open" elseif ev.kind == "roll" then a = 11 end
        ev = night:advance(a)
    end
    return table.concat(out, "\n")
end
check(trace(42) == trace(42), "same seed replays the same night")

print(failures == 0 and "ALL CHECKS PASSED" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
