-- M4 game night check: plays hundreds of whole game nights headlessly (real prep
-- from the M2 DM styles, a simulated DM answering every card) and checks the gate's
-- numbers: about 15 minutes a night at normal speed, 8 to 15 decisions, all six
-- decision types turning up, and fights that end. Run from the project root:
--
--   lua tools/sim/nights.lua [campaigns per style] [weeks] [seed]

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local styles = require "tools.sim.dm_styles"
local pacing = require "game.model.pacing"

local CAMPAIGNS = tonumber(arg and arg[1]) or 8
local WEEKS = tonumber(arg and arg[2]) or 6
local SEED = tonumber(arg and arg[3]) or 4040
local STYLES = { "balanced", "story_threads", "combat_only", "random", "no_prep", "cooker" }
local QUIET = os.getenv("NIGHTS_QUIET")

local failures = {}
local function fail(msg)
    if #failures < 30 then
        table.insert(failures, msg)
    end
end

local function text_ok(t, where)
    if type(t) ~= "string" or t == "" then
        fail("empty text at " .. where)
    elseif string.find(t, "{[%w_]+}") then
        fail("unfilled placeholder at " .. where .. ": " .. t)
    end
end

-- A DM who reads the card and picks something reasonable, with a little randomness.
local function answer(ev, rng, style)
    local k = ev.kind
    if k == "decision" then
        text_ok(ev.card.title, "card title " .. ev.card.id)
        text_ok(ev.card.text, "card text " .. ev.card.id)
        for _, o in ipairs(ev.card.options) do text_ok(o.label, "option " .. ev.card.id) end
        return rng:int(1, #ev.card.options)
    elseif k == "improv" then
        for _, c in ipairs(ev.cards) do text_ok(c.name, "improv card") end
        local picks = {}
        for i, c in ipairs(ev.cards) do
            if c.fit == "great" and #picks < 2 then table.insert(picks, i) end
        end
        if #picks == 0 or rng:chance(0.3) then
            table.insert(picks, rng:int(1, #ev.cards))
        end
        return picks
    elseif k == "roll_where" then
        return style.roll_where(ev, rng)
    elseif k == "roll" then
        return rng:d20()
    elseif k == "ruling" then
        text_ok(ev.prompt, "ruling prompt")
        if ev.cook and style.cook(ev, rng) then
            return "cook"
        end
        return rng:int(1, #ev.options)
    end
    return nil
end

local nights = {}
CARD_IDS = {}
local t0 = os.clock()
for si, skey in ipairs(STYLES) do
    local style = styles[skey]
    for ci = 1, CAMPAIGNS do
        local seed = SEED + si * 1000 + ci
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 77)
        if skey == "cooker" then
            c.dm_rolls = "hidden"
        elseif rng:chance(0.5) then
            c.dm_rolls = "open"
        end
        for w = 1, WEEKS do
            local prep = c:start_week()
            style.prep(prep, rng, c)
            local night = c:start_night()
            local rec = { style = skey, week = w, types = {}, kinds = {}, fights = 0, rounds = 0, downs = 0, turns = 0,
                          says = 0, combat_time = 0, longest_wait = 0 }
            local since_input = 0
            local stretch = {}
            local ok, err = pcall(function()
                local ev = night:advance()
                local guard = 0
                while ev.kind ~= "done" and guard < 3000 do
                    guard = guard + 1
                    rec.kinds[ev.kind] = (rec.kinds[ev.kind] or 0) + 1
                    rec.time = rec.time or {}
                    rec.time[ev.kind] = (rec.time[ev.kind] or 0) + (ev.t or 0)
                    if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc" then
                        text_ok(ev.text, ev.kind)
                    elseif ev.kind == "scene" or (ev.kind == "stage" and ev.title ~= nil) then
                        text_ok(ev.title, "scene title")
                    elseif ev.kind == "decision" then
                        rec.types[ev.card.type] = (rec.types[ev.card.type] or 0) + 1
                        CARD_IDS[ev.card.id] = (CARD_IDS[ev.card.id] or 0) + 1
                        rec.card_list = rec.card_list or {}
                        table.insert(rec.card_list, ev.card.id)
                    elseif ev.kind == "battle" and ev.phase == "end" then
                        rec.fights = rec.fights + 1
                        rec.rounds = rec.rounds + (ev.rounds or 0)
                    elseif ev.kind == "turn" then
                        rec.turns = rec.turns + 1
                        rec.combat_time = rec.combat_time + ev.t
                        for _, s in ipairs(ev.steps) do
                            if s.kind == "down" then rec.downs = rec.downs + 1 end
                        end
                    end
                    if ev.kind == "say" then rec.says = rec.says + 1 end
                    if ev.kind == "scene" then
                        rec.scene_starts = rec.scene_starts or {}
                        table.insert(rec.scene_starts, { night.clock - ev.t, ev.type })
                    end
                    if pacing.DECISION_KINDS[ev.kind] or ev.kind == "roll_where" then
                        since_input = 0
                        stretch = {}
                    else
                        since_input = since_input + (ev.t or 0)
                        table.insert(stretch, ev)
                        if since_input > rec.longest_wait then
                            rec.stretch = { unpack(stretch) }
                            rec.longest_wait = since_input
                            rec.longest_where = (night.battle and "fight" or "talk") .. ":" .. tostring(night.scene and night.scene.type)
                                .. (night.scene and (" s" .. night.scene.index) or " intro")
                        end
                    end
                    ev = night:advance(answer(ev, rng, style))
                end
                if guard >= 3000 then
                    fail("night never ended: " .. skey .. " week " .. w)
                end
            end)
            if not ok then
                fail("error " .. skey .. " seed " .. seed .. " week " .. w .. ": " .. tostring(err))
            end
            rec.minutes = night.clock / 60
            rec.scene_len = {}
            for i, st in ipairs(rec.scene_starts or {}) do
                local nxt = (rec.scene_starts[i + 1] or { night.clock })[1]
                table.insert(rec.scene_len, { st[2], nxt - st[1] })
            end
            rec.decisions = night:decision_count()
            rec.cards = night.counts.decision
            rec.improv = night.counts.improv
            rec.rulings = night.counts.ruling
            rec.callouts = night.callouts
            rec.ended_early = night.end_early
            -- Traps and hazards (A10).
            rec.traps, rec.hazards = 0, 0
            for _, sc in ipairs(night.scenes or {}) do
                if sc.trap_id and sc.had_roll then rec.traps = rec.traps + 1 end
                if sc.hazard and sc.result then rec.hazards = rec.hazards + 1 end
            end
            table.insert(nights, rec)
            c:finish_night()
        end
    end
end

-- Stats ----------------------------------------------------------------------------------------

local function sorted(field)
    local v = {}
    for _, r in ipairs(nights) do table.insert(v, r[field]) end
    table.sort(v)
    return v
end
local function pct(v, q)
    return v[math.max(1, math.min(#v, math.floor(q * #v + 0.5)))]
end
local function share(fn)
    local n = 0
    for _, r in ipairs(nights) do if fn(r) then n = n + 1 end end
    return n / #nights
end

local mins = sorted("minutes")
local decs = sorted("decisions")
print(string.format("%d nights in %.0fs", #nights, os.clock() - t0))
print(string.format("minutes: p10 %.1f  median %.1f  p90 %.1f", pct(mins, 0.1), pct(mins, 0.5), pct(mins, 0.9)))
print(string.format("decisions: p10 %d  median %d  p90 %d", pct(decs, 0.1), pct(decs, 0.5), pct(decs, 0.9)))
local types = { "story", "combat", "rules", "screen", "pacing", "table" }
local type_line = {}
for _, t in ipairs(types) do
    table.insert(type_line, string.format("%s %.0f%%", t, 100 * share(function(r) return (r.types[t] or 0) > 0 end)))
end
print("nights with each card type: " .. table.concat(type_line, ", "))
local fights, rounds, downs = 0, 0, 0
for _, r in ipairs(nights) do fights, rounds, downs = fights + r.fights, rounds + r.rounds, downs + r.downs end
print(string.format("fights per night %.2f, rounds per fight %.1f, PC drops per fight %.2f", fights / #nights,
    rounds / math.max(1, fights), downs / math.max(1, fights)))
local tsum, ksum = {}, {}
for _, r in ipairs(nights) do
    for k, v in pairs(r.time or {}) do tsum[k] = (tsum[k] or 0) + v end
    for k, v in pairs(r.kinds or {}) do ksum[k] = (ksum[k] or 0) + v end
end
local tk = {}
for k in pairs(tsum) do table.insert(tk, k) end
table.sort(tk, function(a, b) return tsum[a] > tsum[b] end)
local parts = {}
for _, k in ipairs(tk) do
    table.insert(parts, string.format("%s %.0fs/%.1f", k, tsum[k] / #nights, ksum[k] / #nights))
end
print("time per night by beat (seconds/count): " .. table.concat(parts, ", "))
local by_type, n_type = {}, {}
for _, r in ipairs(nights) do
    for _, sl in ipairs(r.scene_len or {}) do
        by_type[sl[1]] = (by_type[sl[1]] or 0) + sl[2]
        n_type[sl[1]] = (n_type[sl[1]] or 0) + 1
    end
end
local st_parts = {}
for k, v in pairs(by_type) do
    table.insert(st_parts, string.format("%s %.0fs (%d)", k, v / n_type[k], n_type[k]))
end
table.sort(st_parts)
print("average scene length: " .. table.concat(st_parts, ", "))
local where = {}
for _, r in ipairs(nights) do
    if r.longest_wait > 130 then
        where[r.longest_where] = (where[r.longest_where] or 0) + 1
    end
end
local wp = {}
for k, v in pairs(where) do table.insert(wp, k .. " " .. v) end
table.sort(wp)
print("where the long waits happen (>130s): " .. table.concat(wp, ", "))
local waits = sorted("longest_wait")
-- NIGHTS_TAIL=1: what fills the longest stretches without a DM choice.
if os.getenv("NIGHTS_TAIL") then
    local hist = {}
    for _, n in ipairs(nights) do hist[n.decisions] = (hist[n.decisions] or 0) + 1 end
    local hl = {}
    for d = 0, 30 do if hist[d] then table.insert(hl, d .. ":" .. hist[d]) end end
    print("decisions histogram: " .. table.concat(hl, " "))
    local hi, agg, hc, hi_i, hi_r, lo_c = 0, {}, 0, 0, 0, 0
    for _, n in ipairs(nights) do
        if n.decisions > 15 then
            hi = hi + 1
            hc, hi_i, hi_r = hc + n.cards, hi_i + n.improv, hi_r + n.rulings
            for _, id in ipairs(n.card_list or {}) do
                local k = string.gsub(id, "_[%w]+_%d+$", "_*")
                agg[k] = (agg[k] or 0) + 1
            end
        end
    end
    if hi > 0 then
        local o = {}
        for k, v in pairs(agg) do table.insert(o, { k, v }) end
        table.sort(o, function(a, b) return a[2] > b[2] end)
        local l = {}
        for k = 1, math.min(20, #o) do table.insert(l, string.format("%s %.2f", o[k][1], o[k][2] / hi)) end
        print(string.format("%d nights over 15: cards %.1f improv %.1f rulings %.1f; %s", hi, hc / hi, hi_i / hi, hi_r / hi, table.concat(l, ", ")))
    end
    local worst = {}
    for _, r in ipairs(nights) do
        table.insert(worst, r)
    end
    table.sort(worst, function(a, b) return a.longest_wait > b.longest_wait end)
    local p90 = math.floor(#worst * 0.1)
    local picks = { 1, 2, 3, p90 - 2, p90 - 1, p90, p90 + 1, p90 + 2 }
    for _, i in ipairs(picks) do
        local r = worst[i]
        local by = {}
        for _, ev in ipairs(r.stretch or {}) do
            by[ev.kind] = (by[ev.kind] or 0) + (ev.t or 0)
        end
        local parts = {}
        for k, v in pairs(by) do
            table.insert(parts, string.format("%s %.0fs", k, v))
        end
        table.sort(parts)
        print(string.format("  %.0fs at %s (%s, %d decisions): %s", r.longest_wait, r.longest_where, r.style, r.decisions, table.concat(parts, ", ")))
    end
end
print(string.format("longest stretch without a DM choice: median %.0fs, p90 %.0fs", pct(waits, 0.5), pct(waits, 0.9)))
for _, skey in ipairs(STYLES) do
    local m, d, n = 0, 0, 0
    for _, r in ipairs(nights) do
        if r.style == skey then m, d, n = m + r.minutes, d + r.decisions, n + 1 end
    end
    print(string.format("  %-14s %5.1f min  %4.1f decisions", skey, m / n, d / n))
end

local checks = {}
local function check(name, ok, detail)
    table.insert(checks, ok)
    print(string.format("  [%s] %s  -  %s", ok and "PASS" or "FAIL", name, detail))
end
if os.getenv("NIGHTS_DETAIL") then
    local ids = {}
    for id, n in pairs(CARD_IDS) do
        table.insert(ids, { (string.gsub(id, "_[%w]+_%d+$", "_*")), n })
    end
    local merged, order = {}, {}
    for _, x in ipairs(ids) do
        if not merged[x[1]] then table.insert(order, x[1]) end
        merged[x[1]] = (merged[x[1]] or 0) + x[2]
    end
    table.sort(order, function(a, b) return merged[a] > merged[b] end)
    local line = {}
    for k = 1, math.min(40, #order) do
        table.insert(line, string.format("%s %.2f", order[k], merged[order[k]] / #nights))
    end
    print("cards per night: " .. table.concat(line, ", "))
    local c, i, r = 0, 0, 0
    for _, n in ipairs(nights) do c, i, r = c + n.cards, i + n.improv, r + n.rulings end
    print(string.format("per night: cards %.2f, improv %.2f, rulings %.2f", c / #nights, i / #nights, r / #nights))
    local ty = {}
    for _, n in ipairs(nights) do
        for t, k in pairs(n.types) do ty[t] = (ty[t] or 0) + k end
    end
    local tl = {}
    for t, k in pairs(ty) do table.insert(tl, string.format("%s %.2f", t, k / #nights)) end
    table.sort(tl)
    print("card types per night: " .. table.concat(tl, ", "))
    local worst = {}
    for _, n in ipairs(nights) do table.insert(worst, n) end
    table.sort(worst, function(a, b) return a.longest_wait > b.longest_wait end)
    for k = 1, 3 do
        local n = worst[k]
        local seq = {}
        for _, ev in ipairs(n.stretch or {}) do
            table.insert(seq, ev.kind .. string.format("%.0f", ev.t or 0) .. (ev.kind == "say" and ev.text and ("[" .. string.sub(ev.text, 1, 24) .. "]") or ""))
        end
        print(string.format("wait %.0fs at %s: %s", n.longest_wait, tostring(n.longest_where), table.concat(seq, " ")))
    end
end
print("Gate")
check("No errors, every night ends, every line filled in", #failures == 0, #failures .. " problems")
local in_range = share(function(r) return r.decisions >= 8 and r.decisions <= 15 end)
check("8 to 15 decisions a night", in_range >= 0.9, string.format("%.0f%% of nights", 100 * in_range))
check("About 15 minutes a night", pct(mins, 0.5) >= 13 and pct(mins, 0.5) <= 17 and pct(mins, 0.1) >= 10 and pct(mins, 0.9) <= 20,
    string.format("median %.1f min, 80%% between %.1f and %.1f", pct(mins, 0.5), pct(mins, 0.1), pct(mins, 0.9)))
local all_types = true
for _, t in ipairs(types) do
    if share(function(r) return (r.types[t] or 0) > 0 end) < 0.05 then all_types = false end
end
check("All six decision types come up", all_types, "each type in at least 5% of nights")
check("The DM is never left watching too long", pct(waits, 0.9) <= 150,
    string.format("90%% of nights: longest gap %.0fs", pct(waits, 0.9)))
do
    local traps, hazards = 0, 0
    for _, r in ipairs(nights) do
        traps, hazards = traps + r.traps, hazards + r.hazards
    end
    check("Traps and hazards turn up on game nights (A10)", traps > 0 and hazards > 0,
        string.format("%d trap scenes and %d fights with a hazard in %d nights", traps, hazards, #nights))
end
for _, f in ipairs(failures) do print("  ! " .. f) end
local passed = 0
for _, ok in ipairs(checks) do if ok then passed = passed + 1 end end
print(string.format("%d of %d checks pass", passed, #checks))
